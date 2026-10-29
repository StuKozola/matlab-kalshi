classdef FakeMarketClient < handle
    %FakeMarketClient Test double for the market lookups the recorder performs.

    properties
        OpenTickers (:, 1) string = strings(0, 1)
        Results = containers.Map("KeyType", "char", "ValueType", "char")
    end

    methods
        function data = getMarkets(obj, options)
            arguments
                obj (1, 1) kalshiTest.FakeMarketClient
                options.SeriesTicker (1, 1) string = ""
                options.Status (1, 1) string = ""
                options.Limit double = []
            end

            markets = cell(numel(obj.OpenTickers), 1);
            for k = 1:numel(obj.OpenTickers)
                markets{k} = struct("ticker", char(obj.OpenTickers(k)), "floor_strike", 100.5);
            end

            data = struct("markets", {markets});
        end

        function data = getMarket(obj, ticker)
            arguments
                obj (1, 1) kalshiTest.FakeMarketClient
                ticker (1, 1) string
            end

            result = "";
            if isKey(obj.Results, char(ticker))
                result = string(obj.Results(char(ticker)));
            end

            data = struct("market", struct("ticker", char(ticker), "result", char(result)));
        end
    end
end
