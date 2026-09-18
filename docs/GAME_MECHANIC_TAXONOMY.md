# Game Mechanic Taxonomy

This taxonomy captures the mechanic families validated during reference analysis. It is a design map, not a mandate to implement every engine immediately.

## Board / grid
- cells, slots, occupancy
- gravity, spawn, removal
- regions and layered cells
- territory / ownership
- multi-cell entities

## Match / cascade
- horizontal/vertical matching
- special pieces
- blockers and layered damage
- cascades and refill
- collection objectives

## Realtime grid
- tick-based loop
- falling entities
- rotation
- deterministic collision
- lock delay
- line/row clearing

## Stack / container
- capacity
- push/pop/peek
- top-run detection
- transfer
- split/combine
- solved-container detection

## Routing / occupancy
- axis-constrained movement
- slot/block occupancy
- parking / queue logic
- exits and target matching
- corridor/blocker rules

## Path / trace
- drag-to-grid input
- adjacency
- path occupancy
- ordered waypoints
- full-board coverage
- backtracking

## Sequence
- path-to-token decoding
- words / numbers / symbols
- target validation
- persistent solved paths

## Constraint puzzles
- row/column/region uniqueness
- adjacency exclusion
- count constraints
- required/forbidden placement
- hints/solver/generator potential

## Packing / tiling
- fit and non-overlap
- exact-cover style validation
- region packing
- shape occupancy

## Physics / merge
- gravity bodies
- circular/shape collision
- merge-on-contact
- settling
- fail zones
- value progression

## Projectile / territory
- emitter/projectiles
- reflection/bounce
- area-of-effect
- tile painting/conversion
- deployables
- percentage goals

## Mass entity / swarm
- pooled entities
- spawn/despawn
- seek/avoid/flow
- target assignment
- batch update
- multiplier gates

## Shared semantic actions
Where stable across games, motion and feedback should expose intent such as:
- swap
- drop
- pour
- merge
- collect
- exit
- explode
- blocked-bounce
- celebrate

## Extraction rule
A mechanic becomes a reusable module only after at least two games prove the abstraction is useful and stable.
