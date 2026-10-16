# Milo ChatBot Frontend

Milo is a Flutter companion app for authenticated AI chat and speech. Firebase
Authentication handles email/password accounts; the FastAPI backend validates
Firebase ID tokens before serving chat and speech requests.

## Firebase setup

1. In the [Firebase Console](https://console.firebase.google.com/), open
   project `milo-2107d`.
2. In **Authentication > Sign-in method**, enable **Email/Password**.
3. FlutterFire has registered the Android app using this project's Android
   application ID and generated `lib/firebase_options.dart`. Re-run
   `flutterfire configure --project=milo-2107d --platforms=android` after
   adding another platform or changing the Firebase app configuration.
4. Set `FIREBASE_PROJECT_ID=milo-2107d` in the backend deployment environment.
   See [the backend setup](../backend/README.md).

The Firebase client values identify the app and are not service-account
credentials. Never add a service-account private key to the Flutter app.

## Run locally

Fetch packages:

```sh
flutter pub get
```

Run on Android using the generated Firebase options:

```sh
flutter run
```

Build a release APK with `flutter build apk`, or a Play Store bundle with
`flutter build appbundle`. If you add iOS or web, run FlutterFire configure
with the additional platform(s) before building.

The app uses `https://milo-chatbot-backend.onrender.com` by default; change it
from **Settings** if needed. Chat and speech API requests use the signed-in
user's Firebase ID token. Spoken replies use OpenAI's `gpt-4o-mini-tts` and
consume OpenAI API usage; on-device speech is the fallback if backend speech
generation fails. Firebase Authentication has a no-cost tier, while AI
provider usage may incur separate charges.

## Validate changes

```sh
flutter analyze
flutter test
```

Before publishing, replace the Android `applicationId` placeholder with an
identifier you control and configure the backend URL for the target
environment.
