# Release Operations

## Goal
Make release work repeatable enough that the owner mainly reviews outcomes and makes go/no-go decisions.

## Release pipeline direction
Tag/release candidate → build → automated tests → level validation → replay regression → performance checks → archive/sign → TestFlight → smoke test → screenshots/metadata → App Store submission.

## Required release surfaces
- version/build number
- release notes
- privacy metadata
- support URL
- App Store screenshots/preview
- Game Center metadata where used
- StoreKit products/entitlements where used
- ad configuration
- crash monitoring

## Approval gates
Keep explicit human approval for:
- first public release of a new title
- pricing/IAP changes
- material privacy changes
- major gameplay/economy changes
- large paid-media spend increases
- sunsetting a game

## Hotfix strategy
Prefer remote mitigation first when safe:
- disable broken level
- disable ad placement/provider
- disable store offer
- disable event/config

Then ship tested binary/data fix.

## Definition of shipped
Submission to Apple is the milestone controlled by us. Review duration is external.
