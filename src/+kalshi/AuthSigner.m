classdef AuthSigner < handle
    %AuthSigner Creates Kalshi RSA-PSS authentication headers.

    properties (SetAccess = private)
        ApiKeyId (1, 1) string
        PrivateKeyPath (1, 1) string
    end

    methods
        function obj = AuthSigner(apiKeyId, privateKeyPath)
            arguments
                apiKeyId (1, 1) string
                privateKeyPath (1, 1) string
            end

            obj.ApiKeyId = apiKeyId;
            obj.PrivateKeyPath = privateKeyPath;
        end

        function headers = createHeaders(obj, method, signPath)
            %createHeaders Return KALSHI-ACCESS-* headers as an N-by-2 cell array.
            arguments
                obj (1, 1) kalshi.AuthSigner
                method (1, 1) string
                signPath (1, 1) string
            end

            timestamp = string(floor(posixtime(datetime("now", TimeZone="UTC")) * 1000));
            signature = obj.sign(timestamp, upper(method), signPath);

            headers = {
                "KALSHI-ACCESS-KEY", char(obj.ApiKeyId);
                "KALSHI-ACCESS-SIGNATURE", char(signature);
                "KALSHI-ACCESS-TIMESTAMP", char(timestamp)
            };
        end

        function signature = sign(obj, timestamp, method, signPath)
            %sign Sign timestamp + method + path using RSA-PSS SHA-256.
            arguments
                obj (1, 1) kalshi.AuthSigner
                timestamp (1, 1) string
                method (1, 1) string
                signPath (1, 1) string
            end

            message = kalshi.AuthSigner.createMessage(timestamp, method, signPath);
            signature = obj.signMessage(message);
        end

        function signature = signMessage(obj, message)
            %signMessage Return a base64 RSA-PSS signature for the supplied message.
            arguments
                obj (1, 1) kalshi.AuthSigner
                message (1, 1) string
            end

            if ~isfile(obj.PrivateKeyPath)
                error("kalshi:AuthSigner:PrivateKeyNotFound", ...
                    "Private key file not found: %s", obj.PrivateKeyPath);
            end

            try
                module = loadPythonAuthBackend();
                signature = string(module.sign_pem(char(obj.PrivateKeyPath), char(message)));
            catch exception
                throwAsCaller(MException( ...
                    "kalshi:AuthSigner:SigningFailed", ...
                    "Unable to sign Kalshi request. Ensure Python and the cryptography package can load the private key at '%s'. Original error: %s", ...
                    obj.PrivateKeyPath, exception.message));
            end
        end
    end

    methods (Static)
        function obj = fromConfig(config)
            %fromConfig Create a signer from a kalshi.Config instance.
            arguments
                config (1, 1) kalshi.Config
            end

            if ~config.hasCredentials()
                error("kalshi:AuthSigner:MissingCredentials", ...
                    "ApiKeyId and PrivateKeyPath are required for authenticated requests.");
            end

            obj = kalshi.AuthSigner(config.ApiKeyId, config.PrivateKeyPath);
        end

        function path = requestPath(baseUrl, endpoint)
            %requestPath Return the path Kalshi expects in the signature payload.
            arguments
                baseUrl (1, 1) string
                endpoint (1, 1) string
            end

            endpoint = kalshi.internal.normalizeEndpoint(endpoint);
            endpoint = extractBefore(endpoint + "?", "?");
            basePath = kalshi.AuthSigner.urlPath(baseUrl);
            path = basePath + endpoint;
        end

        function message = createMessage(timestamp, method, signPath)
            %createMessage Build the canonical string Kalshi signs.
            arguments
                timestamp (1, 1) string
                method (1, 1) string
                signPath (1, 1) string
            end

            signPath = extractBefore(signPath + "?", "?");
            message = timestamp + upper(method) + signPath;
        end

        function path = webSocketPath()
            %webSocketPath Return the canonical Kalshi WebSocket signing path.
            path = "/trade-api/ws/v2";
        end
    end

    methods (Static, Access = private)
        function path = urlPath(url)
            expression = "^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]+(?<path>/.*)?$";
            tokens = regexp(char(url), expression, "names");
            if isempty(tokens) || ~isfield(tokens, "path") || isempty(tokens.path)
                path = "";
            else
                path = string(regexprep(tokens.path, "/+$", ""));
            end
        end
    end
end

function module = loadPythonAuthBackend()
    helperFolder = fullfile(fileparts(mfilename("fullpath")), "+internal", "python");
    if ~pythonPathContains(helperFolder)
        insert(py.sys.path, int32(0), helperFolder);
    end

    module = py.importlib.import_module("kalshi_auth");
end

function tf = pythonPathContains(folder)
    tf = false;
    pythonPath = py.sys.path;
    for k = 1:int64(length(pythonPath))
        if string(pythonPath{k}) == string(folder)
            tf = true;
            return
        end
    end
end
