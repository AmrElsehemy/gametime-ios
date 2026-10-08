# Monetization and Commerce

## Philosophy
Monetize engagement, not manufactured frustration.

A player who never watches an ad or buys anything must still have a complete, enjoyable game.

## Primary model
Rewarded ads are the default ad format where they make sense.

Useful reward offers include:
- double rewards
- free hint
- continue / extra moves
- bonus coins
- temporary booster
- optional rescue from failure

## Interstitials
If used at all:
- never during active gameplay
- never immediately after install/open
- never after every level
- centrally frequency-capped
- disabled during initial onboarding

## Commerce capabilities
Optional by game:
- wallet / coins
- gems or secondary currency only when justified
- boosters/consumables
- cosmetics
- Remove Ads IAP
- bundles
- timed unlimited-play bonuses
- premium/season pass only after retention proves demand

## Premium pass
Infrastructure may exist early, but the product should not ship a pass before a meaningful cohort demonstrates repeated multi-day engagement.

Preferred pass model:
- free progression track
- premium second reward track
- premium accelerates/rewards rather than blocking progress

## Economy rules
Every currency must have explicit sources and sinks.

Track and simulate:
- average earned/day
- average spent/day
- inventory accumulation
- booster usage
- rewarded-ad substitution
- IAP conversion
- pass reward inflation

## Platform abstractions
`GameTimeCommerce` should own:
- ad provider protocol
- reward offer semantics
- StoreKit product/entitlement adapter
- wallet/inventory contracts when used
- idempotent reward grants
- centrally enforced monetization policy

## Integrity
Paid entitlements and reward grants must be idempotent. Server-side verification / App Store server notifications / App Attest are future hardening steps when economic abuse becomes material.

## AdMob adapter (`GameTimeAdMob`)

Concrete Google Mobile Ads implementation of `AdProviding`, plus the Google UMP consent flow. It is iOS-only; on macOS the module is empty so `swift test` still runs there.

A consuming game needs:

1. `GameTimeAdMob` added to the app target.
2. `GADApplicationIdentifier` in the app's Info.plist. Use `AdMobConfiguration.sampleApplicationID` until the real AdMob app exists.
3. An `AdMobConfiguration` with a production rewarded unit id per placement. `AdMobConfiguration.testing` uses Google's sample units and must never ship in a release build.
4. This order at launch: `AdConsent().gatherConsent()`, then `AdMobRewardedProvider.start()` once consent allows ads, then pass the provider to `MonetizationCoordinator` and feed `AdConsent.canRequestAds` into `MonetizationContext.canRequestAds`.
5. A way to reopen the consent form from settings when `AdConsent.privacyOptionsRequired` is true.

Behaviour that matters for the rules in this document: one ad is preloaded per placement so `isAvailable` is instant and honest; a failed or missing ad reports `unavailable` and never blocks play; closing an ad without earning the reward is `cancelled`, so only an earned reward becomes `completed`.

