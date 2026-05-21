% demoOrderLifecycle Place, look up, and cancel a small demo order.
%
% Requires .env and kalshi_private_key.pem in the repository root. This
% script submits a post-only one-cent demo bid and cancels it immediately.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));
assert(config.Environment == "demo", "This example is restricted to the demo environment.");

client = kalshi.Client(config);
markets = client.getMarkets(Status="open", Limit=1);
ticker = string(markets.markets{1}.ticker);
clientOrderId = kalshi.makeClientOrderId("matlab-example");

created = client.createOrder(ticker, clientOrderId, "bid", 1, 0.01, PostOnly=true);
cleanup = onCleanup(@() cancelOrderQuietly(client, string(created.order_id)));

order = client.getOrder(string(created.order_id));
disp(order.order)

canceled = client.cancelOrder(string(created.order_id));
disp(canceled)
delete(cleanup)

function cancelOrderQuietly(client, orderId)
    try
        client.cancelOrder(orderId);
    catch
    end
end
