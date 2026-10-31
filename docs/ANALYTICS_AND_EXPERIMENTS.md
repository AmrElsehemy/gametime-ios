# Analytics and Experiments

## Purpose
Analytics is the nervous system of Game Time. It should answer whether players understand, enjoy, return, monetize, and where they fail.

## Destination: PostHog (one project, every game)
All games send to a single PostHog Cloud EU project; the free plan allows one project and 1M events a month across it. Every event carries `game` (such as `top-off`), so dashboards filter or compare by game.

`GameTimeAnalytics` provides the whole path:

- `AnalyticsPipeline` stamps the common fields (`game`, `schema`, `app_version`, `build`, `install_id`, `session_id`, `seq`, `ts`, `platform`, `idiom`, `os_major`, `lang`), emits `first_open`, `session_start` and `session_end`, keeps a local log, and forwards to clients only while sharing is on.
- `PostHogAnalyticsClient` batches events to `https://eu.i.posthog.com/batch/` over plain HTTPS, with a bounded file-backed queue, exponential backoff and a stable `uuid` per event so retries are deduplicated.

Privacy defaults, enforced in code:

- `distinct_id` is a random install id: no IDFA, no device or account identifier, so no App Tracking Transparency prompt.
- `$process_person_profile: false`: no person profiles; events stay anonymous.
- `$geoip_disable: true`: no location derived from the IP address. Also turn on **Discard client IP data** in the PostHog project settings.
- Games keep a fixed allow-list of property keys and test that nothing outside it is emitted.

Setup per game: put the project API key in the app's Info.plist as `PostHogAPIKey` (it is a write-only ingestion key). A build without the key attaches no client and sends nothing. Sending data changes the App Store privacy answers from "Data Not Collected" to Usage Data / Product Interaction, used for Analytics, not linked to the user and not used for tracking; update the game's `PrivacyInfo.xcprivacy`, its App Store Connect privacy answers and its privacy page together.

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
