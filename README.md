# Game Time iOS

Game Time is the internal native-iOS game platform for **Knowlly Games**.

This repository contains the reusable Swift/SpriteKit runtime, shared experience systems, commerce hooks, diagnostics, testing utilities, and reference implementation patterns used by Knowlly Games titles.

## Product goal

Build a portfolio of highly polished, easy-to-learn, replayable iOS games with a shared native foundation so each new title gets faster to prototype, ship, operate, monetize, and market.

## Non-negotiables

- Native Apple stack first: Swift, SpriteKit, Core Haptics, AVFoundation, UIKit/Core Animation, GameKit, StoreKit; Metal only when useful.
- No Unity/Godot or third-party gameplay/rendering dependency by default.
- Game logic is independent from rendering.
- Offline-first core gameplay.
- No proprietary login for v1; Game Center is the gaming identity layer where useful.
- Reward-led monetization; never manufacture frustration to sell relief.
- Tutorials teach through play; first interaction in seconds.
- Analytics, diagnostics, replayability, support, release operations and growth are part of the product, not afterthoughts.
- Public App Store release is the definition of done.

## Initial modules

- `GameTimeCore`
- `GameTimeExperience`
- `GameTimeServices`
- `GameTimeCommerce`
- `GameTimeTesting`

Mechanic-specific modules are extracted only after real reuse is proven by multiple shipped games.

## Build and test

```bash
swift test
```

The package currently targets iOS 17+ and macOS 14+ and is validated in CI on macOS.

## Using GameTimeKit from a game

During active development, add this repository as a **local Swift package** in Xcode so the game and platform can evolve together without copying code or using git submodules.

For shipped releases, games should pin a known-good GameTimeKit tag rather than follow `master`.

See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for the local-package and tagged-release workflow.

## Documentation

Start with [`docs/MASTER_PRD.md`](docs/MASTER_PRD.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and [`docs/ROADMAP_50_DAYS.md`](docs/ROADMAP_50_DAYS.md).
