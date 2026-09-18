# Analytics and Experiments

## Purpose
Analytics is the nervous system of Game Time. It should answer whether players understand, enjoy, return, monetize, and where they fail.

## Common event vocabulary
At minimum:
- install / first_open
- session_start / session_end
- tutorial_started / tutorial_step / tutorial_completed
- level_started / level_failed / level_completed / level_abandoned
- hint_used / undo_used / booster_used
- reward_offer_shown / accepted / declined / completed
- coins_earned / coins_spent
- iap_viewed / started / completed / restored
- daily_started / daily_completed
- crash / nonfatal diagnostic references

## Funnel
Track:
acquisition → first open → tutorial complete → early level milestones → D1 → D7 → D30 → ad revenue → IAP revenue.

## Level analytics
Track by game/level/version:
- completion rate
- attempts
- solve time
- abandon rate
- hint usage
- restart rate
- monetization interaction

## Acquisition
Join App Store acquisition/campaign data with game telemetry at cohort level where privacy rules permit. Optimize for retained/revenue-producing users, not installs alone.

## Experiments
Remote experiments may later test:
- tutorial timing
- reward amounts
- level order
- offer presentation
- difficulty variants
- store presentation

Do not build a sophisticated experimentation platform before Game #001 ships. Keep event schemas stable and versioned so experimentation can be added later.
