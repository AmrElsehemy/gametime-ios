# Quality and Testing

## Principle
Every shipped title inherits a repeatable quality baseline. Game-specific rules remain testable without rendering.

## Required categories
- unit tests for core game rules
- deterministic state transition tests
- persistence and migration tests
- solver / level-validity tests where applicable
- tutorial progression tests
- StoreKit and ad-provider mocks
- replay regression fixtures
- performance checks
- snapshot/UI checks where valuable

## Level content quality
For generated or highly structured puzzle content:
1. generate or author level
2. validate schema
3. solve/verify solvability
4. estimate difficulty if possible
5. reject invalid or degenerate levels
6. include in curated pack

## Performance
Use device-relevant budgets and test:
- frame pacing
- memory
- asset loading
- startup time
- mass-entity counts where relevant
- physics-heavy scenes where relevant

## CI gate direction
Before release candidate:
- tests pass
- level validation passes
- no known critical issue
- app launches offline
- ads/IAP failure gracefully
- privacy/support surfaces present

Do not block Day 1 on building perfect automation. Add gates as the pipeline matures.
