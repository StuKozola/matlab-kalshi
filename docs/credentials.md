# Credential Setup

Kalshi authenticates each request with a signature made from a private key you hold. Nothing secret is ever committed: `.env`, `*.pem`, and `*.key` are git-ignored.

## 1. Pick an environment

| Environment | Use it for | Sign up |
| - | - | - |
| `prod` | Recording real `KXBTC15M` data. The BRTI feed and live order books are real here. | https://kalshi.com |
| `demo` | Trying the client with mock funds. Markets and prices may not match real ones. | https://demo.kalshi.co |

Keys are **not shared** between environments. A production key does not work on demo and the reverse. The recorder only reads market data, and `kalshi.Config.production()` keeps trading disabled unless you pass `EnableProductionTrading=true`, so a production key is safe to use for recording.

## 2. Create an API key

1. Sign in and open https://kalshi.com/account/profile (demo: the same page on https://demo.kalshi.co).
2. In the **API Keys** section choose **Create New API Key**.
3. Pick **Ed25519** (default) or **RSA**. Both work with this package.
4. Copy the **private key** immediately and save it as `kalshi_private_key.pem` in the repository root. Kalshi shows it once and does not store it.
5. Copy the **Key ID**.

You can also generate your own pair and paste only the public key into Kalshi:

```bash
openssl genpkey -algorithm ed25519 -out kalshi_private_key.pem
openssl pkey -in kalshi_private_key.pem -pubout -out kalshi.pub
```

## 3. Create `.env`

Copy `.env.example` to `.env` in the repository root and fill it in:

```text
KALSHI_ENV=prod
KALSHI_API_KEY_ID=<your key id>
KALSHI_PRIVATE_KEY_PATH=
```

Leave `KALSHI_PRIVATE_KEY_PATH` empty to use `kalshi_private_key.pem` beside `.env`. Set it to an absolute path to keep the key elsewhere.

## 4. Install the Python helpers

Signing and WebSockets run through Python. Install the packages into the Python that MATLAB uses (`pyenv` shows it):

```powershell
python -m pip install cryptography websockets
```

## 5. Check it works

```matlab
addpath("src")
config = kalshi.Config.fromDotEnv();
client = kalshi.Client(config);
client.getBalance()        % authenticated; confirms the key and signature
```

Then start recording with `examples/recordBtc15m.m`.

## Security notes

- Never paste the private key or Key ID into chat, issues, or commits.
- If a key leaks, delete it on the Kalshi API Keys page and create a new one.
- Use separate keys for recording and for any future trading code.
