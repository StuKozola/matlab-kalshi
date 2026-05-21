classdef tWebSocketClient < matlab.unittest.TestCase
    %tWebSocketClient Tests WebSocket command construction.

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
        function testTickerSubscriptionCommand(testCase)
            transport = kalshiTest.FakeWebSocketTransport();
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            commandId = ws.subscribe("ticker", MarketTickers="KXTEST-26MAY21-T50");

            testCase.verifyEqual(commandId, 1);
            testCase.verifyEqual(transport.Sent{1}.cmd, "subscribe");
            testCase.verifyEqual(string(transport.Sent{1}.params.channels{1}), "ticker");
            testCase.verifyFalse(isfield(transport.Sent{1}.params, "use_yes_price"));
        end

        function testOrderbookSubscriptionUsesYesPrice(testCase)
            transport = kalshiTest.FakeWebSocketTransport();
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            ws.subscribe("orderbook_delta", MarketTickers="KXTEST-26MAY21-T50");

            testCase.verifyTrue(transport.Sent{1}.params.use_yes_price);
        end

        function testReceiveDecodesJsonMessage(testCase)
            transport = kalshiTest.FakeWebSocketTransport( ...
                Messages={"{""type"":""ticker"",""msg"":{""market_ticker"":""KXTEST""}}"});
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            message = ws.receive(Timeout=1);

            testCase.verifyEqual(string(message.type), "ticker");
            testCase.verifyEqual(string(message.msg.market_ticker), "KXTEST");
        end

        function testReceiveEventParsesEnvelope(testCase)
            transport = kalshiTest.FakeWebSocketTransport( ...
                Messages={"{""type"":""user_order"",""sid"":22,""msg"":{""order_id"":""order-1"",""status"":""resting""}}"});
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            event = ws.receiveEvent(Timeout=1);

            testCase.verifyEqual(event.Type, "user_order");
            testCase.verifyEqual(event.Sid, 22);
            testCase.verifyEqual(string(event.Data.order_id), "order-1");
        end

        function testReconnectReplaysSubscriptions(testCase)
            transport = kalshiTest.FakeWebSocketTransport();
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            ws.subscribe("ticker", MarketTickers="KXTEST-26MAY21-T50");
            commandIds = ws.reconnect();

            testCase.verifyEqual(transport.ConnectCount, 2);
            testCase.verifyEqual(commandIds, 2);
            testCase.verifyEqual(numel(transport.Sent), 2);
            testCase.verifyEqual(string(transport.Sent{2}.params.market_tickers{1}), "KXTEST-26MAY21-T50");
        end
    end
end
