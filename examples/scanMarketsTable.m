% scanMarketsTable Fetch open markets as a table for quick inspection.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

client = kalshi.Client(kalshi.Config.demo());
markets = client.getMarketsTable(Status="open", Limit=20);
disp(markets(:, ["ticker", "status", "yes_bid_dollars", "yes_ask_dollars"]))
