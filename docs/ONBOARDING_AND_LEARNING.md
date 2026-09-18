# Onboarding and Learning

## Goal
A new player should be interacting within seconds and understand the core loop within roughly one minute without reading a manual.

## Principles
- The first levels are the tutorial.
- Level 1 should be nearly impossible to misunderstand.
- Introduce one concept at a time.
- Prefer gesture demonstration, highlight, and contextual feedback over text.
- Good players should not be slowed down.
- Assistance increases only when the player hesitates or repeatedly makes invalid moves.
- The first booster use is usually free so its value is learned before monetization appears.
- Do not show monetization during initial mechanic teaching.

## Reusable tutorial primitives
- spotlight
- animated finger pointer
- tap/drag/swipe/hold gesture demo
- highlight/pulse
- tooltip
- input gating
- trigger conditions
- completion conditions
- hesitation detection
- adaptive hint escalation

## Adaptive assistance example
- 0–3s: no intervention
- ~3s: subtle pulse on valid object
- ~5s: stronger highlight
- ~8s: animated gesture demonstration
- repeated invalid actions: contextual hint

## Mandatory onboarding definition per game
Each game PRD must define:
- first interaction
- first 10 seconds
- first success
- first 60 seconds
- levels 1–5
- first new mechanic
- first free booster exposure
- first monetization exposure

## Tutorial analytics
Track at minimum:
- tutorial started/completed
- tutorial step shown
- assistance level reached
- time to first valid input
- invalid input count
- abandonment step
