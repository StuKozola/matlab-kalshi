classdef tConfig < matlab.unittest.TestCase
    %tConfig Tests configuration and formatting helpers.

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            repoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repoRoot, "src"), IncludingSubfolders=true));
        end
    end

    methods (Test)
        function testDemoDefaults(testCase)
            config = kalshi.Config.demo();

            testCase.verifyEqual(config.Environment, "demo");
            testCase.verifyEqual(config.BaseUrl, ...
                "https://external-api.demo.kalshi.co/trade-api/v2");
            testCase.verifyEqual(config.WebSocketUrl, ...
                "wss://external-api-ws.demo.kalshi.co/trade-api/ws/v2");
        end

        function testProductionDefaults(testCase)
            config = kalshi.Config.production(EnableProductionTrading=true);

            testCase.verifyEqual(config.Environment, "prod");
            testCase.verifyEqual(config.BaseUrl, ...
                "https://external-api.kalshi.com/trade-api/v2");
            testCase.verifyTrue(config.EnableProductionTrading);
        end

        function testFixedPointFormatting(testCase)
            testCase.verifyEqual(kalshi.formatPrice(0.56), "0.5600");
            testCase.verifyEqual(kalshi.formatCount(10), "10.00");
        end

        function testFromDotEnvUsesLocalPemFallback(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            dotEnvPath = fullfile(fixture.Folder, ".env");
            keyPath = fullfile(fixture.Folder, "kalshi_private_key.pem");
            writelines("KALSHI_API_KEY_ID=test-key-id", dotEnvPath);
            writelines("placeholder", keyPath);

            config = kalshi.Config.fromDotEnv(dotEnvPath);

            testCase.verifyEqual(config.Environment, "demo");
            testCase.verifyEqual(config.ApiKeyId, "test-key-id");
            testCase.verifyEqual(config.PrivateKeyPath, string(keyPath));
        end
    end
end
