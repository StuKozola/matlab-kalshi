classdef Config
    %Config Kalshi API environment and credential configuration.

    properties
        Environment (1, 1) string {mustBeMember(Environment, ["demo", "prod"])} = "demo"
        BaseUrl (1, 1) string = "https://external-api.demo.kalshi.co/trade-api/v2"
        WebSocketUrl (1, 1) string = "wss://external-api-ws.demo.kalshi.co/trade-api/ws/v2"
        ApiKeyId (1, 1) string = ""
        PrivateKeyPath (1, 1) string = ""
        Timeout (1, 1) double {mustBePositive} = 30
        EnableProductionTrading (1, 1) logical = false
    end

    methods
        function obj = Config(options)
            arguments
                options.Environment (1, 1) string {mustBeMember(options.Environment, ["demo", "prod"])} = "demo"
                options.BaseUrl (1, 1) string = ""
                options.WebSocketUrl (1, 1) string = ""
                options.ApiKeyId (1, 1) string = ""
                options.PrivateKeyPath (1, 1) string = ""
                options.Timeout (1, 1) double {mustBePositive} = 30
                options.EnableProductionTrading (1, 1) logical = false
            end

            obj.Environment = lower(options.Environment);
            obj.BaseUrl = kalshi.Config.defaultBaseUrl(obj.Environment);
            obj.WebSocketUrl = kalshi.Config.defaultWebSocketUrl(obj.Environment);

            if strlength(options.BaseUrl) > 0
                obj.BaseUrl = eraseBetweenTrailingSlash(options.BaseUrl);
            end

            if strlength(options.WebSocketUrl) > 0
                obj.WebSocketUrl = eraseBetweenTrailingSlash(options.WebSocketUrl);
            end

            obj.ApiKeyId = options.ApiKeyId;
            obj.PrivateKeyPath = options.PrivateKeyPath;
            obj.Timeout = options.Timeout;
            obj.EnableProductionTrading = options.EnableProductionTrading;
        end

        function tf = hasCredentials(obj)
            %hasCredentials Return true when API key ID and private key path are configured.
            tf = strlength(obj.ApiKeyId) > 0 && strlength(obj.PrivateKeyPath) > 0;
        end
    end

    methods (Static)
        function obj = demo(options)
            %demo Create configuration for the Kalshi demo environment.
            arguments
                options.ApiKeyId (1, 1) string = ""
                options.PrivateKeyPath (1, 1) string = ""
                options.Timeout (1, 1) double {mustBePositive} = 30
            end

            obj = kalshi.Config( ...
                Environment="demo", ...
                ApiKeyId=options.ApiKeyId, ...
                PrivateKeyPath=options.PrivateKeyPath, ...
                Timeout=options.Timeout);
        end

        function obj = production(options)
            %production Create configuration for the Kalshi production environment.
            arguments
                options.ApiKeyId (1, 1) string = ""
                options.PrivateKeyPath (1, 1) string = ""
                options.Timeout (1, 1) double {mustBePositive} = 30
                options.EnableProductionTrading (1, 1) logical = false
            end

            obj = kalshi.Config( ...
                Environment="prod", ...
                ApiKeyId=options.ApiKeyId, ...
                PrivateKeyPath=options.PrivateKeyPath, ...
                Timeout=options.Timeout, ...
                EnableProductionTrading=options.EnableProductionTrading);
        end

        function obj = fromEnvironment()
            %fromEnvironment Create configuration from KALSHI_* environment variables.
            env = string(getenv("KALSHI_ENV"));
            if strlength(env) == 0
                env = "demo";
            end

            obj = kalshi.Config( ...
                Environment=lower(env), ...
                ApiKeyId=string(getenv("KALSHI_API_KEY_ID")), ...
                PrivateKeyPath=string(getenv("KALSHI_PRIVATE_KEY_PATH")));
        end

        function baseUrl = defaultBaseUrl(environment)
            arguments
                environment (1, 1) string {mustBeMember(environment, ["demo", "prod"])}
            end

            if environment == "prod"
                baseUrl = "https://external-api.kalshi.com/trade-api/v2";
            else
                baseUrl = "https://external-api.demo.kalshi.co/trade-api/v2";
            end
        end

        function webSocketUrl = defaultWebSocketUrl(environment)
            arguments
                environment (1, 1) string {mustBeMember(environment, ["demo", "prod"])}
            end

            if environment == "prod"
                webSocketUrl = "wss://external-api-ws.kalshi.com/trade-api/ws/v2";
            else
                webSocketUrl = "wss://external-api-ws.demo.kalshi.co/trade-api/ws/v2";
            end
        end
    end
end

function value = eraseBetweenTrailingSlash(value)
    value = regexprep(string(value), "/+$", "");
end
