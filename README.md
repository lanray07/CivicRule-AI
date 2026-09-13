# CivicRule AI

**Know what the rules say before you act.**

Native iPhone/iPad implementation targeting iOS 17+, accompanied by a Python source-verification pilot. Forest green, warm neutral surfaces, serif editorial headings, accessible native forms and an original generated onboarding photograph.

This repository is an initial implementation, **not an App Store-ready or production-validated release**. No iOS binary has been built on this Windows machine. The user brief ends during section 39; subscription pricing and premium entitlements are intentionally unspecified.

## Run on a Mac

Install Xcode 16 or later and XcodeGen, then from this directory:

```sh
brew install xcodegen
xcodegen generate
open CivicRule.xcodeproj
```

Select the CivicRule scheme and an iPhone or iPad simulator. The app works without a backend for business records, checklists, permits, documents and local privacy controls. Speech, camera, authentication and notifications need device-level verification. Choose a signing team to run on a physical device.

```sh
xcodebuild -scheme CivicRule -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
# Substitute an installed simulator from `xcrun simctl list devices available`:
xcodebuild -scheme CivicRule -destination 'platform=iOS Simulator,name=iPhone 16' test
```

The CI workflow builds the app and tests for a simulator; the `build-for-testing` step does not execute XCTest. The commands above explain how to execute tests on a selected simulator.

## Implemented paths

| Area | Behavior |
| --- | --- |
| Onboarding and home | Six onboarding steps, generated shop-owner scene, adaptive action grid, business switcher, counts derived from saved records |
| Businesses | Multiple profiles, explicit nation and user-entered authority, activity and opening-hour context, investigation templates |
| Ask | Explicit cloud consent, HTTPS client, missing-service/error/loading states, structured answer, confidence, source metadata, save, checklist and shareable authority draft |
| Voice | Explicit tap-to-record, on-device-only speech recognition, transcript review, spoken answer and source titles, rate control |
| Checklists | Editable statuses and notes, source links, per-business isolation, deletion |
| Lease pre-check | Proposed address/hours/activities generate investigation prompts with retained premises context |
| Address | Apple Maps search and selected pin; clearly states authority boundaries are not verified |
| Documents | Import PDF/image/screenshots, camera scan, on-device OCR, full page text, original PDF/image, conservative action-line extraction |
| Reminders | User-confirmed document dates; permit reminders at 90/60/30/14/7/1 days; date edits invalidate old permit reminders |
| Permits | Reference, authority, status, application/issue/expiry/renewal dates, notes, editable records |
| Privacy | Device authentication, Keychain, consent revocation, per-record/business/history deletion, JSON export with original document bytes |
| Purchases | StoreKit product loading, verified entitlements, transaction updates, pending/cancelled purchases and restore service; no active products |
| Evidence backend | Exact source allowlist, HTTPS retrieval, no redirects, normalized text hashes, reviewed-version gate, 24-hour freshness, fail-closed responses |

## Connect the pilot backend

Python 3.10+; no third-party packages required.

```sh
python -m unittest discover -s backend -v
python backend/civicrule.py refresh
python backend/civicrule.py review
```

Review the retrieved source, its jurisdiction, current status, the small quoted passage, the summary and investigation prompts in `backend/civicrule.py`. Approve the **exact printed hash** only when that review supports the explanation:

```sh
python backend/civicrule.py approve --hash EXACT_REVIEWED_HASH
```

Set `CIVICRULE_API_TOKEN` to a randomly generated secret of at least 32 characters in your process environment. Do not commit it. Start the local service:

```sh
python backend/civicrule.py serve
```

It binds to `127.0.0.1:8787`. A production HTTP server, TLS reverse proxy, request limits, per-user authentication and operational controls are required before external deployment. The bundled Python HTTP server and shared pilot token are for local development only. No service has been deployed.

Add `CivicAPIBaseURL: https://YOUR_SERVICE_HOST` to `targets.CivicRule.info.properties` in `project.yml`, regenerate the project, then save the matching development token in the app’s Settings. Enable question sharing in the composer. The API does not receive the premises address or documents; it receives question, nation, user-provided authority, business type and activities.

`POST /v1/answers` accepts:

```json
{
  "question": "Can my café put tables outside?",
  "nation": "England",
  "authority": "User-confirmed local authority",
  "businessType": "Café",
  "activities": "Serving coffee"
}
```

The single pilot source is [GOV.UK pavement licences guidance](https://www.gov.uk/government/publications/pavement-licences-guidance/pavement-licences-guidance). It is **national guidance**, not local authority or property verification. No verified source database is committed; new installations start without an answerable corpus. Initial retrieval was exercised successfully, but source approval and scheduled operation are not automatically enabled.

## Evidence and refresh contract

Only exact editorially configured HTTPS URLs can be fetched. User URLs, arbitrary search results and redirects are rejected. The server never sends a question to an LLM. The pilot uses a reviewed explanation tied to the exact content hash of a source, with a supporting excerpt that must still exist in the source.

Schedule `python backend/civicrule.py refresh` every six hours in the deployed environment. This repository does not create a scheduler. A successful unchanged refresh updates the checked time. Meaningful extracted-text changes persist both versions and make the old approval unusable. Formatting/whitespace changes do not trigger a change. Failed refreshes block answers. Sources older than 24 hours, future timestamps and unapproved versions cannot support an answer. Text normalization is conservative and may still flag editorial changes for review.

## Remaining launch work

See [docs/DELIVERY.md](docs/DELIVERY.md) for limitations, architecture and device acceptance checks. In particular: broader reviewed official-source coverage, verified jurisdiction boundaries, LLM extraction/explanation with citation validation, conflict resolution, live business-specific Rule Watch, cloud accounts/storage, App Intents, subscription product decisions and end-to-end iOS verification remain unfinished. The UI explicitly labels unavailable capabilities.

No fees, current compliance verdicts, exact authority boundaries, official contacts or subscription prices are invented. Templates and lease checks are prompts to investigate, not sourced legal conclusions.

## Verification performed here

- 13 Python unit/integration tests pass.
- All Swift app and test files pass Swift frontend syntax parsing on Windows.
- Live official-source retrieval and content hashing completed successfully.
- Xcode compilation, XCTest execution, simulator rendering and physical-device tests were not available on this Windows host.

Apple API references consulted: [on-device speech recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [StoreKit current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements).

