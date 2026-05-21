% getDemoBalance Fetch demo account balance with authenticated REST.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));
client = kalshi.Client(config);
balance = client.getBalance();
disp(balance)
