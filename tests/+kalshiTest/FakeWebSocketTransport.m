classdef FakeWebSocketTransport < handle
    %FakeWebSocketTransport Test double for WebSocket transport.

    properties
        Sent = {}
        Messages = {}
        IsConnected = false
    end

    methods
        function obj = FakeWebSocketTransport(options)
            arguments
                options.Messages cell = {}
            end

            obj.Messages = options.Messages;
        end

        function connect(obj)
            obj.IsConnected = true;
        end

        function send(obj, payload)
            obj.Sent{end + 1} = payload;
        end

        function message = receive(obj, ~)
            message = obj.Messages{1};
            obj.Messages(1) = [];
        end

        function close(obj)
            obj.IsConnected = false;
        end
    end
end
