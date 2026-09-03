# Falora iOS — Apple Guideline 4.3(b) Araştırma Kaynağı

Audience: Falora ürün sahibi ve geliştirici  
Date: 2026-09-02  
Scope: Apple App Store iOS submission; Turkish market first, global policy  
Assumptions: Fal features remain; Android is out of scope; no review-only deception; current submission was rejected under 4.3(b).

## Direct answer

No UI-only change can guarantee passing 4.3(b). Apple explicitly names fortune-telling as saturated and requires a meaningfully different or improved experience. Falora must change its testable core loop, not merely labels. Recommended thesis: a user-created ritual artifact and longitudinal reflection journal, with optional human interpretation, rather than a catalog of one-shot fortune reports.

## Evidence synthesis

- Apple 4.3(b): saturated categories including fortune telling require meaningfully different/improved experience.
- Apple 4.2: app must provide lasting utility/entertainment and not be a catalog.
- Apple before-submit guidance: full review access, live backend, detailed review notes for non-obvious features and IAP.
- Apple HIG onboarding: teach through interactivity; interface should make possible actions discoverable.
- Current App Store competitors already advertise live advisors, interactive tarot, astrology, compatibility and saved conversations. Therefore those features alone are weak differentiation.
- Falora code already stores selected tarot/playing cards, bean scatter and water scatter data, history, human-reader requests, named readers, status and quota. This lowers implementation cost for a ritual artifact/journal architecture.

## Recommended product thesis

Falora is a participatory Turkish ritual journal. The user creates a ritual artifact (scatter, symbols, cards, photos), records their own interpretation before seeing an external reading, optionally sends the same artifact to a named human reader, then returns later to reflect. The journal surfaces recurring user-created symbols/topics over time. Fortune reports become one output, not the product core.

## Material limitations

- Apple provides no pre-clearance or acceptance guarantee.
- Developer Forum reports are anecdotal and show inconsistent outcomes; they do not establish a reliable workaround.
- Existing live-advisor apps may be grandfathered or evaluated under different histories, so their presence does not imply a new submission will pass.

## Claim-to-source ledger

1. App Review Guidelines, Apple, updated/crawled 2026, https://developer.apple.com/app-store/review/guidelines/ — 4.3(b), 4.2, 1.2, 3.1.1, review preparation.
2. Onboarding HIG, Apple, updated 2024, https://developer.apple.com/design/human-interface-guidelines/onboarding — interactive teaching and optional onboarding.
3. Discoverable Design, Apple WWDC21, https://developer.apple.com/videos/play/wwdc2021/10126/ — actions should be understandable before interaction.
4. Upload app previews/screenshots, Apple App Store Connect Help, accessed 2026-09-02, https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/ — 1–10 screenshots and up to three previews.
5. App preview specifications, Apple, accessed 2026-09-02, https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications — 15–30 second previews.
6. Submission overview, Apple, accessed 2026-09-02, https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review — review context and platform submissions.
7. Unresolved issues workflow, Apple, accessed 2026-09-02, https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues — edit/resubmit procedure.
8. Keen App Store listing, Ingenio, accessed 2026-09-02, https://apps.apple.com/us/app/keen-psychic-reading-tarot/id1008861332 — live advisors, matching, messages, history-like services.
9. MyStar App Store listing, Liftalk, accessed 2026-09-02, https://apps.apple.com/us/app/mystar-live-psychic-tarot/id6738414334 — interactive tarot, live advisors, horoscope and compatibility.
10. Falavanga App Store listing, Deploy, accessed 2026-09-02, https://apps.apple.com/tr/app/falavanga-tarot-ve-kahve-fal%C4%B1/id1052259067 — Turkish coffee, tarot, horoscope and 3D tarot.
11. Apple Developer Forum 4.3(b) reports, anecdotal only, accessed 2026-09-02, https://developer.apple.com/forums/thread/112848 and https://developer.apple.com/forums/thread/840388 — uncertainty and discoverability of core functionality.

## Search stopping rationale

Official threshold, adjacent rules, submission mechanics, competitor feature overlap and Falora implementation evidence are covered. Further forum variants repeat the same unverified experiences and are unlikely to alter the recommended product thesis.

## 2026-09-02 lowest-risk follow-up

New disconfirming evidence: journaling, moods, recurring-card patterns, AI interpretation, later reflection, physical-deck logging and privacy-first local storage are already offered by several current tarot apps. Therefore a journal-centered product is not sufficient on its own to reach the lowest practical 4.3(b) risk.

Revised recommendation while retaining fortune features: build an authored, persistent interactive narrative/game around the original Tombik Teyze character. Bean scatter, tarot selection, coffee images and water symbols become mechanics that produce clues and branch a story; the journal becomes the player's almanac. AI personalizes bounded dialogue rather than serving as the entire product. Human readers remain an optional secondary service. This materially changes the core loop from one-shot fortune output.

Additional sources:

- Apple App Review Guidelines, last updated 2026-06-08: https://developer.apple.com/app-store/review/guidelines/
- Apple Journaling Suggestions documentation: https://developer.apple.com/documentation/journalingsuggestions
- Tarot Journal App Store listing: https://apps.apple.com/us/app/tarot-journal/id1271120458
- Tarot and Runes App Store listing: https://apps.apple.com/us/app/tarot-and-runes-daily-reading/id1267312220
- TARO App Store listing: https://apps.apple.com/us/app/taro-learn-tarot-card-meaning/id6479176416
- Specula App Store listing: https://apps.apple.com/us/app/specula-tarot-journal/id6779938915
- ACTS interactive story App Store listing: https://apps.apple.com/us/app/acts-interactive-story-game/id6758665820

Limit: interactive fiction is itself an established category. The defensible distinction must come from the combination of original authored Tombik Teyze IP, persistent branching state, multiple bespoke physical/digital fortune mechanics, replayable outcomes and a complete native experience—not merely renaming fortune screens as chapters.
