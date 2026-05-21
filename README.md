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
```

Authenticated requests require a Kalshi API key ID and RSA private key path:

```matlab
config = kalshi.Config.demo( ...
    ApiKeyId=getenv("KALSHI_API_KEY_ID"), ...
    PrivateKeyPath=getenv("KALSHI_PRIVATE_KEY_PATH"));
client = kalshi.Client(config);
balance = client.getBalance();
```

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
