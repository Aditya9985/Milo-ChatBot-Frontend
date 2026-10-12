# Milo-ChatBot-Frontend

Milo is a Flutter companion app for AI chat, text-to-speech, and live voice
conversations. It opens directly to the home screen and does not ship with
sample conversations or simulated AI responses.

## Run locally

1. Install Flutter and fetch dependencies:

   ```sh
   flutter pub get
   ```

2. Start a compatible FastAPI service that provides `/health` and `/chat`
   endpoints.
3. Run the app:

   ```sh
   flutter run
   ```

The app checks the backend health endpoint and shows its connection status in
the chat/settings screens. Android emulators use `10.0.2.2:8000`; iOS
simulators, desktop and web use `127.0.0.1:8000` by default. Set a reachable
backend address from **Settings** when using a physical device.

## Validate changes

```sh
flutter analyze
flutter test
```

Before publishing, replace the Android `applicationId` placeholder with an
identifier under a domain you control, and configure the backend URL and
transport security for the target environment.
