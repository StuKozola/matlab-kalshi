% subscribeTicker Subscribe to Kalshi ticker updates over WebSocket.

addpath(fullfile(fileparts(mfilename("fullpath")), "..", "src"));

config = kalshi.Config.demo( ...
    ApiKeyId=string(getenv("KALSHI_API_KEY_ID")), ...
    PrivateKeyPath=string(getenv("KALSHI_PRIVATE_KEY_PATH")));

ws = kalshi.WebSocketClient(config);
cleanup = onCleanup(@() ws.close());
ws.connect();
ws.subscribe("ticker");
message = ws.receive(Timeout=10);
disp(message)
