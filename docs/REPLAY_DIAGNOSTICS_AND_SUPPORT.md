# Replay, Diagnostics and Support

## Replay as a foundation
For deterministic games, record enough information to reconstruct a session without recording video:
- game version
- level/version
- RNG seed
- initial state when needed
- player intent/input events

## Uses
- bug reproduction
- regression testing
- level balancing
- suspicious leaderboard investigation
- support
- deterministic marketing capture

## Diagnostics
Collect safe technical context such as:
- app/game version
- iOS version
- device class
- current level/version
- replay/session identifier
- recent non-fatal errors
- ad/IAP failures
- performance/FPS/hang indicators

## Support UX
Every public game should expose:
- Help / Support
- Report a Problem
- Restore Purchases
- Privacy
- contact/support URL

A problem report should attach diagnostics only with appropriate user action and avoid unrelated personal data.

## Desired future flow
Player report → support record → replay/state reproduction → GitHub issue → fix → regression test → hotfix/release.

## Kill-switch integration
If an issue is severe and remotely controllable, operations should be able to disable:
- a broken level
- an ad placement/provider
- a store offer
- an event/config
without making the game unusable offline.
