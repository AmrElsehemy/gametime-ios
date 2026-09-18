# ADR 0002 — Separate Game Logic from Rendering

## Status
Accepted

## Decision
Game rules/state must not depend on SpriteKit/UIKit. Renderers observe/apply state and animation plans; they do not own game rules.

## Consequences
- Logic is unit-testable without rendering.
- Replay/solver/validation become simpler.
- Presentation can evolve without rewriting rules.
