% streamOrderbook Subscribe to live orderbook deltas for one open market.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));
client = kalshi.Client(config);
markets = client.getMarkets(Status="open", Limit=1);
ticker = string(markets.markets{1}.ticker);

ws = kalshi.WebSocketClient(config);
cleanup = onCleanup(@() ws.close());
ws.connect();
ws.subscribe("orderbook_delta", MarketTickers=ticker);

for k = 1:5
    event = ws.receiveEvent(Timeout=10);
    if ~isempty(event)
        fprintf("%s\n", event.Type);
        disp(event.Data)
    end
end
