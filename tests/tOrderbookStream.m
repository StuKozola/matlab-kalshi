classdef tOrderbookStream < matlab.unittest.TestCase
    %tOrderbookStream Tests orderbook snapshot and delta handling.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testSnapshotCreatesBook(testCase)
            stream = kalshi.OrderbookStream();

            stream.applySnapshot(snapshotMessage());
            book = stream.getBook("KXTEST-26MAY21-T50");

            testCase.verifyEqual(book.seq, 1);
            testCase.verifyEqual(book.yes.count_fp(book.yes.price_dollars == "0.5600"), 10);
            testCase.verifyEqual(book.no.count_fp(book.no.price_dollars == "0.4400"), 8);
        end

        function testDeltaUpdatesBook(testCase)
            stream = kalshi.OrderbookStream();

            stream.applySnapshot(snapshotMessage());
            stream.applyDelta(deltaMessage(2, "yes", "0.5600", "-3.00"));
            book = stream.getBook("KXTEST-26MAY21-T50");

            testCase.verifyEqual(book.seq, 2);
            testCase.verifyEqual(book.yes.count_fp(book.yes.price_dollars == "0.5600"), 7);
        end

        function testProcessMessageRequestsSnapshotOnSequenceGap(testCase)
            stream = kalshi.OrderbookStream();
            transport = kalshiTest.FakeWebSocketTransport();
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            stream.applySnapshot(snapshotMessage());
            status = stream.processMessage(deltaMessage(3, "yes", "0.5600", "-3.00"), ...
                WebSocketClient=ws);

            testCase.verifyEqual(status.Type, "resync_requested");
            testCase.verifyEqual(status.Ticker, "KXTEST-26MAY21-T50");
            testCase.verifyEqual(transport.Sent{1}.cmd, "update_subscription");
            testCase.verifyEqual(transport.Sent{1}.params.action, "get_snapshot");
            testCase.verifyEqual(string(transport.Sent{1}.params.market_tickers{1}), ...
                "KXTEST-26MAY21-T50");
        end

        function testReceiveBookProcessesSnapshot(testCase)
            stream = kalshi.OrderbookStream();
            transport = kalshiTest.FakeWebSocketTransport(Messages={jsonencode(snapshotMessage())});
            ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);

            ws.connect();
            book = stream.receiveBook(ws, "KXTEST-26MAY21-T50", Timeout=1, MaxMessages=1);

            testCase.verifyEqual(book.seq, 1);
            testCase.verifyEqual(book.yes.count_fp(book.yes.price_dollars == "0.5600"), 10);
        end

        function testSequenceGapErrors(testCase)
            stream = kalshi.OrderbookStream();

            stream.applySnapshot(snapshotMessage());

            testCase.verifyError( ...
                @() stream.applyDelta(deltaMessage(3, "yes", "0.5600", "-3.00")), ...
                "kalshi:OrderbookStream:SequenceGap");
        end
    end
end

function message = snapshotMessage()
    message = struct( ...
        "type", "orderbook_snapshot", ...
        "sid", 2, ...
        "seq", 1, ...
        "msg", struct( ...
            "market_ticker", "KXTEST-26MAY21-T50", ...
            "yes_dollars_fp", {{"0.5600", "10.00"; "0.5700", "5.00"}}, ...
            "no_dollars_fp", {{"0.4400", "8.00"}}));
end

function message = deltaMessage(sequenceNumber, side, price, delta)
    message = struct( ...
        "type", "orderbook_delta", ...
        "sid", 2, ...
        "seq", sequenceNumber, ...
        "msg", struct( ...
            "market_ticker", "KXTEST-26MAY21-T50", ...
            "side", side, ...
            "price_dollars", price, ...
            "delta_fp", delta));
end
