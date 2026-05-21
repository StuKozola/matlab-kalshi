classdef tResponseNormalization < matlab.unittest.TestCase
    %tResponseNormalization Tests list normalization and table conversion.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testNormalizeStructArrayToCells(testCase)
            items = kalshi.normalizeList(struct("ticker", {"A", "B"}));

            testCase.verifyEqual(numel(items), 2);
            testCase.verifyEqual(string(items{1}.ticker), "A");
            testCase.verifyEqual(string(items{2}.ticker), "B");
        end

        function testNormalizeCellArrayShape(testCase)
            items = kalshi.normalizeList({struct("ticker", "A"), struct("ticker", "B")});

            testCase.verifySize(items, [2 1]);
            testCase.verifyEqual(string(items{2}.ticker), "B");
        end

        function testHeterogeneousStructsBecomeTable(testCase)
            items = {
                struct("ticker", "A", "yes_bid_dollars", "0.1000");
                struct("ticker", "B", "volume_fp", "10.00")
            };

            value = kalshi.toTable(items);

            testCase.verifyEqual(height(value), 2);
            testCase.verifyEqual(value.ticker(1), "A");
            testCase.verifyEqual(value.yes_bid_dollars(1), "0.1000");
            testCase.verifyEqual(value.volume_fp(2), "10.00");
        end
    end
end
