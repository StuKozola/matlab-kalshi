classdef tClientRequests < matlab.unittest.TestCase
    %tClientRequests Tests REST request construction with fake transports.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "tests"), IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testGetMarketsBuildsQuery(testCase)
            client = kalshi.Client(kalshi.Config.demo(), Transport=@identityTransport);

            request = client.getMarkets(Status="open", Limit=5);

            testCase.verifyEqual(request.Method, "GET");
            testCase.verifyEqual(request.Url, ...
                "https://external-api.demo.kalshi.co/trade-api/v2/markets?status=open&limit=5");
            testCase.verifyFalse(request.Authenticated);
        end

        function testCreateOrderUsesV2EndpointAndFixedPoint(testCase)
            client = kalshi.Client(kalshi.Config.demo(), ...
                Signer=kalshiTest.FakeSigner(), Transport=@identityTransport);

            request = client.createOrder("KXTEST-26MAY21-T50", ...
                "client-1", "bid", 10, 0.56);

            testCase.verifyEqual(request.Method, "POST");
            testCase.verifyEqual(request.Endpoint, "/portfolio/events/orders");
            testCase.verifyEqual(request.Body.count, "10.00");
            testCase.verifyEqual(request.Body.price, "0.5600");
            testCase.verifyEqual(request.Body.exchange_index, 0);
            testCase.verifyEqual(request.Headers{1, 1}, "KALSHI-ACCESS-KEY");
        end

        function testProductionTradingRequiresExplicitOptIn(testCase)
            client = kalshi.Client(kalshi.Config.production(), ...
                Signer=kalshiTest.FakeSigner(), Transport=@identityTransport);

            testCase.verifyError( ...
                @() client.createOrder("KXTEST-26MAY21-T50", "client-1", "bid", 10, 0.56), ...
                "kalshi:Client:ProductionTradingDisabled");
        end

        function testRetriesRateLimitedRequests(testCase)
            transport = kalshiTest.FlakyTransport();
            config = kalshi.Config.demo(MaxRetries=2, RetryBaseDelay=0, RetryMaxDelay=0);
            client = kalshi.Client(config, Transport=@(request) transport.handleRequest(request));

            response = client.getMarkets(Status="open", Limit=5);

            testCase.verifyEqual(response.Attempts, 2);
            testCase.verifyEqual(transport.Attempts, 2);
        end

        function testDoesNotRetryPostServerError(testCase)
            transport = kalshiTest.FlakyTransport(ErrorIdentifier="kalshi:ApiError:Status500");
            config = kalshi.Config.demo(MaxRetries=2, RetryBaseDelay=0, RetryMaxDelay=0);
            client = kalshi.Client(config, ...
                Signer=kalshiTest.FakeSigner(), ...
                Transport=@(request) transport.handleRequest(request));

            testCase.verifyError( ...
                @() client.createOrder("KXTEST-26MAY21-T50", "client-1", "bid", 10, 0.56), ...
                "kalshi:ApiError:Status500");
            testCase.verifyEqual(transport.Attempts, 1);
        end
    end
end

function response = identityTransport(request)
    response = request;
end
