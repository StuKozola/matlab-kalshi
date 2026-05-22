classdef OrderbookStream < handle
    %OrderbookStream Maintains orderbook state from Kalshi WebSocket messages.

    properties (Access = private)
        Books
    end

    methods
        function obj = OrderbookStream()
            obj.Books = containers.Map("KeyType", "char", "ValueType", "any");
        end

        function status = applyMessage(obj, message)
            %applyMessage Apply an orderbook_snapshot or orderbook_delta message.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                message (1, 1) struct
            end

            status = struct( ...
                "Type", "ignored", ...
                "Ticker", "", ...
                "CommandId", NaN);
            messageType = string(message.type);
            if messageType == "orderbook_snapshot"
                obj.applySnapshot(message);
                status.Type = "snapshot";
                status.Ticker = string(message.msg.market_ticker);
            elseif messageType == "orderbook_delta"
                obj.applyDelta(message);
                status.Type = "delta";
                status.Ticker = string(message.msg.market_ticker);
            end
        end

        function commandId = subscribe(obj, webSocketClient, marketTickers, options)
            %subscribe Subscribe a WebSocket client to orderbook updates.
            arguments
                obj (1, 1) kalshi.OrderbookStream %#ok<INUSA>
                webSocketClient (1, 1) kalshi.WebSocketClient
                marketTickers string
                options.UseYesPrice (1, 1) logical = true
            end

            commandId = webSocketClient.subscribe( ...
                "orderbook_delta", ...
                MarketTickers=marketTickers, ...
                UseYesPrice=options.UseYesPrice);
        end

        function status = processMessage(obj, message, options)
            %processMessage Apply one message and request resync on sequence gaps.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                message (1, 1) struct
                options.WebSocketClient = []
            end

            try
                status = obj.applyMessage(message);
            catch exception
                if exception.identifier ~= "kalshi:OrderbookStream:SequenceGap" || ...
                        isempty(options.WebSocketClient)
                    rethrow(exception)
                end

                status = obj.requestSnapshot(options.WebSocketClient, message);
            end
        end

        function book = receiveBook(obj, webSocketClient, ticker, options)
            %receiveBook Process messages until a current book is available.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                webSocketClient (1, 1) kalshi.WebSocketClient
                ticker (1, 1) string
                options.Timeout (1, 1) double {mustBeNonnegative} = 10
                options.MaxMessages (1, 1) double {mustBeInteger, mustBePositive} = 50
            end

            for k = 1:options.MaxMessages
                message = webSocketClient.receive(Timeout=options.Timeout);
                if isempty(message)
                    continue
                end

                obj.processMessage(message, WebSocketClient=webSocketClient);
                if obj.hasBook(ticker)
                    book = obj.getBook(ticker);
                    return
                end
            end

            error("kalshi:OrderbookStream:BookTimeout", ...
                "No orderbook snapshot was received for %s.", ticker);
        end

        function applySnapshot(obj, message)
            %applySnapshot Replace book state for one market.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                message (1, 1) struct
            end

            ticker = char(message.msg.market_ticker);
            book = struct( ...
                "yes", containers.Map("KeyType", "char", "ValueType", "double"), ...
                "no", containers.Map("KeyType", "char", "ValueType", "double"), ...
                "seq", double(message.seq));

            if isfield(message.msg, "yes_dollars_fp")
                book.yes = loadLevels(book.yes, message.msg.yes_dollars_fp);
            end

            if isfield(message.msg, "no_dollars_fp")
                book.no = loadLevels(book.no, message.msg.no_dollars_fp);
            end
            obj.Books(ticker) = book;
        end

        function applyDelta(obj, message)
            %applyDelta Apply an incremental price-level delta.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                message (1, 1) struct
            end

            ticker = char(message.msg.market_ticker);
            if ~isKey(obj.Books, ticker)
                error("kalshi:OrderbookStream:MissingSnapshot", ...
                    "Received an orderbook delta before a snapshot for %s.", ticker);
            end

            book = obj.Books(ticker);
            expectedSeq = book.seq + 1;
            if isfield(message, "seq") && double(message.seq) ~= expectedSeq
                error("kalshi:OrderbookStream:SequenceGap", ...
                    "Expected sequence %d but received %d for %s.", expectedSeq, double(message.seq), ticker);
            end

            side = char(message.msg.side);
            price = char(string(message.msg.price_dollars));
            delta = str2double(string(message.msg.delta_fp));
            book.(side) = applyLevelDelta(book.(side), price, delta);
            book.seq = double(message.seq);
            obj.Books(ticker) = book;
        end

        function book = getBook(obj, ticker)
            %getBook Return current book state as a struct of tables.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                ticker (1, 1) string
            end

            key = char(ticker);
            if ~isKey(obj.Books, key)
                error("kalshi:OrderbookStream:BookNotFound", ...
                    "No orderbook is available for %s.", ticker);
            end

            rawBook = obj.Books(key);
            book = struct( ...
                "ticker", ticker, ...
                "seq", rawBook.seq, ...
                "yes", mapToTable(rawBook.yes), ...
                "no", mapToTable(rawBook.no));
        end

        function tf = hasBook(obj, ticker)
            %hasBook Return true when state exists for a market ticker.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                ticker (1, 1) string
            end

            tf = isKey(obj.Books, char(ticker));
        end
    end

    methods (Access = private)
        function status = requestSnapshot(~, webSocketClient, message)
            ticker = string(message.msg.market_ticker);
            if isfield(message, "sid")
                commandId = webSocketClient.updateSubscription( ...
                    double(message.sid), ...
                    "get_snapshot", ...
                    MarketTickers=ticker);
            else
                commandId = NaN;
            end

            status = struct( ...
                "Type", "resync_requested", ...
                "Ticker", ticker, ...
                "CommandId", commandId);
        end
    end
end

function levels = loadLevels(levels, rawLevels)
    if isempty(rawLevels)
        return
    end

    if iscell(rawLevels)
        if size(rawLevels, 2) >= 2 && ~iscell(rawLevels{1})
            for k = 1:size(rawLevels, 1)
                levels(char(string(rawLevels{k, 1}))) = str2double(string(rawLevels{k, 2}));
            end
        elseif isFlattenedCellLevels(rawLevels)
            midpoint = numel(rawLevels) / 2;
            for k = 1:midpoint
                levels(char(string(rawLevels{k}))) = str2double(string(rawLevels{k + midpoint}));
            end
        else
            for k = 1:numel(rawLevels)
                row = rawLevels{k};
                [price, count] = rowValues(row);
                levels(char(string(price))) = str2double(string(count));
            end
        end
    else
        for k = 1:size(rawLevels, 1)
            levels(char(string(rawLevels(k, 1)))) = str2double(string(rawLevels(k, 2)));
        end
    end
end

function tf = isFlattenedCellLevels(rawLevels)
    tf = size(rawLevels, 2) == 1 && ...
        mod(numel(rawLevels), 2) == 0 && ...
        ~isempty(rawLevels) && ...
        ~iscell(rawLevels{1});
end

function [price, count] = rowValues(row)
    if iscell(row)
        price = row{1};
        count = row{2};
    else
        price = row(1);
        count = row(2);
    end
end

function levels = applyLevelDelta(levels, price, delta)
    if isKey(levels, price)
        nextValue = levels(price) + delta;
    else
        nextValue = delta;
    end

    if nextValue <= 0
        if isKey(levels, price)
            remove(levels, price);
        end
    else
        levels(price) = nextValue;
    end
end

function value = mapToTable(levels)
    prices = string(keys(levels))';
    counts = zeros(numel(prices), 1);

    for k = 1:numel(prices)
        counts(k) = levels(char(prices(k)));
    end

    value = table(prices, counts, VariableNames=["price_dollars", "count_fp"]);
    if height(value) > 0
        value = sortrows(value, "price_dollars");
    end
end
