classdef tLiveKalshiDemo < matlab.unittest.TestCase
    %tLiveKalshiDemo Live demo-environment integration tests.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
        end
    end

    methods (Test, TestTags = {'Integration', 'Live'})
        function testDemoBalance(testCase)
            config = liveDemoConfig(testCase);
            client = kalshi.Client(config);

            response = client.getBalance();

            testCase.verifyTrue(isfield(response, "balance"));
            testCase.verifyTrue(isfield(response, "portfolio_value"));
        end
    end

    methods (Test, TestTags = {'Integration', 'Live', 'Trading'})
        function testDemoOrderCanBeCanceled(testCase)
            config = liveDemoConfig(testCase);
            requireTradingIntegration(testCase);
            client = kalshi.Client(config);
            ticker = selectRestingBidMarket(client);
            testCase.assumeTrue(strlength(ticker) > 0, ...
                "No suitable open demo market was available for a post-only bid.");

            clientOrderId = kalshi.makeClientOrderId("matlab-test");
            createResponse = client.createOrder( ...
                ticker, clientOrderId, "bid", 1, 0.01, ...
                TimeInForce="good_till_canceled", PostOnly=true);
            orderId = string(createResponse.order_id);
            testCase.addTeardown(@() cancelOrderQuietly(client, orderId));

            cancelResponse = client.cancelOrder(orderId);

            testCase.verifyEqual(string(cancelResponse.order_id), orderId);
            testCase.verifyTrue(isfield(cancelResponse, "reduced_by"));
        end
    end
end

function config = liveDemoConfig(testCase)
    testCase.assumeTrue(strcmpi(getenv("KALSHI_RUN_INTEGRATION"), "true"), ...
        "Set KALSHI_RUN_INTEGRATION=true to run live integration tests.");

    repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
    config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));
    testCase.assumeEqual(config.Environment, "demo", ...
        "Live integration tests are restricted to the Kalshi demo environment.");
    testCase.assumeTrue(config.hasCredentials(), ...
        "Kalshi demo credentials are required for live integration tests.");
end

function requireTradingIntegration(testCase)
    testCase.assumeTrue(strcmpi(getenv("KALSHI_RUN_TRADING_INTEGRATION"), "true"), ...
        "Set KALSHI_RUN_TRADING_INTEGRATION=true to run demo order placement tests.");
end

function ticker = selectRestingBidMarket(client)
    response = client.getMarkets(Status="open", Limit=100);
    ticker = "";

    for k = 1:numel(response.markets)
        market = getMarketAt(response.markets, k);
        if isfield(market, 'yes_ask_dollars') && isRestingBidCandidate(market)
            ticker = string(market.ticker);
            return
        end
    end
end

function market = getMarketAt(markets, index)
    if iscell(markets)
        market = markets{index};
    else
        market = markets(index);
    end
end

function tf = isRestingBidCandidate(market)
    yesAsk = str2double(string(market.yes_ask_dollars));
    tf = isnan(yesAsk) || yesAsk == 0 || yesAsk > 0.02;
end

function cancelOrderQuietly(client, orderId)
    try
        client.cancelOrder(orderId);
    catch
    end
end
