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
