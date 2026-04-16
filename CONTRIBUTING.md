# Contributing to SwiftF1Telemetry

Thank you for considering a contribution to `SwiftF1Telemetry`.

This project aims to provide a Swift-native Formula 1 telemetry library with real archive-backed data access, typed models, and chart-ready outputs. Contributions are welcome across code, tests, documentation, validation, and tooling.

## Before You Start

Please keep these goals in mind when contributing:

- preserve a clean and small public API
- prefer typed Swift-first models over loosely structured payloads
- keep the library practical for real telemetry workflows
- favor correctness and validation over feature count
- document behavior clearly, especially where FastF1 parity is not yet complete

## Good Contribution Areas

Contributions are especially helpful in these areas:

- parser correctness and resilience
- telemetry comparison accuracy
- FastF1 parity checks
- lap-building heuristics
- cache behavior and platform portability
- test coverage
- documentation improvements
- CLI improvements for inspection and debugging

## Development Setup

Clone the repository and run:

```bash
swift test
```

You can also run the CLI manually:

```bash
swift run f1-cli 2024 Monza Q 16
```

## Code Style Expectations

When contributing code:

- keep the implementation straightforward and readable
- avoid unnecessary abstraction
- prefer small focused types and functions
- use ASCII unless the file already requires something else
- keep comments concise and useful
- do not add speculative APIs without a clear use case

## Public API Changes

The package's public user documentation lives in the repository `docs/` folder.

If you change the public API:

- update `README.md` when the user-facing workflow changes
- update the relevant pages in `docs/`
- update `CHANGELOG.md`
- add or adjust tests

Public API additions should be intentional and well documented.

## Testing

Every functional change should include validation where appropriate.

Examples:

- parser changes should include parser tests
- telemetry processing changes should include processing tests
- public workflow changes should include end-to-end style tests through `Session` or `F1Client` when possible

Before opening a pull request, run:

```bash
swift test
```

## Issues and Pull Requests

When opening an issue or pull request, please describe:

- what you changed
- why it is needed
- any FastF1 reference behavior if relevant
- any known tradeoffs or limitations

Small, focused pull requests are easier to review and merge than large mixed changes.

## Validation Against FastF1

For behavior that is intended to resemble FastF1, please be explicit about:

- what session you compared against
- what drivers or laps you checked
- what matched
- what still differs

This helps keep parity discussions concrete and reproducible.

## License

By contributing to this repository, you agree that your contributions will be licensed under the MIT License included in this repository.
