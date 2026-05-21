classdef FakeSigner < handle
    %FakeSigner Test double for Kalshi request signing.

    methods
        function headers = createHeaders(~, ~, ~)
            headers = {
                "KALSHI-ACCESS-KEY", "fake-key";
                "KALSHI-ACCESS-SIGNATURE", "fake-signature";
                "KALSHI-ACCESS-TIMESTAMP", "1710000000000"
            };
        end
    end
end
