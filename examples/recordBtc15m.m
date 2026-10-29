% recordBtc15m Record KXBTC15M order books, trades, and BRTI ticks to data/kxbtc15m/.
%
% Recording only reads market data and never places orders. Credentials come
% from .env (see .env.example and docs/credentials.md). Press Ctrl-C to stop;
% buffered data is flushed on exit.

repoRoot = fullfile(fileparts(mfilename("fullpath")), "..");
addpath(fullfile(repoRoot, "src"));

config = kalshi.Config.fromDotEnv(fullfile(repoRoot, ".env"));
recorder = kalshi.Recorder(config, OutputFolder=fullfile(repoRoot, "data"));
recorder.run();
