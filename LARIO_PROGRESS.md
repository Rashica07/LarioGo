# LARIO GO — PROJECT STATE

> Single source of truth for autonomous development. **Verify claims against the repo before trusting them.**
> Last updated: 2026-08-15 · Phase 0 (Audit) complete

---

## 0. CRITICAL ENVIRONMENT CONSTRAINT — READ FIRST

**The development machine is Windows 11. There is no Swift toolchain on it.**

Verified absent: `swift`, `swiftc`, `xcodebuild`, `docker`, `psql`.
Verified present: `node v24.18.1`, `python 3.14.6`, `winget`, `choco`, `git`.

Consequences — these are facts, not opinions:

| Requirement | Status on this machine |
|---|---|
| Compile the iOS app | **Impossible.** SwiftUI/MapKit/UIKit/AVFoundation are Apple-platform-only and need macOS + Xcode. |
| Run iOS tests / simulator | **Impossible.** |
| Compile a Vapor backend | **Impossible.** Swift not installed; Vapor has no supported Windows target. |
| Run PostgreSQL | **Impossible.** No Docker, no local Postgres. |

**Therefore the Implement → Compile → Test → Fix loop cannot close locally.**
Swift written here is *unverified* until it is built on macOS or a macOS CI runner.
Any phase below marked "written, unverified" has NOT met the project's own Definition of Done (§48),
which requires "project compiles" and "affected tests pass".

**RESOLUTION ATTEMPTED: macOS CI — CURRENTLY BLOCKED.**
`.github/workflows/ci.yml` was written, pushed on 2026-08-15, and **could not run**.
GitHub reports, on https://github.com/Rashica07/LarioGo/actions:

> GitHub Actions workflows can't be executed on this repository.
> Your account's billing is currently locked. Please update your payment information.

Run #1 shows "Startup failure" with no job graph. This is **not** a workflow defect —
the file passes `actionlint` clean, contains no BOM, no CRLF, no tabs, and valid UTF-8.
No job ran, not even the free Ubuntu one, because the block is account-wide.

**Nothing in this repository has ever been compiled.** Every Swift deliverable is a
**draft pending first compile**.

**Unblocking requires a human (payment details — I will not handle those):**
1. Update payment information on GitHub → the existing workflow should then run as-is.
2. Make the repo public → Actions minutes are free for public repos, but this is
   commercial source; probably not acceptable.
3. Use another CI with a free macOS tier (Codemagic, Bitrise) — needs a new config.
4. Build on a Mac and report errors back.

### Attempt to get a local Swift compiler — FAILED (disk space)
Tried `winget install Swift.Toolchain` (6.3.3) on 2026-08-15. Visual Studio Build Tools 2026
and Windows SDK 10.0.26100 are present, so prerequisites were fine. Six of seven MSIs
installed; **`windows.msi` — the Swift Windows SDK, the one component needed to compile
anything — failed with 1603 / 0x80070643** and the bundle rolled back, removing Swift
entirely.

Root cause: **drive C: has only 5.1 GB free.** The toolchain needs roughly 5–8 GB.
D: (104 GB free) and E: (70 GB free) are both fixed drives.

Worth noting even if this is fixed: Swift-on-Windows would let us compile and test
**`LarioCore` only**. It cannot build the iOS app (SwiftUI/MapKit are Apple-only) or the
Vapor backend (no Windows support). Unblocking GitHub Actions remains the higher-leverage
fix because it covers all three.

### The Core package — logic designed to be testable off-Apple
`Core/` (`LarioCore`) is a Foundation-only Swift package holding the domain logic:
`Coordinate` + haversine distance, `Place` model, `PlaceQuery`/`PlaceSearch`
(filtering, relevance ranking, sorting), `Itinerary` (day grouping, reordering,
rescheduling, resolution) and `FavoritesStore`. ~1,900 lines including 100+ tests.
A CI guard rejects any `import SwiftUI/UIKit/MapKit/CoreLocation/AVFoundation/AppKit`
in that target, because the moment one appears it stops being testable off Apple.
**Still never compiled** — see above.

### What CAN be verified on Windows (and is, automatically)
`tools/check_project.py` validates project structure, scheme wiring, and asset references.
`tools/test_pick_simulator.py` self-tests the CI simulator selection. Both run in the
`project-integrity` CI job before the macOS runner is paid for, and both pass locally today.
This is not a substitute for compilation — it catches the corruption class that breaks a
build before Swift is even reached.

---

## 1. CURRENT PHASE

**Phase 0 — Audit: COMPLETE.** Build blockers fixed.
**Phase 1 — Backend foundation: WRITTEN, UNCOMPILED.** Vapor + Fluent + PostgreSQL + JWT
auth + health endpoint + 15 tests exist under `Backend/`. None of it has been built.
**Blocked on the CI billing issue in §0 before Phase 2.**

---

## 2. WHAT ACTUALLY EXISTS (verified by reading every file)

### Repo layout
Layout **after** the Phase 0 consolidation (Bug #1):
```
LarioGo.xcodeproj/            single project: LarioGo + LarioGoTests + LarioGoUITests
  xcshareddata/xcschemes/     shared LarioGo scheme (added; CI depends on it)
LarioGo/                      app sources, synchronized folder group
  LarioGoApp.swift            @main + SplashView
  Tab.swift                   ContentView + TabView (Explore/Map/Tickets/Profile)
  Models/                     Site.swift, TourEvent.swift, TicketPass.swift
  Services/                   TourismData.swift (static seed), ItineraryManager.swift
  Utilities/                  Theme.swift (design tokens)
  Views/                      8 views + 4 components
  Assets.xcassets/            AppIcon + 1 working photo + empty icon.imageset
LarioGoTests/                 seed-integrity tests
LarioGoUITests/               template stubs
tools/                        cross-platform project + CI checks (run on Windows)
.github/workflows/ci.yml      macOS build & test — the only place Swift compiles
```

### Frontend inventory — it is *better* than "3%" on UI, ~0% on product plumbing

| File | Lines | State |
|---|---|---|
| `Views/ARViewfinder.swift` | 311 | Built |
| `Views/SiteDetailView.swift` | 214 | Built |
| `Views/ExploreView.swift` | 185 | Built |
| `Views/ItineraryPlannerView.swift` | 165 | Built |
| `Views/ProfileView.swift` | 154 | Built, **all rows are dead** (no navigation except Itinerary) |
| `Views/MapTabView.swift` | 153 | Built |
| `Views/BookingSheet.swift` | 150 | Built |
| `Views/TicketsView.swift` | 144 | Built |
| `Views/Components/AudioGuidePlayer.swift` | — | Built (AVSpeechSynthesizer TTS) |
| `Views/Components/FeaturedCard.swift` | — | Built (FeaturedCard, SiteRowCard, EventCard, CategoryTag) |
| `Views/Components/SiteImage.swift` | — | Built, graceful asset fallback |
| `Views/Components/PressableScaleStyle.swift` | — | Built + `Haptics` facade |

**Genuinely good and worth preserving:** the `Theme` token system, `SiteImage`'s
placeholder fallback, `PressableScaleStyle` + haptics, the custom `MapPin`/`MapPreviewCard`,
and the card component set. The visual identity (Deep Azure / Clear Water Teal / Sand /
Coral) is coherent. **Do not redesign this.**

### What does NOT exist at all
- ❌ No backend. No Vapor, no Package.swift, no server directory, nothing.
- ❌ No database, no migrations, no PostgreSQL.
- ❌ No networking layer. No API client, no URLSession, no async/await calls anywhere.
- ❌ No service protocols (`AttractionService`, `RestaurantService`, … per spec §29). Zero.
- ❌ No authentication. No JWT, no Keychain, no login/register UI, no session.
- ❌ No Favorites feature (ProfileView hardcodes "Saved Places — 5").
- ❌ No Search tab and no search of any kind.
- ❌ No Restaurant model. No Event *detail* view. No Review model or UI.
- ❌ No Booking persistence (BookingSheet is UI-only).
- ❌ No ViewModels — every view reads `TourismData` statics directly. No MVVM yet.
- ❌ No real tests. Both test files are unmodified Xcode templates.
- ❌ No loading / error states anywhere (nothing is async, so nothing can fail yet).

### Navigation vs. spec
Spec §18 requires **Map · Search · Favorites · Profile**.
Actual tabs are **Explore · Map · Tickets · Profile**.
Explore is a good discovery home and should stay. **Search and Favorites are missing entirely.**

### Data model gap vs. spec §12
Spec wants Attraction / Restaurant / Event / Experience with address, region, images[],
reviewCount, openingHours, website, phone, tags, timestamps, price level, cuisine.
Actual `Site` has 12 flat fields, no region, no address, no tags, no timestamps, single image.
`Site` is also **not `Codable`** — it cannot be decoded from any API as written.

### Payments — fully native, no third-party SDK ✅
Repo-wide search: **zero matches** for any third-party payment SDK. This is now enforced by a
CI gate that fails the build if one appears in `LarioGo/`, `LarioGoTests/`, `LarioGoUITests/`
or `Backend/`. Apple Pay / PassKit only; provider-independent `PaymentStatus` / `PaymentMethod`
state when payments are eventually implemented. Verified the gate blocks a planted violation.

---

## 3. BUGS FOUND

### Bug #1 — Duplicate/orphaned Xcode project ✅ FIXED
Two projects both named `LarioGo.xcodeproj`, both git-tracked:
- **Root** `./LarioGo.xcodeproj` — 14 KB, 1 target, `PBXFileSystemSynchronizedRootGroup path = "LarioGo"`
  → resolves to `./LarioGo/` which holds the real source. **This one is correct.**
- **Nested** `./LarioGo/LarioGo.xcodeproj` — 21 KB, 3 targets (app + unit + UI tests), references
  `path = LarioGo` → resolves to `./LarioGo/LarioGo/` **which does not exist**. Stale from a
  pre-reorganization layout.

The root project also carries **3 junk self-references** to `LarioGo.xcodeproj`
(`CE1CBAE4`, `CE1CBB8A`, `CE5192A8`) from someone dragging the nested project in.

Impact: opening the wrong one gave a broken build, and the root project had no test targets,
so **there was no way to run tests at all**.

Fix applied:
- Deleted the orphaned nested `LarioGo/LarioGo.xcodeproj` (recoverable from git history).
- Moved `LarioGoTests/` and `LarioGoUITests/` up to the repo root — the canonical Xcode
  layout — which also removed the need for `membershipExceptions`.
- Rewrote the root `project.pbxproj`: dropped the 3 junk self-references, added
  `LarioGoTests` (unit) and `LarioGoUITests` targets with proper dependencies,
  container proxies, config lists and `TEST_HOST`/`TEST_TARGET_NAME` wiring.
- Added the missing shared scheme. `xcuserdata` claimed the scheme was shared but
  `xcshareddata/xcschemes/LarioGo.xcscheme` did not exist — **CI would have failed
  immediately with "scheme not found"**.
- Verified structurally with `tools/check_project.py`: 3 targets, 0 dangling references,
  0 duplicate objects, balanced delimiters, all scheme blueprint IDs resolve. **Not yet
  verified by xcodebuild.**

### Bug #2 — Asset catalog was entirely non-functional ✅ FIXED
`alpine_medaow_lake_como/` was broken three ways: misspelled ("medaow"), missing the
required `.imageset` directory extension, and its `Contents.json` had no `"filename"` key —
so the PNG was never linked. Renamed to `alpine_meadow_lake_como.imageset/` (matching the
name `TourismData` already used) with a correct `Contents.json`.

### Bug #3 — 10 of 11 referenced images do not exist ⚠️ OPEN
`TourismData` references `basilica_san_nicolo_lecco`, `lecco_lakefront_sunset`,
`romanesque_abbey_cloister`, `resegone_mountain_ridge`, `varenna_lake_como_village`,
`photorealistic_rustic_italian`, `site_lungolago`, `site_varenna`, `site_erna` — none exist.
Not a crash (SiteImage falls back to a gradient) but the app is ~90% placeholder art.
Needs real licensed photography before any launch.

### Bug #4 — `icon.imageset` is empty ⚠️ OPEN
No PNG, no `filename` in Contents.json, and nothing in code references it. Dead asset.
Now reported automatically by `tools/check_project.py`.

### Bug #5 — ProfileView rows are dead ⚠️ OPEN
"My Tickets", "Saved Places", "Visitor Information", "Emergency & Help",
"Official City Service" render a chevron but have no action. Counts ("2 active", "5")
are hardcoded literals. Spec §36 forbids dead buttons.

### Bug #6 — `ItineraryManager` stores `siteID` with no stable identity ✅ FIXED
`Site.id` defaults to `UUID()` generated fresh at every launch because `TourismData.sites`
is a `let` array of literals with no fixed IDs. Persisted itinerary items therefore
reference UUIDs that **never match again after relaunch** — saved itineraries silently
resolve to nothing. This broke Journey 4 and Journey 5 (spec §40).

Fix applied: added a private `SeedID` table to `TourismData` pinning a fixed UUID to each of
the 7 seed sites. Guarded by two regression tests in `LarioGoTests`.

### Bug #7 — `SpeechManager` is not `@MainActor` ⚠️ OPEN
It's an `ObservableObject` publishing `isPlaying`/`currentText` from
`AVSpeechSynthesizerDelegate` callbacks, which are not guaranteed main-thread.
Under Swift 6 strict concurrency this is a data race / likely compile error.
Expected to surface on the first CI build.

### Bug #8 — `TourEvent` date formatting is locale-dependent and allocation-heavy ⚠️ OPEN
`dayString`/`monthString` build a fresh `DateFormatter` per call (expensive, called per
cell during scrolling) and never pin a locale, so the month abbreviation length varies by
device language while `EventCard` reserves a fixed 76pt column. Use a cached, locale-pinned
formatter.

### Bug #9 — No location permission usage strings ✅ FIXED
The app has a Map tab and an AR viewfinder but the generated Info.plist declared neither
`NSLocationWhenInUseUsageDescription` nor `NSCameraUsageDescription`. Requesting either
permission without them is an immediate crash on device. Added both to the app target's
Debug and Release configurations.

---

## 4. ARCHITECTURE DECISIONS (locked)

- **Preserve the existing SwiftUI app.** Extend, never rebuild. Keep `Theme`, the component
  set, and the visual identity exactly as they are.
- **No Stripe, ever.** Provider-independent `PaymentStatus` / `PaymentMethod` enums;
  Apple Pay / PassKit only if online payment is ever needed. Currently clean.
- **Backend:** Swift + Vapor + Fluent + PostgreSQL + JWT, versioned at `/api/v1`.
- **iOS:** MVVM + protocol-backed services, each with a Mock and an API implementation, so the
  UI never changes when swapping mock → live. Centralized API client; no URLSession in views.
- **Geography:** model by region, never hardcode Lecco. Lecco is the seed-content focus only.
- **Traversar boundary:** no TravelMe/LuxHotel code in this repo. Integration happens later via
  the Traversar private API layer — no cross-product database access, service-to-service auth.

---

## 5. STATUS BOARD

| Area | Status |
|---|---|
| Frontend UI shell | Partial — 8 views built, static data, no states |
| Frontend architecture | **Not started** — no VMs, no services, no networking |
| Backend | Phase 1 written (Vapor/Fluent/JWT, health, auth). **Never compiled.** |
| Database | `users` table + migration written. Never run against Postgres. |
| API | `/health`, `/api/v1/auth/{register,login,me}` written. Never served a request. |
| Auth | JWT + bcrypt + bearer authenticator written. **Never executed.** |
| Favorites | **Not started** |
| Search | **Not started** |
| Bookings | UI only, no persistence |
| Reviews | **Not started** |
| Itineraries | Local-only, **broken by Bug #6** |
| Offline | UserDefaults itineraries only |
| Notifications | **Not started** |
| Tests | 12 iOS + 15 backend + ~100 LarioCore tests. **None ever executed.** |
| Deployment | Dockerfile + docker-compose + deploy docs written. Never built. |
| Last successful build | **Never.** CI pushed 2026-08-15 and rejected: billing locked. |
| Last successful test run | **Never.** Only the Python tooling checks pass locally. |

---

## 6. NEXT TASKS (priority order)

1. **Unblock CI (needs you).** See §0. Until then nothing below can be verified, and the
   backlog of unverified Swift keeps growing. Expect real compile errors on the first
   successful run — Bug #7 in particular.
2. **Phase 2** — attractions/restaurants/events endpoints + filtering + geosearch + seed data.
4. **Phase 3** — iOS service protocols, API client, `Codable` models (note: `Site` is not
   currently `Codable`), wire existing views to ViewModels.
5. **Phase 4** — Search tab + Favorites tab (missing from navigation entirely).
6. **Bug #5** — make ProfileView's dead rows real once Favorites/Bookings exist.

---

## 7. CHANGE LOG

- **2026-08-15 (later)** — Phase 1 backend foundation written under `Backend/`:
  Vapor package, `configure` (fail-fast on a missing/weak `JWT_SECRET`, deny-all CORS in
  production), `User` model + unique-email migration, JWT `UserToken` + bearer
  authenticator, `AuthController` (register/login/me), `/health`, 15 tests, Dockerfile,
  docker-compose, `.env.example`, README. Added a Linux backend CI job.
  Verified the workflow with `actionlint` (clean) and re-tested the payment-SDK gate
  against `Backend/`. Pushed — **CI rejected, account billing locked.** Stopped
  Phase 2 rather than pile more unverified code on top.

- **2026-08-15** — Phase 0 audit. Read every source file. Confirmed no backend of any kind
  exists and zero third-party payment SDKs (now a hard CI gate).
  Fixed Bug #1 (project consolidation + test targets + missing shared scheme),
  Bug #2 (asset catalog), Bug #6 (stable seed IDs), Bug #9 (permission usage strings).
  Documented Bugs #3, #4, #5, #7, #8.
  Added `tools/check_project.py` and `tools/pick_simulator.py` (+ its self-test),
  `.github/workflows/ci.yml` (macOS build & test), 12 seed-integrity tests,
  and consolidated `.gitignore`. Untracked `xcuserdata`.
