# Implementation and release handoff

## Boundaries of this delivery

The brief describes a multi-jurisdiction regulated-information platform. This implementation provides a native local workspace and a deliberately narrow source-backed backend path. It does not claim the full brief is complete. GitHub Actions now builds the app and executes its four XCTest tests successfully with Xcode 16.4. The live service, authority datasets, purchase configuration and physical Apple device execution remain outstanding.

### Implemented but not device-validated

SwiftUI navigation and forms; SwiftData persistence; local PDF/image OCR and camera scan; source-backed answer rendering; on-device voice capture; speech synthesis; MapKit search; local notification scheduling; device authentication; Keychain; export/deletion; StoreKit adapter. Xcode now typechecks the Apple APIs and SwiftData macros. Unit tests exercise persistence, templates, action extraction and intent classification; they do not establish end-to-end device behavior.

### Explicitly incomplete

- Simulator screenshots, accessibility audit and physical-device test pass. The simulator build and four unit tests are complete.
- Verified geospatial jurisdiction resolution and local/planning/licensing authority routing. A user-entered council is not treated as verified.
- Regulatory domains beyond the England pavement-seating pilot, including conflicting-source reconciliation and fee verification.
- AI retrieval/extraction/plain-language generation. The implemented explanation is deterministic and editorially curated. No LLM provider is configured and no model is allowed to supply requirements from memory.
- Document AI interpretation, semantic follow-up questions, reference/authority extraction and automatic date extraction. The current implementation quotes candidate action lines and asks the user to enter and verify dates.
- Permit/document attachment relationships; documents are currently associated with the business.
- On-site conversational sessions and voice commands that perform local actions. VoiceIntentRouter is tested scaffolding and is not wired to automatic actions.
- Business-specific Rule Watch subscriptions, scheduling, material-change classification, affected-checklist mapping and remote notifications. Backend snapshots and review quarantine exist; the Rule Watch UI states that monitoring is inactive.
- Optional authorised GPS capture. Address search uses deliberately entered text only.
- App Intents and Siri shortcuts.
- Cloud accounts, encrypted cloud storage, deletion APIs, backups, sync and per-user API authentication. The app stores records locally and the pilot backend stores only public source material.
- Subscription limits, purchase benefits, prices, App Store server verification, App Store creative assets and purchase testing. StoreKit product IDs are intentionally empty because the source brief cuts off before the product definitions.
- Launch artwork, App Store metadata, legal/privacy review, retention policy and final privacy manifest audit. An app icon is included. The generated onboarding photo is a synthetic illustration of the product scenario, not a customer endorsement.

## Architecture

```
SwiftUI features -> SwiftData local records
      |
      +-> Speech / AVFoundation (on-device transcript -> explicit submit)
      +-> Vision / PDFKit (local OCR -> original text inspection)
      +-> UserNotifications (user-confirmed dates)
      +-> MapKit (user-entered address search)
      |
      +-> HTTPS RegulatoryAnswerService
            -> explicit context checks
            -> supported-topic gate
            -> allowlisted source snapshot
            -> exact reviewed hash + freshness + excerpt validation
            -> curated explanation + evidence + limitations
```

For expanded coverage, source records should belong to verified authority IDs and precise geographic scope. Each extracted claim should carry source/version/page/section/quote and applicability predicates. A rules layer should reject missing context, contradictory evidence, stale sources and unsupported domains before any explanation model runs. Untrusted page text must never become executable tool instructions. A future LLM output must reference only admitted claim IDs, and should be rejected on citation mismatch. Do not silently replace the deterministic path with unrestricted chat.

The pilot's exact allowlist and redirect rejection constrain retrieval. The development HTTP server must remain loopback-only. Before production: deploy behind TLS and a supported application server; add per-user identity, quota/rate limits, timeout/body-size enforcement, abuse controls, secret rotation and non-sensitive observability. Do not distribute one shared pilot token to production users.

## Data and privacy

Business records and documents use the app sandbox and operating system device protection. App lock is an additional UI gate, not independent file encryption. Keychain stores the API token with `WhenUnlockedThisDeviceOnly`. No analytics or advertising integration is included. No promise is made that exports or device backups are encrypted by this app.

Export includes original document bytes encoded as Base64 and all stored business, permit, answer and checklist fields. Large archives are currently assembled in memory; use streaming export before supporting large document libraries. History deletion is local. Business deletion explicitly deletes dependent records and scheduled reminders. Deletion cannot retract copies the user exported. Review the privacy manifest and App Store labels against the deployed backend's actual data practices before release.

## Device acceptance checks

1. Generate and build the Xcode project; execute XCTest on a simulator. Resolve any platform typechecking or macro failures before treating the app as runnable.
2. Complete onboarding at standard and accessibility text sizes on small iPhone and iPad, including landscape. Confirm VoiceOver action names and native navigation.
3. Add two businesses. Confirm checklist, documents, answers and permits remain isolated after relaunch and switching.
4. Deny microphone/speech permissions. Confirm typing remains available. Test unavailable on-device speech language; ensure no cloud fallback occurs. Stop and dismiss recording; microphone must stop.
5. Try no service, no consent, failed token, no coverage, stale evidence, refreshed changed evidence and supported reviewed evidence. Confirm sources and limitations are visible, never replaced with fabricated responses.
6. Save an answer, disable networking, and open the saved answer with its historic checked time. Verify no fresh-answer claim appears.
7. Import native-text PDF, scanned PDF, rotated photo, empty document, locked PDF, oversized file and 50-page boundary cases. Compare page numbers and original wording.
8. Add a confirmed permit reminder, deny notification permission, edit its date, delete its business and verify pending reminders are removed.
9. Enable authentication, background and return, cancel unlock, and use passcode fallback. Inspect app-switcher privacy on hardware.
10. Export, inspect all data types, delete individual records, then delete all local data and relaunch. Verify notification removal and token deletion.
11. Configure StoreKit test products only after benefits/pricing are defined. Test verified purchase, pending, cancellation, revoked entitlement and restore. No production purchase UI should launch with undefined benefits.

## Validation record

Windows host: Python tests and Swift frontend parsing passed; a live GOV.UK source was fetched and hashed. GitHub Actions run [34739972509](https://github.com/lanray07/CivicRule-AI/actions/runs/34739972509) built commit `9ee3dd8` using Xcode 16.4 and passed 4 XCTest tests on an iPhone 16 Pro / iOS 18.5 simulator, plus all 13 backend tests. Simulator app and test-result artifacts were uploaded. No UI screenshot inspection, physical-device validation, signed IPA or TestFlight upload is claimed.
