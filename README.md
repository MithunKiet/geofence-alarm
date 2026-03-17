# GeoAlarm

A production-ready Flutter Android application that triggers an alarm when the user enters a selected geographic area using GPS.

## Features

- 📍 **Map Location Picker** — tap the map to set alarm location with visual radius circle
- 🔔 **Alarm Monitoring** — continuous geofence monitoring using `geofence_service`
- 🔊 **Alarm Sound** — plays alarm.mp3 using `audioplayers`
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
3. Create an API key
4. Replace `YOUR_API_KEY_HERE` in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY" />
```

### 3. Add Alarm Sound

Place an `alarm.mp3` file in the `assets/sounds/` directory:

```
assets/
└── sounds/
    └── alarm.mp3   ← add your alarm sound here
```

You can use any royalty-free alarm sound. The app will still work without it (just no audio).

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run the app

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
| `geolocator` | ^10.1.0 | GPS location access |
| `geofence_service` | ^5.0.0 | Geofence monitoring |
| `flutter_local_notifications` | ^16.1.0 | System notifications |
| `audioplayers` | ^5.2.1 | Play alarm sound |
| `sqflite` | ^2.3.0 | Local SQLite database |
| `path` | ^1.9.0 | File path utilities |
| `provider` | ^6.1.1 | State management |
| `permission_handler` | ^11.1.0 | Runtime permissions |

## Security Notes

- The Google Maps API key in `AndroidManifest.xml` is a placeholder — replace before deploying
- Restrict your API key in Google Cloud Console to only the Maps SDK for Android
- The `android/local.properties` file is excluded from source control (contains local SDK paths)

## Setup

### Google Maps API Key

This app uses Google Maps. You **must** replace the placeholder API key in
`android/app/src/main/AndroidManifest.xml` before building:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project and enable the **Maps SDK for Android**
3. Create an API key and restrict it to your app's package name (`com.example.geofence_alarm`)
4. Replace `YOUR_API_KEY_HERE` with your key

### Alarm Sound

Add a real `alarm.mp3` file to `assets/sounds/alarm.mp3`. The app will log a
warning and still show the alarm screen/notification if the file is absent.

## Features

- Tap on a map to place a geofence alarm
- Choose a radius (100 m, 200 m, 500 m or 1 km)
- Background geofence monitoring
- Full-screen alarm screen with Stop and Snooze (5 min) actions
- Auto-stop after 60 seconds
- SQLite persistence via sqflite
