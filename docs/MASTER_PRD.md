# Game Time — Master PRD

## 1. Vision

Game Time is the internal product platform behind **Knowlly Games**: a native-iOS micro-game studio designed to repeatedly create, release, operate, monetize, and grow highly polished, easy-to-learn games.

The objective is not to build one large game. The objective is to create a compounding factory where each shipped title makes the next title faster and better.

Public studio identity: **Knowlly Games**  
Internal platform codename: **Game Time**  
Primary web presence: **knowlly.games**

## 2. Product thesis

Each game should:

- Be understandable through interaction rather than manuals.
- Reach first meaningful interaction in roughly 3 seconds.
- Deliver a satisfying response in the first few seconds.
- Give the player an early win quickly.
- Support short sessions and instant replay.
- Build mastery through progressive disclosure and well-paced novelty.
- Monetize optional value, not artificial frustration.
- Operate offline for core gameplay.
- Ship with telemetry, diagnostics, support and a growth path.

## 3. Native technology strategy

Apple-native by default:

- Swift
- SpriteKit
- UIKit / Core Animation where appropriate
- Core Haptics
- AVFoundation
- GameKit
- StoreKit 2
- GameplayKit selectively
- Metal selectively for performance-heavy rendering

No Unity/Godot or third-party gameplay/rendering dependency by default.

External SDKs are permitted where they solve business infrastructure problems such as advertising, analytics, attribution or crash reporting. Gameplay ownership remains ours.

## 4. Platform shape

Game Time consists of three systems:

### Runtime
Reusable native components used by games:

- state and game loop
- experience/juice
- onboarding
- audio/haptics
- progression
- identity/Game Center
- commerce/rewards
- persistence
- replay
- diagnostics
- testing support

### Factory
Tooling to build and ship games faster:

- game templates / generation
- level definitions
- validators and solvers
- deterministic replay
- screenshot/video capture
- CI/CD
- App Store asset generation
- marketing creative generation

### Control
The operating system for live products:

- remote configuration
- kill switches
- analytics
- LiveOps
- support
- economy configuration
- experiments
- growth reporting

## 5. Initial reusable module boundary

Do not prematurely build every mechanic engine.

GameTimeKit v0.1 starts with:

- `GameTimeCore`
- `GameTimeExperience`
- `GameTimeServices`
- `GameTimeCommerce`
- `GameTimeTesting`

Game-specific mechanics remain inside the first game until a second title proves real reuse. Only then are mechanic-specific modules extracted.

## 6. Gameplay families validated by reference research

The architecture has been tested conceptually against:

- constraint-placement puzzles
- path-cover puzzles
- word/sequence tracing
- packing / region logic
- falling-block realtime games
- container/water/ball sorting
- sliding / exit-routing puzzles
- physics merge / 2048 / Suika-like games
- match-3 / cascade systems
- parking / queue / occupancy games
- projectile / territory systems
- swarm / mass-agent systems
- mob multiplier / gate systems

The goal is not a universal engine. It is a shared platform plus reusable mechanic families extracted as evidence appears.

## 7. Learning and onboarding

The first levels are the tutorial.

Principles:

- no instruction wall before play
- first interaction in seconds
- show, then let the player do
- level 1 should be extremely difficult to misunderstand
- introduce one concept at a time
- increase assistance only when hesitation or repeated invalid input is detected
- skilled players should not be slowed down by tutorials
- first booster use should usually be free so the player learns its value
- no monetization during the initial teaching experience

Every game PRD must define:

- first interaction
- first 10 seconds
- first win
- first 60 seconds
- levels 1–5
- first new mechanic
- first booster exposure
- first monetization exposure

## 8. Engagement model

Design five nested loops:

1. Second-to-second: input → motion → sound → haptic → visual reward.
2. Round: challenge → tension → solve → celebration → restart/next.
3. Session: levels → mastery → novelty → milestone.
4. Daily: challenge → streak → reward → return.
5. Long-term: progression → collections → events → seasons where justified.

Difficulty should alternate between learning, practice, challenge and relief. Do not create a monotonic frustration curve.

## 9. Monetization

Primary model: **rewarded value**.

Examples:

- optional double reward
- free hint
- continue / extra moves
- bonus coins
- temporary booster

Rules:

- ignoring every ad must still leave a complete game
- no ad during tutorial teaching flow
- no interstitial during gameplay
- interstitials, if used, are centrally frequency-capped
- never deliberately manufacture failure to sell relief

Optional layers by game maturity:

- coins / wallet
- boosters
- Remove Ads IAP
- bundles
- cosmetics
- events
- premium/season pass only after retention proves demand

## 10. Identity

No proprietary username/password account in v1.

Use:

- local player profile
- Game Center where useful for leaderboards, achievements and player identity
- cloud save only where justified

The game must remain playable when Game Center is unavailable.

## 11. Replay

Deterministic games should record enough information to reproduce sessions:

- game version
- level version
- seed
- initial state where needed
- player input events

Replay supports:

- bug reproduction
- regression testing
- balancing analysis
- suspicious leaderboard investigation
- marketing capture

## 12. Backend / control plane

Core gameplay never depends on the backend.

The backend exists for enhancement and operations:

- remote config
- kill switches
- level/config distribution
- support intake
- LiveOps later
- App Store/server notifications later

Every remote feature must have bundled defaults and graceful failure.

## 13. Web

One umbrella web presence, not one domain per game.

`knowlly.games` should provide:

- studio portfolio
- individual game landing pages
- App Store links
- privacy
- terms
- support
- press/marketing assets

Dedicated game domains are exceptions for breakout titles.

## 14. Social and growth

Initial social identity is studio-wide, not one account per game.

Priority channels:

- TikTok
- Instagram Reels
- YouTube Shorts

Organic creative testing should feed paid acquisition. Gameplay replays and marketing events should eventually feed automated Remotion-based creative generation.

Paid acquisition scales only when retention/revenue evidence supports it.

## 15. Quality and support

Every public title must have:

- automated rule tests
- persistence/migration testing
- level validation where applicable
- performance checks
- crash/non-fatal diagnostics
- ad and IAP diagnostics
- Report a Problem flow
- restore purchases
- privacy/support links

For deterministic games, support should ideally be able to replay reported sessions.

## 16. Privacy / accessibility

Privacy is a platform concern, not per-game reinvention.

Design for:

- minimal data collection
- ATT only when required by chosen tracking behavior
- third-party SDK privacy manifests
- reset/delete local data support
- color-independent state cues where feasible
- Reduce Motion
- sound/haptic controls
- large touch targets

## 17. Portfolio lifecycle

Each title moves through:

- Experiment
- Grow
- Maintain
- Sunset

Not every game deserves endless iteration. Low-cost shipping enables disciplined killing of weak titles and scaling of strong ones.

## 18. Definition of done

Game Time v1 is **not** complete when the framework compiles.

It exists when Knowlly Games has public App Store titles with real users, telemetry, monetization, support and a repeatable pipeline:

**idea → build → TestFlight → App Store → acquire → observe → improve → scale/stop**
