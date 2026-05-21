classdef tAuthSigner < matlab.unittest.TestCase
    %tAuthSigner Tests Kalshi signature canonicalization helpers.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testRequestPathExcludesQuery(testCase)
            path = kalshi.AuthSigner.requestPath( ...
                "https://external-api.demo.kalshi.co/trade-api/v2", ...
                "/markets?limit=10");

            testCase.verifyEqual(path, "/trade-api/v2/markets");
        end

        function testRequestPathNormalizesFullUrl(testCase)
            path = kalshi.AuthSigner.requestPath( ...
                "https://external-api.demo.kalshi.co/trade-api/v2", ...
                "https://external-api.demo.kalshi.co/trade-api/v2/portfolio/balance");

            testCase.verifyEqual(path, "/trade-api/v2/portfolio/balance");
        end

        function testCreateMessage(testCase)
            message = kalshi.AuthSigner.createMessage( ...
                "1710000000000", "get", "/trade-api/v2/markets?limit=1");

            testCase.verifyEqual(message, "1710000000000GET/trade-api/v2/markets");
        end
    end
end
