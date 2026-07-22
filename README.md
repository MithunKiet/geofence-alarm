# GeoAlarm

A production-ready Flutter Android application that triggers an alarm when the user enters a selected geographic area using GPS — even if the app is closed or removed from recent apps.

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Screens](#screens)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Permissions Required](#permissions-required)
- [Database Schema](#database-schema)
- [Packages Used](#packages-used)
- [Battery & Background Behavior](#battery--background-behavior)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)

## Features

- 📍 **Map Location Picker** — tap the map to set an alarm location with a visual radius circle, or search for an address by typing it
- 🔔 **Reliable Background Monitoring** — geofence monitoring runs in a real Android foreground service (`flutter_foreground_task`), so it keeps working after the app is closed or swiped away from recents — not just while the app is open
- 🔊 **Alarm Sound** — plays the system alarm ringtone via `flutter_ringtone_player` on the dedicated alarm audio stream
- 🔕 **Rings Through Do Not Disturb** — optional DND-bypass access so the alarm's visual/notification alert still shows even when the phone is in Silent/DND mode (the sound already plays regardless, since it uses the alarm audio stream)
- 📳 **Notifications** — persistent "monitoring" notification plus a full-screen alarm notification via `flutter_local_notifications`
- 📏 **Live Distance Notification** — while monitoring, the persistent notification updates with your live distance to the nearest active zone
- 💾 **Local Storage** — alarms stored in SQLite via `sqflite`, with schema migrations
- ⏰ **Snooze & Auto-stop** — snooze for 5 minutes, alarm auto-stops after 60 seconds if not dismissed
- 🔁 **Repeating or One-time Alarms** — a repeating alarm re-arms every time you re-enter the zone; a one-time (trip) alarm disables itself the moment it fires, so background location isn't held after your trip is over
- 🔋 **Adaptive Battery-Aware Monitoring** — GPS sampling rate automatically scales down the further you are from any active zone (see [Battery & Background Behavior](#battery--background-behavior))
- 🔄 **State Sync** — toggling, editing, or deleting an alarm from the Home screen immediately re-syncs the background monitoring service, no restart needed

## How It Works

GeoAlarm runs on two Dart isolates that stay in sync:

- **UI isolate** — the normal Flutter app (`AlarmService`, screens, provider state)
- **Service isolate** — `GeofenceTaskHandler`, running inside an Android foreground service via `flutter_foreground_task`, completely independent of whether the app UI is open

The two communicate over `flutter_foreground_task`'s message port: the service isolate streams status/distance/trigger events to the UI (`sendDataToMain`), and the UI isolate can send commands (stop alarm, snooze, refresh monitored alarms) back to the service (`sendDataToTask`).

This is what makes the alarm reliable when the app is closed — Android keeps the foreground service (and its persistent notification) alive independently of the app's UI, and only an explicit **Force Stop** from Android's app settings can kill it (this is an OS-level restriction, no app can work around it).

## Screens

| Screen | Description |
|---|---|
| Home | List of all alarms with toggle / edit / delete, live status |
| Map Picker | Interactive Google Map to pick a location & radius, or search by address |
| Alarm Settings | Create or edit an alarm, choose repeating vs. one-time |
| Alarm Ring | Full-screen alarm with STOP and SNOOZE buttons |

## Project Structure

```
lib/
├── main.dart                          # App entry point, foreground-task port init
├── config/
│   ├── app_routes.dart
│   └── constants.dart                 # Tunables: radii, tiers, intervals, DB schema
├── models/
│   └── alarm_model.dart
├── database/
│   └── database_helper.dart           # sqflite setup + schema migrations
├── providers/
│   └── alarm_provider.dart
├── services/
│   ├── location_service.dart
│   ├── geofence_service.dart          # UI-isolate facade over the foreground service
│   ├── geofence_task_handler.dart     # Service-isolate logic: adaptive monitoring, alarms
│   ├── alarm_service.dart             # Mirrors triggered/stopped alarm state in the UI
│   └── notification_service.dart      # Alarm + DND-bypass notification logic
├── screens/
│   ├── home/home_screen.dart
│   ├── map/map_picker_screen.dart
│   └── alarm/
│       ├── alarm_settings_screen.dart
│       └── alarm_ring_screen.dart
├── widgets/
│   ├── alarm_card.dart
│   ├── radius_selector.dart
│   └── custom_button.dart
├── utils/
│   ├── permission_utils.dart
│   ├── distance_utils.dart
│   └── validators.dart
└── theme/
    └── app_theme.dart
```

## Setup Instructions

### Prerequisites

- Flutter SDK ≥ 3.0 (stable channel)
- Android Studio or VS Code with Flutter plugin
- Android device / emulator (API 21+)

### 1. Clone the repository

```bash
git clone https://github.com/MithunKiet/geofence-alarm.git
cd geofence-alarm
```

### 2. Add Google Maps API Key

The app needs a Google Maps API key to show the map screen. **Never commit this key or put it directly in `AndroidManifest.xml`** — it always goes in `android/local.properties`, which is git-ignored, and Gradle injects it at build time.

**Step 1 — Get an API key**

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create/select a project
2. Go to **APIs & Services → Library**, search for **Maps SDK for Android**, and enable it
3. Go to **APIs & Services → Credentials → Create Credentials → API key**

**Step 2 — Get your SHA-1 fingerprint** (needed to restrict the key)

```bash
# Debug key (used by `flutter run`)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows path is usually:
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copy the `SHA1:` value from the output.

**Step 3 — Restrict the key** (strongly recommended, especially on a public repo)

1. In Google Cloud Console, open your new key → **Edit**
2. Under **Application restrictions**, choose **Android apps** → **Add package name and fingerprint**
   - Package name: `com.example.geofence_alarm`
   - SHA-1: the value from Step 2
3. Under **API restrictions**, choose **Restrict key** → select only **Maps SDK for Android**
4. Save

**Step 4 — Add the key to `android/local.properties`**

This file already exists in your project (auto-generated by Flutter/Android Studio with your `sdk.dir` etc.) — open it and add one line at the end. If it doesn't exist yet, create it in the `android/` folder:

```properties
MAPS_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

That's it — no other file needs to change. `local.properties` is listed in `android/.gitignore`, so `git status` should never show it, and the key never gets committed. The key is injected into `AndroidManifest.xml` at build time via a Gradle manifest placeholder (see `android/app/build.gradle.kts`). Without it, the app still builds and runs, but the map screen shows a blank/grey map.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
flutter run
```

Or open in Android Studio / VS Code and press **Run**.

### 5. Grant permissions on first launch

For the app to actually work end-to-end, walk through every prompt on first launch and accept them all: precise location, "Allow all the time" background location, notifications, and (optionally) battery-optimization exemption and DND access. See [Permissions Required](#permissions-required) below for what each one is for.

## Permissions Required

| Permission | Purpose |
|---|---|
| `ACCESS_FINE_LOCATION` | Precise GPS location |
| `ACCESS_COARSE_LOCATION` | Network-based location fallback |
| `ACCESS_BACKGROUND_LOCATION` | Monitor location when the app is backgrounded/closed |
| `POST_NOTIFICATIONS` | Show the monitoring and alarm notifications |
| `USE_FULL_SCREEN_INTENT` | Launch the full-screen alarm-ring UI from the lock screen |
| `ACCESS_NOTIFICATION_POLICY` | Let the alarm notification channel request to bypass Do Not Disturb |
| `VIBRATE` | Vibrate on alarm |
| `WAKE_LOCK` | Keep the CPU awake while the foreground service monitors location |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION` | Run geofence monitoring as an Android foreground service |
| `RECEIVE_BOOT_COMPLETED` | Restore scheduled notifications after a device reboot |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ask to be excluded from OEM battery killers (Xiaomi/Samsung/OnePlus/Oppo, etc.) so monitoring isn't killed in the background |

> **Note:** On Android 10+, the user must explicitly grant **"Allow all the time"** location access (not just "While using the app") for background geofencing to work at all. Some OEM Android skins also aggressively kill background apps regardless of official permissions — disabling battery optimization for GeoAlarm in system Settings significantly improves reliability.

> Do Not Disturb access has no runtime permission dialog on Android — it's a manual toggle in system Settings, so the app shows a one-time rationale dialog and links there. Declining it only means the notification/visual alert can be suppressed by DND; the alarm sound itself still plays, since it's on the alarm audio stream.

## Database Schema

```sql
CREATE TABLE alarms (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    title        TEXT    NOT NULL,
    latitude     REAL    NOT NULL,
    longitude    REAL    NOT NULL,
    radius       REAL    NOT NULL,
    is_active    INTEGER NOT NULL DEFAULT 1,
    created_at   TEXT    NOT NULL,
    is_one_time  INTEGER NOT NULL DEFAULT 0   -- added in schema v2
);
```

`is_one_time` rows migrated from schema v1 default to `0` (repeating), preserving prior behavior for existing installs.

## Packages Used

| Package | Version | Purpose |
|---|---|---|
| `google_maps_flutter` | ^2.5.0 | Google Maps widget |
| `geolocator` | ^14.0.2 | GPS location access |
| `geocoding` | ^5.0.0 | Address search on the map picker |
| `flutter_foreground_task` | ^9.2.2 | Foreground service for background geofence monitoring |
| `flutter_local_notifications` | ^21.0.0 | System notifications, DND bypass |
| `flutter_ringtone_player` | ^4.0.0+4 | Play the alarm sound |
| `sqflite` | ^2.3.0 | Local SQLite database |
| `path` | ^1.9.0 | File path utilities |
| `provider` | ^6.1.1 | State management |
| `permission_handler` | ^12.0.1 | Runtime permissions |

> **Note:** the previously used `geofence_service` package (discontinued upstream, and never actually started a real Android service) has been removed. Geofence checks now run inside a `flutter_foreground_task` foreground service using `geolocator` position streams and a Haversine distance check, so monitoring survives the app being backgrounded or removed from recents. Android does not allow any app to keep running after an explicit **Force Stop**.

## Battery & Background Behavior

Continuously polling high-accuracy GPS all the time would drain the battery fast, so monitoring is **adaptive** based on how close you are to the nearest edge of any active geofence:

| Tier | Distance to nearest zone edge | Behavior |
|---|---|---|
| **Close** | ≤ 200 m | Continuous high-accuracy GPS stream |
| **Near** | ≤ 2000 m | Continuous balanced-power GPS stream |
| **Far** | > 2000 m | GPS off; one-shot low-power checks on a timer, sized by distance ÷ an assumed max travel speed (so it checks more often the closer you get) |

A watchdog also periodically re-checks that monitoring is actually still active, and monitoring automatically stops entirely once there are no active alarms left (e.g. after a one-time alarm fires), so the background service isn't kept alive for nothing.

## Security Notes

- The Google Maps API key is **not** stored in `AndroidManifest.xml` — it's injected
  at build time from `android/local.properties` (git-ignored) via a Gradle manifest
  placeholder. See [Setup Instructions → Step 2](#2-add-google-maps-api-key).
- Restrict your API key in Google Cloud Console to only the Maps SDK for Android,
  scoped to this app's package name and signing certificate fingerprint.
- The `android/local.properties` file is excluded from source control (contains
  local SDK paths and the Maps API key). `android/key.properties` and any
  `*.keystore`/`*.jks` signing files are excluded too — never commit those either.
- If a secret is ever accidentally committed, changing the file afterwards is not
  enough — it stays in git history. Rotate the exposed credential immediately and
  rewrite history (e.g. with `git-filter-repo`) to remove it, then force-push.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Map screen is blank/grey | Google Maps API key missing or invalid — see [Setup Instructions → Step 2](#2-add-google-maps-api-key) |
| Alarm doesn't trigger when app is closed | Background location not set to "Allow all the time", or the OS killed the foreground service — disable battery optimization for GeoAlarm in system Settings |
| Alarm notification doesn't show in Do Not Disturb mode | Grant Do Not Disturb access when prompted, or manually in Settings → Notifications → Do Not Disturb access. The alarm sound itself still plays either way |
| Address search returns "No results found" | Some Android OEM builds ship an unreliable native geocoder; try a more complete address, or drop a pin manually on the map instead |
| DND rationale dialog keeps reappearing | Should only show once until granted — if it persists, check that the app hasn't lost notification-policy access in system Settings |
