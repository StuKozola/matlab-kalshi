classdef Recorder < handle
    %Recorder Records a Kalshi series and CF Benchmarks BRTI ticks to JSON Lines files.
    %
    %   Every WebSocket message is stored verbatim with a local receive time so
    %   order books and the BRTI averages can be rebuilt offline. Market
    %   metadata and settlement results are fetched over REST and stored in the
    %   same files. Files are written to <OutputFolder>/<series>/<yyyymmdd>.jsonl
    %   (UTC date), one line per message:
    %
    %       {"t_recv_ms":1730000000000,"src":"ws","raw":{...}}
    %
    %   src is "ws" (WebSocket message), "rest_market" (market metadata, including
    %   floor_strike), "rest_settlement" (settled market) or "recorder" (gaps,
    %   reconnects and errors).

    properties (SetAccess = private)
        Config (1, 1) kalshi.Config
        SeriesTicker (1, 1) string
        OutputFolder (1, 1) string
        ActiveTickers (:, 1) string = strings(0, 1)
        MessageCount (1, 1) double = 0
        Running (1, 1) logical = false
    end

    properties
        Client = []
        WebSocketFactory = []
        Clock = []
        Verbose (1, 1) logical = true
        DiscoveryInterval (1, 1) double {mustBePositive} = 5
        FlushInterval (1, 1) double {mustBePositive} = 1
        StatusInterval (1, 1) double {mustBePositive} = 60
        MaxSettlementAttempts (1, 1) double {mustBePositive} = 120
        IncludeFastBrti (1, 1) logical = true
    end

    properties (Access = private)
        WebSocket = []
        ChannelState = struct()
        SidChannel
        LastSeq
        SeenTickers (:, 1) string = strings(0, 1)
        PendingSettlement
        Buffer = {}
        BufferDay = []
        LastFlushMs = 0
        LastDiscoveryMs = -Inf
        LastStatusMs = 0
    end

    properties (Constant, Access = private)
        MarketChannels = ["orderbook_delta", "ticker", "trade"]
    end

    methods
        function obj = Recorder(config, options)
            arguments
                config (1, 1) kalshi.Config = kalshi.Config.production()
                options.SeriesTicker (1, 1) string = "KXBTC15M"
                options.OutputFolder (1, 1) string = "data"
                options.Client = []
                options.WebSocketFactory = []
                options.Clock = []
            end

            obj.Config = config;
            obj.SeriesTicker = options.SeriesTicker;
            obj.OutputFolder = options.OutputFolder;

            if isempty(options.Client)
                obj.Client = kalshi.Client(config);
            else
                obj.Client = options.Client;
            end

            if isempty(options.WebSocketFactory)
                obj.WebSocketFactory = @() kalshi.WebSocketClient(config);
            else
                obj.WebSocketFactory = options.WebSocketFactory;
            end

            if isempty(options.Clock)
                obj.Clock = @currentUnixMs;
            else
                obj.Clock = options.Clock;
            end

            obj.PendingSettlement = containers.Map("KeyType", "char", "ValueType", "double");
            obj.resetSubscriptionState();
        end

        function start(obj)
            %start Open the WebSocket and subscribe to the BRTI channels.
            ws = obj.WebSocketFactory();
            ws.connect();
            obj.WebSocket = ws;
            obj.resetSubscriptionState();

            ws.subscribe("cfbenchmarks_value", IndexIds="BRTI");
            if obj.IncludeFastBrti
                ws.subscribe("cfbenchmarks_value_5hz", IndexIds="BRTI");
            end

            obj.LastDiscoveryMs = -Inf;
            obj.reconcile();
            obj.logEvent("connected", obj.Config.WebSocketUrl);
        end

        function run(obj, options)
            %run Record until stop() is called or Duration seconds have elapsed.
            arguments
                obj (1, 1) kalshi.Recorder
                options.Duration (1, 1) double {mustBePositive} = Inf
                options.PollTimeout (1, 1) double {mustBePositive} = 0.2
            end

            obj.Running = true;
            cleanup = onCleanup(@() obj.shutdown()); %#ok<NASGU>
            startMs = obj.Clock();
            obj.LastFlushMs = startMs;
            obj.LastStatusMs = startMs;
            failures = 0;

            while obj.Running && obj.Clock() - startMs < options.Duration * 1000
                try
                    if isempty(obj.WebSocket)
                        obj.start();
                    end

                    obj.step(options.PollTimeout);
                    failures = 0;
                catch exception
                    failures = failures + 1;
                    obj.logEvent("error", string(exception.identifier) + ": " + string(exception.message));
                    obj.dropConnection();
                    pause(min(2^failures, 30));
                end
            end
        end

        function stop(obj)
            %stop Ask a running recorder to finish its current iteration and exit.
            obj.Running = false;
        end

        function step(obj, pollTimeout)
            %step Drain pending messages, then run periodic discovery and flushing.
            arguments
                obj (1, 1) kalshi.Recorder
                pollTimeout (1, 1) double {mustBeNonnegative} = 0.2
            end

            timeout = pollTimeout;
            for k = 1:500
                message = obj.WebSocket.receive(Timeout=timeout);
                if isempty(message)
                    break
                end

                obj.ingest(message, obj.WebSocket.LastRawMessage);
                timeout = 0;
            end

            nowMs = obj.Clock();
            if nowMs - obj.LastDiscoveryMs >= obj.DiscoveryInterval * 1000
                obj.LastDiscoveryMs = nowMs;
                obj.refreshMarkets();
            end

            if nowMs - obj.LastFlushMs >= obj.FlushInterval * 1000
                obj.flush();
            end

            if nowMs - obj.LastStatusMs >= obj.StatusInterval * 1000
                obj.LastStatusMs = nowMs;
                obj.print(sprintf("messages=%d active=%s", obj.MessageCount, strjoin(obj.ActiveTickers, ",")));
            end
        end

        function ingest(obj, message, rawText)
            %ingest Record one decoded WebSocket message and track subscription state.
            arguments
                obj (1, 1) kalshi.Recorder
                message
                rawText (1, 1) string
            end

            nowMs = obj.Clock();
            obj.append(nowMs, "ws", rawText);
            obj.MessageCount = obj.MessageCount + 1;

            if ~isstruct(message) || ~isfield(message, "type")
                return
            end

            messageType = string(message.type);
            if messageType == "subscribed"
                obj.registerSubscription(message);
            elseif messageType == "error"
                obj.print("WebSocket error: " + rawText);
            elseif isfield(message, "sid") && isfield(message, "seq")
                obj.checkSequence(message, nowMs);
            end
        end

        function refreshMarkets(obj)
            %refreshMarkets Discover open markets, record metadata, and update subscriptions.
            try
                response = obj.Client.getMarkets( ...
                    SeriesTicker=obj.SeriesTicker, Status="open", Limit=20);
            catch exception
                obj.logEvent("rest_error", string(exception.message));
                return
            end

            markets = response.markets;
            tickers = strings(numel(markets), 1);
            for k = 1:numel(markets)
                tickers(k) = string(markets{k}.ticker);
                if ~ismember(tickers(k), obj.SeenTickers)
                    obj.append(obj.Clock(), "rest_market", string(jsonencode(markets{k})));
                    obj.SeenTickers = [obj.SeenTickers; tickers(k)];
                end
            end

            if numel(obj.SeenTickers) > 500
                obj.SeenTickers = obj.SeenTickers(end - 499:end);
            end

            gone = setdiff(obj.ActiveTickers, tickers);
            for k = 1:numel(gone)
                obj.PendingSettlement(char(gone(k))) = 0;
            end

            obj.ActiveTickers = tickers;
            obj.reconcile();
            obj.pollSettlements();
        end

        function flush(obj)
            %flush Write buffered lines to the day files.
            obj.LastFlushMs = obj.Clock();
            if isempty(obj.Buffer)
                return
            end

            lines = obj.Buffer;
            days = obj.BufferDay;
            for day = unique(days)
                appendLines(obj.dayFile(day), lines(days == day));
            end

            obj.Buffer = {};
            obj.BufferDay = [];
        end
    end

    methods (Access = private)
        function resetSubscriptionState(obj)
            state = struct();
            for channel = obj.MarketChannels
                state.(channel) = struct( ...
                    "Sid", NaN, ...
                    "Requested", false, ...
                    "Tickers", strings(0, 1));
            end

            obj.ChannelState = state;
            obj.SidChannel = containers.Map("KeyType", "double", "ValueType", "char");
            obj.LastSeq = containers.Map("KeyType", "double", "ValueType", "double");
        end

        function reconcile(obj)
            %reconcile Make each market channel subscription match ActiveTickers.
            desired = obj.ActiveTickers;
            if isempty(desired) || isempty(obj.WebSocket)
                return
            end

            for channel = obj.MarketChannels
                state = obj.ChannelState.(channel);
                if ~state.Requested
                    obj.WebSocket.subscribe(channel, MarketTickers=desired);
                    state.Requested = true;
                    state.Tickers = desired;
                elseif ~isnan(state.Sid)
                    toAdd = setdiff(desired, state.Tickers);
                    toDelete = setdiff(state.Tickers, desired);
                    if ~isempty(toAdd)
                        obj.WebSocket.updateSubscription(state.Sid, "add_markets", MarketTickers=toAdd);
                    end

                    if ~isempty(toDelete)
                        obj.WebSocket.updateSubscription(state.Sid, "delete_markets", MarketTickers=toDelete);
                    end

                    state.Tickers = desired;
                end

                obj.ChannelState.(channel) = state;
            end
        end

        function registerSubscription(obj, message)
            if ~isfield(message, "msg") || ~isfield(message.msg, "sid")
                return
            end

            sid = double(message.msg.sid);
            channel = string(message.msg.channel);
            obj.SidChannel(sid) = char(channel);
            if isKey(obj.LastSeq, sid)
                remove(obj.LastSeq, sid);
            end

            if any(channel == obj.MarketChannels)
                obj.ChannelState.(channel).Sid = sid;
                obj.reconcile();
            end
        end

        function checkSequence(obj, message, nowMs)
            sid = double(message.sid);
            seq = double(message.seq);

            if isKey(obj.LastSeq, sid) && seq ~= obj.LastSeq(sid) + 1
                detail = struct( ...
                    "event", "seq_gap", ...
                    "sid", sid, ...
                    "expected", obj.LastSeq(sid) + 1, ...
                    "received", seq);
                obj.append(nowMs, "recorder", string(jsonencode(detail)));
                obj.print(sprintf("sequence gap on sid %d: expected %d, received %d", ...
                    sid, obj.LastSeq(sid) + 1, seq));
                obj.requestSnapshot(sid);
            end

            obj.LastSeq(sid) = seq;
        end

        function requestSnapshot(obj, sid)
            if ~isKey(obj.SidChannel, sid) || obj.SidChannel(sid) ~= "orderbook_delta"
                return
            end

            tickers = obj.ChannelState.orderbook_delta.Tickers;
            if ~isempty(tickers) && ~isempty(obj.WebSocket)
                obj.WebSocket.updateSubscription(sid, "get_snapshot", MarketTickers=tickers);
            end
        end

        function pollSettlements(obj)
            pending = string(keys(obj.PendingSettlement));
            for k = 1:numel(pending)
                key = char(pending(k));
                try
                    data = obj.Client.getMarket(pending(k));
                catch exception
                    obj.logEvent("rest_error", string(exception.message));
                    continue
                end

                if isfield(data, "market") && isfield(data.market, "result") && ...
                        strlength(string(data.market.result)) > 0
                    obj.append(obj.Clock(), "rest_settlement", string(jsonencode(data)));
                    remove(obj.PendingSettlement, key);
                    continue
                end

                attempts = obj.PendingSettlement(key) + 1;
                if attempts > obj.MaxSettlementAttempts
                    obj.logEvent("settlement_timeout", pending(k));
                    remove(obj.PendingSettlement, key);
                else
                    obj.PendingSettlement(key) = attempts;
                end
            end
        end

        function dropConnection(obj)
            if ~isempty(obj.WebSocket)
                try
                    obj.WebSocket.close();
                catch
                end
            end

            obj.WebSocket = [];
        end

        function shutdown(obj)
            obj.Running = false;
            try
                obj.flush();
            catch exception
                obj.print("Flush on shutdown failed: " + string(exception.message));
            end

            obj.dropConnection();
        end

        function logEvent(obj, eventName, detail)
            payload = struct("event", eventName, "detail", string(detail));
            obj.append(obj.Clock(), "recorder", string(jsonencode(payload)));
            obj.print(eventName + ": " + string(detail));
        end

        function append(obj, nowMs, source, rawJson)
            rawJson = regexprep(rawJson, "[\r\n]+", " ");
            line = sprintf('{"t_recv_ms":%.0f,"src":"%s","raw":%s}', nowMs, source, rawJson);
            obj.Buffer{end + 1} = line;
            obj.BufferDay(end + 1) = floor(nowMs / 86400000);
        end

        function fileName = dayFile(obj, day)
            folder = fullfile(obj.OutputFolder, lower(obj.SeriesTicker));
            if ~isfolder(folder)
                mkdir(folder);
            end

            stamp = datetime(day * 86400, "ConvertFrom", "posixtime", ...
                "TimeZone", "UTC", "Format", "yyyyMMdd");
            fileName = fullfile(folder, string(stamp) + ".jsonl");
        end

        function print(obj, text)
            if obj.Verbose
                fprintf("[%s] %s\n", char(datetime("now", Format="HH:mm:ss")), char(text));
            end
        end
    end
end

function nowMs = currentUnixMs()
    nowMs = floor(posixtime(datetime("now", TimeZone="UTC")) * 1000);
end

function appendLines(fileName, lines)
    fid = fopen(fileName, "a", "n", "UTF-8");
    if fid < 0
        error("kalshi:Recorder:FileOpenFailed", "Unable to open %s for writing.", fileName);
    end

    closer = onCleanup(@() fclose(fid));
    fprintf(fid, "%s\n", lines{:});
    clear closer
end
