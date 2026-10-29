# matlab-kalshi

MATLAB interface for the Kalshi Trade API. The package currently provides a REST client, RSA-PSS request signing hooks, fixed-point formatting helpers, and a WebSocket client abstraction with a Python-backed transport.

## Layout

```text
src/+kalshi/                 MATLAB package source
src/+kalshi/+internal/        Internal HTTP/WebSocket helpers
tests/                        matlab.unittest tests
examples/                     Small demo scripts
docs/                         Implementation notes and roadmap
```

## Quick Start

Add the package to the MATLAB path:

```matlab
addpath("src")
client = kalshi.Client(kalshi.Config.demo());
markets = client.getMarkets(Status="open", Limit=5);
marketsTable = client.getMarketsTable(Status="open", Limit=20);
```

Authenticated requests require a Kalshi API key ID and RSA private key path:

```matlab
config = kalshi.Config.fromDotEnv();
client = kalshi.Client(config);
balance = client.getBalance();
```

`Config.fromDotEnv()` reads `KALSHI_API_KEY_ID`, optional `KALSHI_ENV`, and optional `KALSHI_PRIVATE_KEY_PATH`. If no key path is set, it uses `kalshi_private_key.pem` beside `.env` when present.

Production trading is disabled unless explicitly enabled:

```matlab
config = kalshi.Config.production( ...
    ApiKeyId=getenv("KALSHI_API_KEY_ID"), ...
    PrivateKeyPath=getenv("KALSHI_PRIVATE_KEY_PATH"), ...
    EnableProductionTrading=true);
```

## WebSockets

Kalshi WebSocket connections require authenticated handshake headers. The MATLAB wrapper uses a Python backend based on the `websockets` package:

```matlab
ws = kalshi.WebSocketClient(config);
ws.connect()
ws.subscribe("ticker", MarketTickers=["KXHIGHNY-26MAY21-T80"]);
msg = ws.receive(Timeout=5);
```

Install Python dependencies in the MATLAB-selected Python environment:

```powershell
python -m pip install cryptography websockets
```

## Recording BTC 15-minute data

`kalshi.Recorder` records the `KXBTC15M` series for later backtesting: order book snapshots and deltas, ticker updates, public trades, the CF Benchmarks BRTI feed (1 Hz with the settlement averages, plus the 5 Hz feed), market metadata (including `floor_strike`), and settlement results. It only reads data and never places orders.

Set up credentials first (see [docs/credentials.md](docs/credentials.md)), then run:

```matlab
run("examples/recordBtc15m.m")
```

Or from code:

```matlab
config = kalshi.Config.fromDotEnv();
recorder = kalshi.Recorder(config, OutputFolder="data");
recorder.run(Duration=3600)   % seconds; omit to run until Ctrl-C
```

Data is written to `data/kxbtc15m/<yyyymmdd>.jsonl` (UTC date), one line per message:

```json
{"t_recv_ms":1730000000000,"src":"ws","raw":{"type":"orderbook_delta","sid":7,"seq":42,"msg":{}}}
```

`src` is `ws` (verbatim WebSocket message), `rest_market` (market metadata), `rest_settlement` (settled market with its result), or `recorder` (sequence gaps, reconnects, errors). `t_recv_ms` is the local time the recorder processed the message, so keep the machine clock synced (NTP). Messages are processed in order and are not individually timestamped by the Python transport, so treat `t_recv_ms` as accurate to roughly the poll interval under heavy load.

The recorder follows each 15-minute market roll by adding and removing markets on its subscriptions, reconnects with backoff after errors, and requests a fresh order book snapshot when it sees a sequence gap.

## Tests

Run the unit tests from MATLAB:

```matlab
addpath("src")
results = runtests("tests");
assertSuccess(results)
```

Or from a shell:

```powershell
matlab -batch "addpath('src'); results = runtests('tests'); assertSuccess(results)"
```

`buildtool` runs the offline suite only:

```powershell
matlab -batch "buildtool"
```

Live demo integration tests are opt-in. Balance/WebSocket-style live checks require `KALSHI_RUN_INTEGRATION=true`; demo order placement/cancel additionally requires `KALSHI_RUN_TRADING_INTEGRATION=true`.

```powershell
$env:KALSHI_RUN_INTEGRATION="true"
$env:KALSHI_RUN_TRADING_INTEGRATION="true"
matlab -batch "buildtool integrationTest"
```

REST requests retry `429` with exponential backoff. `GET` requests also retry transient `5xx` responses; write requests do not retry `5xx` by default.

## Packaging

Create an installable toolbox file:

```matlab
buildtool package
```

The packaging script stages only distributable files under `build/` and writes `release/matlab-kalshi.mltbx`. Secrets, tests, Git metadata, and local `.env` files are excluded.

## CI

GitHub Actions runs the default offline `buildtool` task on pushes and pull requests. Live integration tests are intentionally manual because they require credentials and, for trading coverage, explicit demo order-placement flags.
