# ADR 0007 — Extract Reuse After Evidence

## Status
Accepted

## Decision
Do not prebuild a universal game engine or every mechanic module. Implement specific games first and extract shared mechanics only after real duplication appears across shipped titles.

## Consequences
- Lower risk of speculative abstractions.
- Game #001 stays fast.
- Game #002 is the first serious test of GameTimeKit reuse.
