# Game #002 — Top Off

**Status:** Active  
**Public name:** Top Off  
**Mechanic family:** stack / container  
**Game repository:** `AmrElsehemy/gametime-topoff-ios`

The canonical product requirements live in the game repository at `docs/PRD.md`.

## Frozen direction

Top Off supersedes the earlier path-engine concept as Game #002. Path / trace remains a candidate mechanic family for a future game.

The immediate product gate is not large-scale level generation. It is a tactile five-level iPhone prototype:

- tap a container to select/lift it
- tap a legal destination to pour
- invalid moves produce immediate feedback
- pours feel physical and satisfying
- solved levels celebrate and advance with minimal friction
- the first five handcrafted levels teach through play

Only after this gate is met should the seeded generator/solver become the main focus.

## Platform proof

Game #002 must fill the reuse table in its canonical PRD with actual outcomes: reused as-is, reused with change, rebuilt, or not needed, plus approximate effort. This is the first measured proof that GameTimeKit makes subsequent games faster to ship.
