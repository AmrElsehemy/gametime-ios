# ADR 0001 — Native Apple Game Stack

## Status
Accepted

## Decision
Use Swift and Apple-native frameworks as the default Game Time runtime: SpriteKit, Core Haptics, AVFoundation, UIKit/Core Animation, GameKit, StoreKit 2, with GameplayKit/Metal used selectively.

## Consequences
- No Unity/Godot dependency for target game families.
- Small native binaries, direct Apple integration and reusable Swift packages.
- External SDKs remain acceptable for business infrastructure such as ads/analytics when justified.
