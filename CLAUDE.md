# skamp! — Project Guide

## Overview
Digital stamp-based photo journal app for iOS and Android. Users capture photos through a physical "stamp machine" viewfinder, build scrapbook journals, and share with friends.

## Project Structure
- Flutter project: `x:\Skamp\skamp\`
- GitHub: `https://github.com/ymetdev/Skamp_app`
- Firebase project ID: `skamp-f2367` (asia-southeast1)
- Assets: `assets/`
  - `icon_stamp.png` — stamp icon (red/pink)
  - `wordmark.png` — wordmark "skamp!" (static)
  - `wordmark_anim.gif` — wordmark animation (used on splash screen)
  - `logo_white.png` — white logo
  - `machine_perforated.png` `machine_serrated.png` `machine_rounded.png` `machine_rect.png` — machine overlay images (transparent viewfinder)

## Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Firebase
  - Firebase Auth — Google Sign-In + Email/Password
  - Firestore — users, friends, journals, stamp collections, invite codes, app config
  - Cloud Functions — GPS verification, gift processing
- **Image Storage:** Cloudinary (cloud name: `dg3ctv3km`, preset: `skamp_upload`)
  - Firebase Storage ไม่ได้ใช้ (billing issue) — ใช้ Cloudinary แทน
- **State Management:** Riverpod v3 (flutter_riverpod)
- **Routing:** go_router
- **GPS:** Device GPS + GeoJSON country boundaries, server-side verified

## Firestore Collections
```
users/{uid}               — profile, isInvited, isPremium, username, dailyStampCount, lastStampDate
usernames/{username}      — reverse lookup uid
inviteCodes/{code}        — used: bool, usedBy: uid, usedAt
config/app                — inviteOnly: bool
stamps/{stampId}          — paper stamps (ownerId, imageUrl, shape, isPlaced, capturedAt, lat/lng)
rubberStamps/{stampId}    — rubber stamps (ownerId, imageUrl, shape, unlockedAt)
journals/{journalId}      — journal (ownerId, title, paperStyle, coverColor, pageCount)
journals/{id}/pages/{id}  — journal pages (pageNumber, stamps: [PlacedStamp])
```

**Required Firestore composite indexes:**
- `stamps`: `ownerId` ASC + `isPlaced` ASC + `capturedAt` DESC
- `rubberStamps`: `ownerId` ASC + `unlockedAt` DESC
- `journals`: `ownerId` ASC + `updatedAt` DESC

## Auth & Onboarding Flow
```
Login (Google / Email+Password)
  → /loading (spinner while Firestore user doc loads)
  → [inviteOnly=true] /invite — Invite Code screen
  → /username-setup — Username Setup (mandatory, unique, cannot change)
  → /home — Camera screen
```

**Invite-only toggle:** แก้ `inviteOnly` ใน Firestore `config/app` — ไม่ต้อง redeploy

## App Navigation Architecture

### Home Screen — Vertical PageView
`/home` = HomeScreen shell with IndexedStack + persistent bottom nav pill

```
HomeScreen
├── IndexedStack
│   ├── Tab 0: _CameraTab (vertical PageView)
│   │   ├── Page 0: Camera + machine overlay (default view)
│   │   └── Page 1: Feed (swipe up from camera)
│   ├── Tab 1: _CollectionTab (dark theme, stamp grid)
│   ├── Tab 2: _FriendsTab (dark theme, placeholder)
│   └── Tab 3: _JournalsTab (dark theme, journal list)
└── _NavPill (persistent bottom nav: Home/Collection/Friends/Journal)
```

**Navigation behavior:**
- Open app → camera immediately (machine + live viewfinder)
- Swipe up → Feed / Swipe down → back to camera
- Bottom nav → switch tabs without losing camera state
- `/stamps`, `/journals` routes = full-screen versions (pushed from top bar buttons)

### Routes
```
/loading          — animated splash (stamp bounce) while auth loads
/login            — Google + email/password
/invite           — invite code entry
/username-setup   — first-time username setup
/home             — main shell (camera + all tabs)
/camera           — standalone camera (for future use from non-home contexts)
/stamps           — standalone collection screen
/journals         — standalone journal list
/journal/:id      — journal detail (page grid)
/journal/:id/page/:pageId — page editor (drag-and-drop stamps)
/profile          — profile (points to home)
```

## Camera — Stamp Machine UI

### Machine Overlay
4 physical machine PNGs (`x1.png`–`x4.png`) with transparent viewfinder centers.  
Camera preview shows through the transparent hole naturally.

| Machine | Asset | Stamp Shape |
|---------|-------|-------------|
| 1 | `x1.png` | Perforated |
| 2 | `x2.png` | Serrated |
| 3 | `x3.png` | Rounded |
| 4 | `x4.png` | Rectangle |

**Machine selector:** 4 dots in top bar (between person+ and person buttons)  
**Capture trigger:** Tap the slot at the bottom of the machine image

### Camera Page Layout
```
Stack (full screen)
├── CameraPreview (full screen background)
├── StampMachineOverlay (x1-x4 PNG centered)
├── Top bar: [person+ circle] [machine dots] [person circle]
├── Feed hint ("↓ Feed •") just above nav
└── [nav pill handled by shell]
```

## Stamp Types (core mechanic)

| Type | Source | Journal use | Giftable |
|------|--------|-------------|----------|
| **Paper stamp** | Captured via in-app camera | One-time (consumed on place) | Yes (copy — sender keeps original) |
| **Rubber stamp** | Unlocked via Achievement | Unlimited reuse | No |

**Rubber stamp sources:**
- Country stamps — must capture a photo while physically in that country (GPS verified)
- Easter Egg City stamps — GPS-based hidden city locations, zero hints in-app
- Achievement stamps — milestones with hints (e.g. "collect 100 stamps")

## Journal
- Named by user, paper style selectable (lined, graph, blank, dotted) — **all free**
- Drag paper stamps + rubber stamps onto pages
- Paper stamp = consumed on place, rubber stamp = unlimited reuse
- Free: 3 journals / 24 pages | Premium: unlimited / 32 pages each
- PlacedStamp positions stored as normalized x,y (0.0–1.0) on page

## Social (Friends only — no public feed)
- Add friends by **Username** (set once, cannot change)
- Free: max 20 friends | Premium: unlimited
- Friends tab = feed of friends' shared stamps/pages
- No follow system, no public feed in-app
- Public sharing = export only (Instagram, TikTok)

## Design Language
- **Camera/main:** dark theme (black background, white text)
- **Feed/journal:** warm cream (#F0E8D0), muted paper aesthetic
- **Nav pill:** dark gray (#2A2A2A) with white active indicator
- **Accent:** Vivid Red (#CC3333) for skamp! wordmark and active elements
- Physical-feeling animations: stamp "thump" bounce on loading screen
- Haptic feedback on all stamp interactions

## Key Files
```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   ├── stamp_model.dart          — PaperStamp, RubberStamp, StampShape enum
│   └── journal_model.dart        — Journal, JournalPage, PlacedStamp, PaperStyle
├── core/
│   ├── theme/app_theme.dart
│   ├── router/router.dart        — GoRouter + _LoadingSplash animated widget
│   ├── providers/app_config_provider.dart
│   └── services/cloudinary_service.dart
└── features/
    ├── auth/
    │   ├── repositories/auth_repository.dart
    │   ├── providers/auth_provider.dart
    │   └── screens/login_screen.dart, invite_code_screen.dart, username_setup_screen.dart
    ├── home/screens/home_screen.dart   — Shell + _CameraTab + _FeedPage + dark section tabs
    ├── camera/
    │   ├── screens/camera_screen.dart  — standalone camera route
    │   └── widgets/
    │       ├── stamp_machine.dart      — StampMachineOverlay, MachineSelector, MachineCircleButton
    │       └── stamp_shape_clipper.dart — StampClipper, StampShapePainter, kStampAspect
    ├── stamps/
    │   ├── repositories/stamp_repository.dart
    │   ├── providers/stamp_provider.dart
    │   └── screens/collection_screen.dart
    └── journals/
        ├── repositories/journal_repository.dart
        ├── providers/journal_provider.dart
        └── screens/
            ├── journal_list_screen.dart
            ├── journal_detail_screen.dart
            └── journal_page_screen.dart
```

## Monetization — Freemium
| Feature | Free | Premium |
|---------|------|---------|
| Paper stamps/day | 3 | Unlimited |
| Journals | 3 | Unlimited |
| Pages/journal | 24 | 32 |
| Friends | 20 | Unlimited |
| Photo source | In-app camera only | Camera roll import + in-app |

## Dev Commands
```powershell
# Run on Android emulator (requires emulator to be running)
cd x:\Skamp\skamp
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
$env:ANDROID_HOME = "X:\Android"
C:\flutter\bin\flutter.bat run -d emulator-5554

# Start emulator (AVD: skamp_test, Android 36)
X:\Android\emulator\emulator.exe -avd skamp_test -accel auto -gpu auto -no-boot-anim

# Run on web (port 5500)
C:\flutter\bin\flutter.bat run -d web-server --web-port 5500

# Build web
C:\flutter\bin\flutter.bat build web --no-tree-shake-icons
```

## Known Issues / Notes
- `google_sign_in ^7.2.0` requires `GoogleSignIn.instance.initialize(serverClientId: ...)` before authenticate — done in `google_auth_mobile.dart`
- Kotlin incremental compiler fails cross-drive (C: vs X:) — disabled via `kotlin.incremental=false` in `android/gradle.properties`
- JDK must be 21 (`org.gradle.java.home=C:\\Program Files\\Java\\jdk-21`)
- Firestore composite indexes must be created manually in Firebase Console (see above)
- Ad blockers block Firestore on localhost — disable for localhost when testing web
