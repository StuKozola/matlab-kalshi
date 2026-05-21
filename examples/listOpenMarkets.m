% listOpenMarkets Fetch a small page of open Kalshi markets.

addpath(fullfile(fileparts(mfilename("fullpath")), "..", "src"));

client = kalshi.Client(kalshi.Config.demo());
response = client.getMarkets(Status="open", Limit=5);
disp(response.markets)
