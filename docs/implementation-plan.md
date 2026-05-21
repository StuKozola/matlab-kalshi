# Kalshi MATLAB Interface Implementation Plan

## Scope

Build a MATLAB package under `src/+kalshi` for Kalshi REST and WebSocket access. Start with demo-safe reads, then authenticated portfolio reads, then trading methods guarded by production opt-in.

## API Foundations

- Use explicit `demo` and `prod` environments because Kalshi credentials are environment-specific.
- REST base URLs:
  - Demo: `https://external-api.demo.kalshi.co/trade-api/v2`
  - Production: `https://external-api.kalshi.com/trade-api/v2`
- WebSocket URLs:
  - Demo: `wss://external-api-ws.demo.kalshi.co/trade-api/ws/v2`
  - Production: `wss://external-api-ws.kalshi.com/trade-api/ws/v2`

Source: https://docs.kalshi.com/getting_started/api_environments

## Authentication

Authenticated requests use `KALSHI-ACCESS-KEY`, `KALSHI-ACCESS-TIMESTAMP`, and `KALSHI-ACCESS-SIGNATURE`. Sign `timestamp + method + pathWithoutQuery` using RSA-PSS SHA-256 and base64 encode the signature. For WebSockets, sign `/trade-api/ws/v2`.

Source: https://docs.kalshi.com/getting_started/quick_start_authenticated_requests

## REST Milestones

1. Public market data: series, events, markets, orderbooks, trades.
2. Cursor pagination helper for list endpoints.
3. Authenticated portfolio reads: balance, positions, orders, fills, API limits.
4. Trading through the V2 event-market order endpoint `/portfolio/events/orders`.
5. Retry/backoff for `429` rate-limit responses. `GET` requests may also retry transient `5xx` responses.

Sources:

- https://docs.kalshi.com/getting_started/quick_start_market_data
- https://docs.kalshi.com/getting_started/pagination
- https://docs.kalshi.com/api-reference/orders/create-order-v2
- https://docs.kalshi.com/getting_started/rate_limits

## Fixed-Point Data

Use fixed-point strings for prices and counts:

- `kalshi.formatPrice(0.56)` -> `"0.5600"`
- `kalshi.formatCount(10)` -> `"10.00"`

Source: https://docs.kalshi.com/getting_started/fixed_point_migration

## WebSocket Milestones

1. Authenticated connection and command send/receive.
2. Subscription management for `subscribe`, `unsubscribe`, `list_subscriptions`, and `update_subscription`.
3. Public channels: `ticker`, `trade`, `orderbook_delta`.
4. Private channels: `user_orders`, `fill`, `market_positions`.
5. `OrderbookStream` state manager using snapshots and deltas with sequence validation.
6. Reconnect and resubscribe workflow.

Sources:

- https://docs.kalshi.com/getting_started/quick_start_websockets
- https://docs.kalshi.com/websockets/websocket-connection
- https://docs.kalshi.com/websockets/orderbook-updates
- https://docs.kalshi.com/websockets/market-ticker

## Testing

Keep default tests offline by injecting fake transports. Cover URL construction, query encoding, signature paths, fixed-point formatting, retry behavior, order request bodies, WebSocket command JSON, and orderbook snapshot/delta behavior.

Live tests live under `tests/integration/` and are guarded by environment variables so they cannot place demo orders during normal builds.
