classdef OrderbookStream < handle
    %OrderbookStream Maintains orderbook state from Kalshi WebSocket messages.

    properties (Access = private)
        Books
    end

    methods
        function obj = OrderbookStream()
            obj.Books = containers.Map("KeyType", "char", "ValueType", "any");
        end

        function applyMessage(obj, message)
            %applyMessage Apply an orderbook_snapshot or orderbook_delta message.
            arguments
                obj (1, 1) kalshi.OrderbookStream
                message (1, 1) struct
            end

            messageType = string(message.type);
            if messageType == "orderbook_snapshot"
                obj.applySnapshot(message);
            elseif messageType == "orderbook_delta"
                obj.applyDelta(message);
            end
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

            book.yes = loadLevels(book.yes, message.msg.yes_dollars_fp);
            book.no = loadLevels(book.no, message.msg.no_dollars_fp);
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
        else
            for k = 1:numel(rawLevels)
                row = rawLevels{k};
                levels(char(string(row{1}))) = str2double(string(row{2}));
            end
        end
    else
        for k = 1:size(rawLevels, 1)
            levels(char(string(rawLevels(k, 1)))) = str2double(string(rawLevels(k, 2)));
        end
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
