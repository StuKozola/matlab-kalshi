classdef Subscription
    %Subscription Metadata for a Kalshi WebSocket subscription.

    properties
        Sid double = NaN
        Channel (1, 1) string = ""
        MarketTickers string = strings(0, 1)
        CommandId double = NaN
    end

    methods
        function obj = Subscription(options)
            arguments
                options.Sid double = NaN
                options.Channel (1, 1) string = ""
                options.MarketTickers string = strings(0, 1)
                options.CommandId double = NaN
            end

            obj.Sid = options.Sid;
            obj.Channel = options.Channel;
            obj.MarketTickers = options.MarketTickers(:);
            obj.CommandId = options.CommandId;
        end
    end
end
