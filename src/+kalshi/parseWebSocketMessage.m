function event = parseWebSocketMessage(message)
%parseWebSocketMessage Normalize a Kalshi WebSocket message envelope.

    if isempty(message)
        event = [];
        return
    end

    if isstring(message) || ischar(message)
        message = jsondecode(char(message));
    end

    event = struct( ...
        "Type", "", ...
        "Sid", NaN, ...
        "Seq", NaN, ...
        "Data", struct(), ...
        "Raw", message);

    if isfield(message, "type")
        event.Type = string(message.type);
    end

    if isfield(message, "sid")
        event.Sid = double(message.sid);
    end

    if isfield(message, "seq")
        event.Seq = double(message.seq);
    end

    if isfield(message, "msg")
        event.Data = message.msg;
    end
end
