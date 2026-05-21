# Repository Guidelines

## Project Structure & Module Organization

This workspace is currently minimal, so keep new files organized from the start. Place MATLAB source in `src/`, tests in `tests/`, examples in `examples/`, and reusable data or static assets in `resources/`. Keep top-level files limited to project metadata, documentation, and build entry points such as `README.md`, `buildfile.m`, or `AGENTS.md`.

For MATLAB packages, prefer package folders such as `src/+kalshi/` and class folders only when MATLAB requires them. Example layout:

```text
src/+kalshi/
tests/
examples/
resources/
```

## Build, Test, and Development Commands

Use MATLAB batch commands so work can run consistently in local terminals and CI:

```powershell
matlab -batch "addpath('src'); runtests('tests')"
```

Runs the test suite after adding source files to the path.

```powershell
matlab -batch "buildtool"
```

Runs the project build if a `buildfile.m` is added. Prefer adding common validation tasks there as the repository grows.

## Coding Style & Naming Conventions

Use 4-space indentation in MATLAB code. Name functions and variables with clear lower camel case, for example `fetchMarkets` or `apiKey`. Use package-qualified public APIs under `+kalshi` when possible to avoid path conflicts. Keep scripts for demos only; production behavior should live in functions or classes.

Run MATLAB Code Analyzer before committing substantial changes and resolve warnings unless there is a documented reason not to.

## Testing Guidelines

Use `matlab.unittest` tests under `tests/`. Name test files after the behavior under test, such as `TestMarketClient.m`, and keep fixtures small and deterministic. Tests that touch external services should be clearly marked or isolated from the default suite; prefer mocked HTTP responses for routine validation.

## Commit & Pull Request Guidelines

No local Git history is available in this checkout, so use concise imperative commit messages, for example `Add market client tests` or `Document API configuration`. Pull requests should include a short summary, test results, linked issues when applicable, and screenshots only for UI or visual changes.

## Security & Configuration Tips

Do not commit API keys, tokens, or account identifiers. Load secrets from environment variables or an ignored local file such as `.env`. Keep sample configuration files sanitized, and document required variable names without including real values.
