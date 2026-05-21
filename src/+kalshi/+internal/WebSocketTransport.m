classdef WebSocketTransport < handle
    %WebSocketTransport Python-backed WebSocket transport for Kalshi.

    properties (SetAccess = private)
        Url (1, 1) string
        Headers cell
        Timeout (1, 1) double = 30
        Backend
    end

    methods
        function obj = WebSocketTransport(url, headers, options)
            arguments
                url (1, 1) string
                headers cell = {}
                options.Timeout (1, 1) double {mustBePositive} = 30
            end

            obj.Url = url;
            obj.Headers = headers;
            obj.Timeout = options.Timeout;
        end

        function connect(obj)
            module = loadPythonBackend();
            headerItems = kalshi.internal.headerCellsToItems(obj.Headers);
            headersJson = jsonencode(headerItems);
            obj.Backend = module.KalshiWebSocketTransport(char(obj.Url), char(headersJson), obj.Timeout);
            obj.Backend.connect();
        end

        function send(obj, payload)
            obj.assertConnected();
            obj.Backend.send_json(char(jsonencode(payload)));
        end

        function message = receive(obj, timeout)
            arguments
                obj (1, 1) kalshi.internal.WebSocketTransport
                timeout (1, 1) double {mustBeNonnegative} = 0
            end

            obj.assertConnected();
            rawMessage = obj.Backend.receive(timeout);
            if isequal(rawMessage, py.None)
                message = [];
            else
                message = string(rawMessage);
            end
        end

        function close(obj)
            if ~isempty(obj.Backend)
                obj.Backend.close();
            end
        end
    end

    methods (Access = private)
        function assertConnected(obj)
            if isempty(obj.Backend)
                error("kalshi:WebSocketTransport:NotConnected", ...
                    "WebSocket transport is not connected.");
            end
        end
    end
end

function module = loadPythonBackend()
    helperFolder = fullfile(fileparts(mfilename("fullpath")), "python");
    if ~pythonPathContains(helperFolder)
        insert(py.sys.path, int32(0), helperFolder);
    end

    try
        module = py.importlib.import_module("kalshi_ws_transport");
        module = py.importlib.reload(module);
    catch exception
        throwAsCaller(MException( ...
            "kalshi:WebSocketTransport:PythonBackendUnavailable", ...
            "Unable to load Python WebSocket backend. Install the Python 'websockets' package and ensure MATLAB can import it. Original error: %s", ...
            exception.message));
    end
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
