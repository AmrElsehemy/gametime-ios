# ADR 0008 — Replay Is Foundational

## Status
Accepted

## Decision
Deterministic games should record compact replayable intent/state information from the beginning.

## Consequences
- Exact bug reproduction becomes possible.
- Replay fixtures support regression testing.
- Replays can power balancing analysis and future marketing capture.
- Replay data must remain compact, versioned and privacy-conscious.
