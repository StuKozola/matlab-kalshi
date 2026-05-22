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
stream = kalshi.OrderbookStream();
stream.subscribe(ws, ticker);

book = stream.receiveBook(ws, ticker, Timeout=10);
disp(book.yes)
disp(book.no)

for k = 1:20
    message = ws.receive(Timeout=5);
    if isempty(message)
        continue
    end

    stream.processMessage(message, WebSocketClient=ws);
    book = stream.getBook(ticker);
    fprintf("seq=%d yes_levels=%d no_levels=%d\n", ...
        book.seq, height(book.yes), height(book.no));
end
