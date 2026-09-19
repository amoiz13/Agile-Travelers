# Agile Travellers

Agile Travellers is a Flutter Android prototype for planning Swedish public
transport journeys with the Trafiklab ResRobot API.

## Prototype features

- Station-name autocomplete using ResRobot
- Journey search for Swedish public transport
- Journey leg details for trains, buses, and walking
- CO2 estimates per leg and per journey
- Sorting by departure time, journey duration, transfers, or CO2
- Android splash screen and Agile Travellers branding

## Setup

1. Install Flutter and Android Studio.
2. Copy `.env.example` to `.env`.
3. Add a Trafiklab ResRobot API key:

   ```env
   RESROBOT_API_KEY=your_key_here
   ```

4. Run:

   ```powershell
   flutter pub get
   flutter run
   ```

The `.env` file is ignored by Git and must never be committed.

## Build the Android prototype

```powershell
flutter build apk --release --build-name 0.1.0 --build-number 1
```

The generated APK is written to
`build/app/outputs/flutter-apk/app-release.apk`.

## Versioning

The current release is `0.1.0+1`, an initial prototype build. The `0.1.0`
tag and GitHub release identify this milestone; later features should use a
new semantic version and Android build number.
