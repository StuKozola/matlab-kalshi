# TODO

## WebSocket Hardening

- Add a longer live WebSocket integration test that observes real `orderbook_delta` messages.
- Verify sequence progression across snapshots and deltas.
- Exercise automatic snapshot resync behavior after sequence gaps.

## Endpoint Coverage

- Add table helpers for events and series.
- Add a trades table helper.
- Expand filter coverage for orders, fills, and positions.
- Polish exchange status and API limits helpers.

## Toolbox Install Verification

- Install `release/matlab-kalshi.mltbx` into a clean MATLAB session.
- Verify examples run from the installed toolbox path, not the repository source path.

## Documentation

- Add API reference docs for public classes and functions.
- Add a Getting Started guide for toolbox users.
- Add credential setup docs covering demo and production separation.

## Release Automation

- Use the manual release workflow for the next release to verify the full automation path.
- Add a single version source so `tools/packageToolbox.m`, release notes, and Git tags stay aligned.

## CI Matrix

- Run offline tests on Windows and Linux.
- Test R2024b plus the latest MATLAB release.

## Production Readiness

- Add stronger safety rails around production trading.
- Improve typed API error data and error handling.
- Add optional request logging with secret redaction.
