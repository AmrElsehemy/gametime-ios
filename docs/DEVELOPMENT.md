# GameTimeKit Development

## Role of this repository

`gametime-ios` is shared platform code only. Game-specific rules, levels, artwork, product copy and release assets belong in each game's own repository.

## Local package development

During active development, a game repo may reference a local checkout of this package from Xcode using **Add Local Package**. A typical workspace layout is:

```text
~/Work/GameTime/
├── gametime-ios/
└── gametime-nine-ios/
```

This allows rapid iteration across the game and shared package without copying code or using git submodules.

## Tagged consumption

Shipped games should pin a known-good GameTimeKit release tag through Swift Package Manager. Do not let a live game silently follow `master`.

Example intent:

```swift
.package(
    url: "https://github.com/AmrElsehemy/gametime-ios.git",
    exact: "0.1.0"
)
```

Create a new tag only after tests pass and the package is suitable for at least one consuming game release.

## Initial module boundaries

- `GameTimeCore`: deterministic/shared primitives, time/RNG contracts, build metadata, future replay contracts.
- `GameTimeExperience`: reusable sensory/interaction contracts and helpers; Apple-specific implementations can be added behind these APIs.
- `GameTimeServices`: analytics, diagnostics, remote-config and platform-service adapters.
- `GameTimeCommerce`: rewarded-value and StoreKit/ad abstractions; no game-specific economy rules.
- `GameTimeTesting`: deterministic clocks, fakes, recording adapters and fixtures for consuming games.

## Extraction rule

Do not add generic mechanic engines just because we can imagine them. Implement mechanics inside the first game, observe actual duplication in later games, then extract only stable reusable semantics.

## Validation

Run:

```bash
swift test
```

The GitHub Actions workflow also runs tests on macOS for pull requests and pushes to the default branch.
