% subscribeTicker Subscribe to Kalshi ticker updates over WebSocket.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));

ws = kalshi.WebSocketClient(config);
cleanup = onCleanup(@() ws.close());
ws.connect();

client = kalshi.Client(config);
markets = client.getMarkets(Status="open", Limit=1);
ticker = string(markets.markets{1}.ticker);
ws.subscribe("ticker", MarketTickers=ticker);

message = ws.receive(Timeout=10);
disp(message)
