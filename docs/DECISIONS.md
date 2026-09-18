# Frozen Decisions

This file records product/architecture decisions already made so future development does not repeatedly reopen settled questions without new evidence.

## Brand and portfolio
- Public studio identity: **Knowlly Games**.
- Internal platform codename: **Game Time**.
- Primary public domain: **knowlly.games**.
- One umbrella web presence; dedicated domains only for exceptional breakout titles.
- One studio social identity initially; individual game accounts are exceptions.

## Repositories
- `gametime-ios`: reusable native runtime + canonical product/architecture docs.
- `gametime-backend`: tiny optional control plane, not gameplay server.
- `gametime-web`: public marketing/support/legal website.
- Individual games get separate repos when created.

## Native stack
- Swift first.
- SpriteKit for most game rendering/interaction.
- UIKit/Core Animation for conventional shell/UI where cleaner.
- Core Haptics for tactile feedback.
- AVFoundation for sound/music.
- GameKit for Game Center capabilities.
- StoreKit 2 for IAP/entitlements.
- GameplayKit selectively.
- Metal only when justified by performance/visual needs.
- No Unity/Godot or third-party gameplay/rendering dependency by default.

## Architecture
- Game logic is framework-independent; renderers display state rather than owning rules.
- Core gameplay is offline-first.
- Build minimal shared modules first; extract mechanic engines only after proven reuse.
- Replay is foundational for deterministic titles.
- Backend-controlled features require bundled defaults, validation, caching and graceful failure.

## Identity
- No proprietary username/password account in v1.
- Local-first player state.
- Game Center used where useful for gaming identity, leaderboards and achievements.

## Onboarding
- First levels are the tutorial.
- First interaction in seconds.
- Adaptive assistance increases only when needed.
- No monetization during initial teaching flow.

## Monetization
- Rewarded ads are primary where ads make sense.
- Free experience remains complete.
- Interstitials are conservative and centrally frequency-capped.
- Commerce/store only where a game has an economy that supports it.
- Premium/season pass only after retention proves demand.
- Never manufacture frustration to monetize relief.

## Operations
- Analytics, diagnostics, support, privacy, release engineering and growth are part of the product.
- Public App Store release is the definition of done.
- Game #002 does not become the main focus before Game #001 is submitted.
- Use remote kill switches for severe controllable issues.

## Growth
- Organic short-form creative is the first creative testing loop.
- Winning organic formats may become paid creative.
- Paid acquisition is evaluated on retained/revenue-producing cohorts, not installs alone.
- Marketing capture/Remotion/social scheduling are future automation targets.

## Roadmap
- Day 1: foundation.
- Day 2: playable Game #001.
- Day 3: feels like a game.
- Day 5: internal TestFlight product.
- Day 10: submitted to Apple.
- Day 20: first real learning loop + Game #002 proving reuse.
- Day 30: 2–3 public games target and visible studio.
- Day 50: functioning factory with ~4 public games target.

## Scope discipline
Every task should answer at least one:
1. Does this directly help ship Game #001?
2. Does this materially make Game #002 faster?

If neither, backlog it unless it mitigates a material legal/security/release risk.
