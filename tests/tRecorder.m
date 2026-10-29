classdef tRecorder < matlab.unittest.TestCase
    %tRecorder Tests market recording, subscription management, and sequence tracking.

    properties (Constant)
        TickerA = "KXBTC15M-26OCT291000-00"
        TickerB = "KXBTC15M-26OCT291015-15"
    end

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
        function testStartSubscribesToBrtiAndMarkets(testCase)
            [recorder, transport, client] = makeRecorder(testCase);
            client.OpenTickers = testCase.TickerA;

            recorder.start();
            recorder.refreshMarkets();

            channels = sentChannels(transport);
            testCase.verifyTrue(all(ismember( ...
                ["cfbenchmarks_value", "cfbenchmarks_value_5hz", "orderbook_delta", "ticker", "trade"], ...
                channels)));

            brtiCommand = transport.Sent{find(channels == "cfbenchmarks_value", 1)};
            testCase.verifyEqual(string(brtiCommand.params.index_ids{1}), "BRTI");

            bookCommand = transport.Sent{find(channels == "orderbook_delta", 1)};
            testCase.verifyEqual(string(bookCommand.params.market_tickers{1}), testCase.TickerA);
        end

        function testRefreshRecordsMarketMetadataOnce(testCase)
            [recorder, ~, client, folder] = makeRecorder(testCase);
            client.OpenTickers = testCase.TickerA;

            recorder.start();
            recorder.refreshMarkets();
            recorder.refreshMarkets();
            recorder.flush();

            records = readRecords(folder);
            marketRecords = records(sourcesOf(records) == "rest_market");
            testCase.verifyEqual(numel(marketRecords), 1);
            testCase.verifyEqual(string(marketRecords{1}.raw.ticker), testCase.TickerA);
            testCase.verifyEqual(marketRecords{1}.raw.floor_strike, 100.5);
        end

        function testIngestStoresRawMessageWithReceiveTime(testCase)
            [recorder, ~, ~, folder] = makeRecorder(testCase);
            rawText = "{""type"":""ticker"",""sid"":3,""msg"":{""market_ticker"":""KXTEST"",""price_dollars"":""0.5600""}}";

            recorder.ingest(jsondecode(rawText), rawText);
            recorder.flush();

            records = readRecords(folder);
            testCase.verifyEqual(numel(records), 1);
            testCase.verifyEqual(string(records{1}.src), "ws");
            testCase.verifyEqual(records{1}.t_recv_ms, 1730000000000);
            testCase.verifyEqual(string(records{1}.raw.msg.price_dollars), "0.5600");
            testCase.verifyEqual(recorder.MessageCount, 1);
        end

        function testSequenceGapRequestsOrderbookSnapshot(testCase)
            [recorder, transport, client, folder] = makeRecorder(testCase);
            client.OpenTickers = testCase.TickerA;
            recorder.start();
            recorder.refreshMarkets();

            ingestText(recorder, "{""id"":3,""type"":""subscribed"",""msg"":{""channel"":""orderbook_delta"",""sid"":7}}");
            ingestText(recorder, "{""type"":""orderbook_snapshot"",""sid"":7,""seq"":1,""msg"":{""market_ticker"":""" + testCase.TickerA + """}}");
            ingestText(recorder, "{""type"":""orderbook_delta"",""sid"":7,""seq"":3,""msg"":{""market_ticker"":""" + testCase.TickerA + """}}");
            recorder.flush();

            command = transport.Sent{end};
            testCase.verifyEqual(string(command.cmd), "update_subscription");
            testCase.verifyEqual(string(command.params.action), "get_snapshot");
            testCase.verifyEqual(command.params.sid, 7);
            testCase.verifyEqual(string(command.params.market_tickers{1}), testCase.TickerA);

            records = readRecords(folder);
            recorderRecords = records(sourcesOf(records) == "recorder");
            events = strings(numel(recorderRecords), 1);
            for k = 1:numel(recorderRecords)
                events(k) = string(recorderRecords{k}.raw.event);
            end

            testCase.verifyTrue(any(events == "seq_gap"));
        end

        function testContiguousSequenceDoesNotRequestSnapshot(testCase)
            [recorder, transport, client] = makeRecorder(testCase);
            client.OpenTickers = testCase.TickerA;
            recorder.start();
            recorder.refreshMarkets();
            sentBefore = numel(transport.Sent);

            ingestText(recorder, "{""id"":3,""type"":""subscribed"",""msg"":{""channel"":""orderbook_delta"",""sid"":7}}");
            ingestText(recorder, "{""type"":""orderbook_snapshot"",""sid"":7,""seq"":1,""msg"":{""market_ticker"":""" + testCase.TickerA + """}}");
            ingestText(recorder, "{""type"":""orderbook_delta"",""sid"":7,""seq"":2,""msg"":{""market_ticker"":""" + testCase.TickerA + """}}");

            testCase.verifyEqual(numel(transport.Sent), sentBefore);
        end

        function testMarketRollUpdatesSubscriptionAndRecordsSettlement(testCase)
            [recorder, transport, client, folder] = makeRecorder(testCase);
            client.OpenTickers = testCase.TickerA;
            recorder.start();
            recorder.refreshMarkets();
            ingestText(recorder, "{""id"":3,""type"":""subscribed"",""msg"":{""channel"":""orderbook_delta"",""sid"":7}}");

            client.OpenTickers = testCase.TickerB;
            client.Results(char(testCase.TickerA)) = 'yes';
            recorder.refreshMarkets();
            recorder.flush();

            updates = {};
            actions = strings(0, 1);
            for k = 1:numel(transport.Sent)
                if string(transport.Sent{k}.cmd) == "update_subscription"
                    updates{end + 1} = transport.Sent{k}; %#ok<AGROW>
                    actions(end + 1, 1) = string(transport.Sent{k}.params.action);
                end
            end

            testCase.verifyTrue(any(actions == "add_markets"));
            testCase.verifyTrue(any(actions == "delete_markets"));

            addCommand = updates{find(actions == "add_markets", 1)};
            testCase.verifyEqual(string(addCommand.params.market_tickers{1}), testCase.TickerB);
            testCase.verifyEqual(recorder.ActiveTickers, testCase.TickerB);

            records = readRecords(folder);
            settled = records(sourcesOf(records) == "rest_settlement");
            testCase.verifyEqual(numel(settled), 1);
            testCase.verifyEqual(string(settled{1}.raw.market.result), "yes");
        end

        function testRunRecordsAndShutsDownCleanly(testCase)
            [recorder, transport, client, folder] = makeRecorder(testCase, UseFixedClock=false);
            client.OpenTickers = testCase.TickerA;

            recorder.run(Duration=0.3, PollTimeout=0.05);

            testCase.verifyEqual(transport.ConnectCount, 1);
            testCase.verifyFalse(transport.IsConnected);
            testCase.verifyFalse(recorder.Running);

            records = readRecords(folder);
            testCase.verifyTrue(any(sourcesOf(records) == "rest_market"));
        end
    end
end

function [recorder, transport, client, folder] = makeRecorder(testCase, options)
    arguments
        testCase
        options.UseFixedClock (1, 1) logical = true
    end

    fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = fixture.Folder;
    transport = kalshiTest.FakeWebSocketTransport();
    ws = kalshi.WebSocketClient(kalshi.Config.demo(), Transport=transport);
    client = kalshiTest.FakeMarketClient();

    recorderArgs = {"OutputFolder", folder, "Client", client, "WebSocketFactory", @() ws};
    if options.UseFixedClock
        recorderArgs = [recorderArgs, {"Clock", @() 1730000000000}];
    end

    recorder = kalshi.Recorder(kalshi.Config.demo(), recorderArgs{:});
    recorder.Verbose = false;
end

function channels = sentChannels(transport)
    channels = strings(numel(transport.Sent), 1);
    for k = 1:numel(transport.Sent)
        channels(k) = string(transport.Sent{k}.params.channels{1});
    end
end

function sources = sourcesOf(records)
    sources = strings(numel(records), 1);
    for k = 1:numel(records)
        sources(k) = string(records{k}.src);
    end
end

function ingestText(recorder, rawText)
    recorder.ingest(jsondecode(rawText), rawText);
end

function records = readRecords(folder)
    files = dir(fullfile(folder, "kxbtc15m", "*.jsonl"));
    records = {};
    for k = 1:numel(files)
        lines = readlines(fullfile(files(k).folder, files(k).name));
        lines = lines(strlength(lines) > 0);
        for j = 1:numel(lines)
            records{end + 1} = jsondecode(char(lines(j))); %#ok<AGROW>
        end
    end
end
