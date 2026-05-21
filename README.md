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
