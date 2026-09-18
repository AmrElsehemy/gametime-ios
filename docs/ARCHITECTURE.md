# Game Time Architecture

## Guiding rule

Game rules and state are framework-independent. SpriteKit/UIKit render state; they do not own the rules.

## Runtime layers

### GameTimeCore
Owns:
- game/level state
- objective model
- deterministic timing where needed
- persistence contracts
- undo/history contracts
- replay event contracts

### GameTimeExperience
Owns:
- SpriteKit helpers
- semantic motion (`swap`, `drop`, `merge`, `pour`, `exit`, `collect`, `explode`)
- juice/celebration levels
- particles/trails/shake
- Core Haptics
- AVFoundation audio
- tutorial primitives

### GameTimeServices
Owns adapters/interfaces for:
- Game Center
- analytics
- crash/non-fatal diagnostics
- remote config
- support diagnostics

### GameTimeCommerce
Owns:
- reward offers
- ad provider abstraction
- StoreKit products/entitlements
- wallet/inventory abstractions when a game needs them
- centrally enforced ad policy

### GameTimeTesting
Owns:
- mocks/fakes
- deterministic clocks/RNG
- replay fixtures
- level validators
- performance test helpers

## Rendering strategy

Use SpriteKit for most single-screen game rendering and interaction. Use UIKit/Core Animation for ordinary shell/UI where cleaner. Use SpriteKit physics only when emergent physical behavior is part of the fun; prefer deterministic logical collision for grid/routing games. Use Metal only as a performance escape hatch for effects or mass-entity rendering.

## Mechanic extraction rule

Do not create generic `PathEngine`, `StackEngine`, `RoutingEngine`, etc. before evidence.

1. Implement Game #001 mechanic locally.
2. Build Game #002.
3. Extract only duplicated abstractions with stable semantics.
4. Keep unique gameplay local to each title.

## Persistence

Local-first. Version persisted state from the start so migrations are testable.

## Networking

Gameplay must degrade gracefully to fully offline behavior. Remote config and LiveOps may enhance behavior but may never be required to launch or continue ordinary play.

## Backend contract

Remote values are data only. Every remotely controlled behavior must have:
- bundled default
- cached last-known-good value
- validation
- kill switch where appropriate

## Replay

A replayable deterministic title records a compact stream of player intent, not video. Minimum identity:
- game build/version
- level definition version
- RNG seed
- input/event sequence

Replay is used for QA, support and marketing capture.
