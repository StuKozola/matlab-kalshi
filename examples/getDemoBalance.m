% getDemoBalance Fetch demo account balance with authenticated REST.

addpath(fullfile(fileparts(mfilename("fullpath")), "..", "src"));

config = kalshi.Config.demo( ...
    ApiKeyId=string(getenv("KALSHI_API_KEY_ID")), ...
    PrivateKeyPath=string(getenv("KALSHI_PRIVATE_KEY_PATH")));
client = kalshi.Client(config);
balance = client.getBalance();
disp(balance)
