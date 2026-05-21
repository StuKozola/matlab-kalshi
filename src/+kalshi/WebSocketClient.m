classdef WebSocketClient < handle
    %WebSocketClient Authenticated Kalshi WebSocket command client.

    properties (SetAccess = private)
        Config (1, 1) kalshi.Config
        Connected (1, 1) logical = false
        LastCommandId (1, 1) double = 0
    end

    properties
        Signer = []
        Transport = []
        MessageReceivedFcn = []
        ErrorFcn = []
    end

    properties (Access = private)
        Subscriptions
        SubscriptionSpecs
    end

    methods
        function obj = WebSocketClient(config, options)
            arguments
                config (1, 1) kalshi.Config = kalshi.Config.demo()
                options.Signer = []
                options.Transport = []
            end

            obj.Config = config;
            obj.Signer = options.Signer;
            obj.Transport = options.Transport;
            obj.Subscriptions = containers.Map("KeyType", "double", "ValueType", "any");
            obj.SubscriptionSpecs = {};
        end

        function connect(obj)
            %connect Open the authenticated WebSocket transport.
            if isempty(obj.Transport)
                headers = obj.ensureSigner().createHeaders("GET", kalshi.AuthSigner.webSocketPath());
                obj.Transport = kalshi.internal.WebSocketTransport( ...
                    obj.Config.WebSocketUrl, headers, Timeout=obj.Config.Timeout);
            end

            obj.Transport.connect();
            obj.Connected = true;
        end

        function commandId = subscribe(obj, channels, options)
            %subscribe Subscribe to one or more Kalshi WebSocket channels.
            arguments
                obj (1, 1) kalshi.WebSocketClient
                channels string
                options.MarketTicker (1, 1) string = ""
                options.MarketTickers string = strings(0, 1)
                options.MarketId (1, 1) string = ""
                options.MarketIds string = strings(0, 1)
                options.UseYesPrice (1, 1) logical = true
            end

            params = struct("channels", {cellstr(channels(:)')});
            params = addMarketSelectors(params, options.MarketTicker, options.MarketTickers, ...
                options.MarketId, options.MarketIds);

            if any(channels(:) == "orderbook_delta")
                params.use_yes_price = options.UseYesPrice;
            end

            commandId = obj.sendCommand("subscribe", params);
            obj.SubscriptionSpecs{end + 1} = params;
        end

        function commandId = unsubscribe(obj, sids)
            %unsubscribe Cancel one or more active subscriptions.
            arguments
                obj (1, 1) kalshi.WebSocketClient
                sids double
            end

            params = struct("sids", sids(:)');
            commandId = obj.sendCommand("unsubscribe", params);
        end

        function commandId = listSubscriptions(obj)
            %listSubscriptions Request active subscription metadata.
            commandId = obj.sendCommand("list_subscriptions", struct());
        end

        function commandId = updateSubscription(obj, sid, action, options)
            %updateSubscription Add/remove markets or request a fresh orderbook snapshot.
            arguments
                obj (1, 1) kalshi.WebSocketClient
                sid (1, 1) double
                action (1, 1) string {mustBeMember(action, ["add_markets", "delete_markets", "get_snapshot"])}
                options.MarketTickers string = strings(0, 1)
            end

            params = struct( ...
                "sid", sid, ...
                "action", action, ...
                "market_tickers", {cellstr(options.MarketTickers(:)')});
            commandId = obj.sendCommand("update_subscription", params);
        end

        function commandIds = resubscribe(obj)
            %resubscribe Replay remembered subscribe commands on the current connection.
            obj.assertConnected();
            commandIds = zeros(numel(obj.SubscriptionSpecs), 1);

            for k = 1:numel(obj.SubscriptionSpecs)
                commandIds(k) = obj.sendCommand("subscribe", obj.SubscriptionSpecs{k});
            end
        end

        function commandIds = reconnect(obj)
            %reconnect Reopen the transport and replay remembered subscriptions.
            obj.close();
            obj.connect();
            commandIds = obj.resubscribe();
        end

        function message = receive(obj, options)
            %receive Read one message from the transport and decode JSON.
            arguments
                obj (1, 1) kalshi.WebSocketClient
                options.Timeout (1, 1) double {mustBeNonnegative} = 0
            end

            rawMessage = obj.Transport.receive(options.Timeout);
            if isempty(rawMessage)
                message = [];
                return
            end

            if isstring(rawMessage) || ischar(rawMessage)
                message = jsondecode(char(rawMessage));
            else
                message = rawMessage;
            end

            obj.recordMessage(message);
            obj.dispatchMessage(message);
        end

        function event = receiveEvent(obj, options)
            %receiveEvent Receive one message and return a normalized event envelope.
            arguments
                obj (1, 1) kalshi.WebSocketClient
                options.Timeout (1, 1) double {mustBeNonnegative} = 0
            end

            message = obj.receive(Timeout=options.Timeout);
            event = kalshi.parseWebSocketMessage(message);
        end

        function close(obj)
            %close Close the WebSocket transport.
            if ~isempty(obj.Transport)
                obj.Transport.close();
            end

            obj.Connected = false;
        end
    end

    methods (Access = private)
        function commandId = sendCommand(obj, commandName, params)
            obj.assertConnected();
            obj.LastCommandId = obj.LastCommandId + 1;
            commandId = obj.LastCommandId;
            command = struct("id", commandId, "cmd", commandName, "params", params);
            obj.Transport.send(command);
        end

        function signer = ensureSigner(obj)
            if isempty(obj.Signer)
                obj.Signer = kalshi.AuthSigner.fromConfig(obj.Config);
            end

            signer = obj.Signer;
        end

        function assertConnected(obj)
            if ~obj.Connected || isempty(obj.Transport)
                error("kalshi:WebSocketClient:NotConnected", ...
                    "Call connect before sending WebSocket commands.");
            end
        end

        function recordMessage(obj, message)
            if ~isstruct(message) || ~isfield(message, "type")
                return
            end

            if string(message.type) == "subscribed" && isfield(message, "msg")
                sid = double(message.msg.sid);
                obj.Subscriptions(sid) = kalshi.Subscription( ...
                    Sid=sid, ...
                    Channel=string(message.msg.channel), ...
                    CommandId=double(message.id));
            end
        end

        function dispatchMessage(obj, message)
            try
                if ~isempty(obj.MessageReceivedFcn)
                    obj.MessageReceivedFcn(message);
                end
            catch exception
                if isempty(obj.ErrorFcn)
                    rethrow(exception)
                end

                obj.ErrorFcn(exception);
            end
        end
    end
end

function params = addMarketSelectors(params, marketTicker, marketTickers, marketId, marketIds)
    if strlength(marketTicker) > 0
        params.market_ticker = marketTicker;
    end

    if numel(marketTickers) > 0
        params.market_tickers = cellstr(marketTickers(:)');
    end

    if strlength(marketId) > 0
        params.market_id = marketId;
    end

    if numel(marketIds) > 0
        params.market_ids = cellstr(marketIds(:)');
    end
end
