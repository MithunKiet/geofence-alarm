# Geofence Alarm

Flutter application that triggers an alarm when the user enters a selected location using geofencing.

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
