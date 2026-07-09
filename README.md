# GeoAlarm

A production-ready Flutter Android application that triggers an alarm when the user enters a selected geographic area using GPS.

## Features

- 📍 **Map Location Picker** — tap the map to set alarm location with visual radius circle
- 🔔 **Alarm Monitoring** — geofence monitoring in a foreground service (`flutter_foreground_task` + `geolocator`) that keeps running after the app is closed
- 🔊 **Alarm Sound** — plays the system alarm ringtone via `flutter_ringtone_player`
- 📳 **Notifications** — system notifications via `flutter_local_notifications`
- 💾 **Local Storage** — alarms stored in SQLite via `sqflite`
- ⏰ **Snooze & Auto-stop** — snooze for 5 min, auto-stop after 60 s
- 🔄 **Background Support** — works when app is in background

## Screens

| Screen | Description |
|---|---|
| Home | List of all alarms with toggle / edit / delete |
| Map Picker | Interactive Google Map to pick location & radius |
| Alarm Settings | Create or edit an alarm |
| Alarm Ring | Full-screen alarm with STOP and SNOOZE buttons |

## Project Structure

```
lib/
├── main.dart
├── config/
│   ├── app_routes.dart
│   └── constants.dart
├── models/
│   └── alarm_model.dart
├── database/
│   └── database_helper.dart
├── providers/
│   └── alarm_provider.dart
├── services/
│   ├── location_service.dart
│   ├── geofence_service.dart
│   ├── alarm_service.dart
│   └── notification_service.dart
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

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable **Maps SDK for Android**
3. Create an API key and restrict it to this app's package name (`com.example.geofence_alarm`) and your debug/release SHA-1 fingerprint
4. Add it to `android/local.properties` (this file is git-ignored, so the key is never committed):

```properties
MAPS_API_KEY=YOUR_ACTUAL_API_KEY
```

The key is injected into `AndroidManifest.xml` at build time via a Gradle manifest placeholder. Without it, the app still builds and runs, but the map screen shows a blank map.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
flutter run
```

Or open in Android Studio / VS Code and press **Run**.

## Permissions Required

The app requests the following permissions at runtime:

| Permission | Purpose |
|---|---|
| `ACCESS_FINE_LOCATION` | Precise GPS location |
| `ACCESS_COARSE_LOCATION` | Network-based location |
| `ACCESS_BACKGROUND_LOCATION` | Monitor location when app is in background |
| `POST_NOTIFICATIONS` | Show alarm notifications |
| `VIBRATE` | Vibrate on alarm |
| `FOREGROUND_SERVICE` | Run location service in foreground |

> **Note:** On Android 10+, the user must explicitly grant "Allow all the time" location permission for background geofencing to work.

## Database Schema

```sql
CREATE TABLE alarms (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT    NOT NULL,
    latitude   REAL    NOT NULL,
    longitude  REAL    NOT NULL,
    radius     REAL    NOT NULL,
    is_active  INTEGER NOT NULL DEFAULT 1,
    created_at TEXT    NOT NULL
);
```

## Packages Used

| Package | Version | Purpose |
|---|---|---|
| `google_maps_flutter` | ^2.5.0 | Google Maps widget |
| `geolocator` | ^14.0.2 | GPS location access |
| `flutter_foreground_task` | ^9.2.2 | Foreground service for background geofence monitoring |
| `flutter_local_notifications` | ^21.0.0 | System notifications |
| `flutter_ringtone_player` | ^4.0.0+4 | Play the alarm sound |
| `sqflite` | ^2.3.0 | Local SQLite database |
| `path` | ^1.9.0 | File path utilities |
| `provider` | ^6.1.1 | State management |
| `permission_handler` | ^12.0.1 | Runtime permissions |

> **Note:** the previously used `geofence_service` package (discontinued upstream)
> has been removed. Geofence checks now run inside a `flutter_foreground_task`
> foreground service using `geolocator` position streams and a Haversine
> distance check, so monitoring survives the app being backgrounded or removed
> from recents. Android does not allow any app to keep running after an
> explicit **Force Stop**.

## Security Notes

- The Google Maps API key is **not** stored in `AndroidManifest.xml` — it's injected
  at build time from `android/local.properties` (git-ignored) via a Gradle manifest
  placeholder. See Setup Instructions → Step 2.
- Restrict your API key in Google Cloud Console to only the Maps SDK for Android,
  scoped to this app's package name and signing certificate fingerprint.
- The `android/local.properties` file is excluded from source control (contains
  local SDK paths and the Maps API key).
