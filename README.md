# Milo ChatBot Frontend

Milo is a Flutter companion app for authenticated AI chat and speech. Firebase
Authentication handles Google sign-in; the FastAPI backend validates Firebase
ID tokens before serving chat and speech requests.

## Firebase setup

1. In the [Firebase Console](https://console.firebase.google.com/), open
   project `milo-2107d`.
2. In **Authentication > Sign-in method**, enable **Google**. Milo's app login
   uses Google sign-in only.
3. In **Project settings > General > Your apps**, open the Android app and add
   the SHA-1 fingerprint for the signing key. For this development environment,
   `cd android && ./gradlew signingReport` reports debug SHA-1
   `DF:1C:FA:CA:19:BB:DB:69:EE:47:06:77:8D:AD:30:0D:21:AA:64:4D`.
   Register your release signing key's SHA-1 separately before publishing.
4. FlutterFire registered the Android app using this project's Android
   application ID and generated `lib/firebase_options.dart`. After adding the
   fingerprint, regenerate the Android config:

   ```sh
   flutterfire configure --project=milo-2107d --platforms=android
   ```

   This refreshes `google-services.json` with the OAuth client needed for
   Google sign-in.
5. Set `FIREBASE_PROJECT_ID=milo-2107d` in the backend deployment environment.
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

The app calls `https://milo-chatbot-backend.onrender.com` for chat and speech;
the production endpoint is intentionally not editable in Settings. Requests
use the signed-in user's Firebase ID token. Spoken replies use OpenAI's
`gpt-4o-mini-tts` and consume OpenAI API usage; on-device speech is the fallback
if backend speech generation fails. Milo's home and voice screens render the
selected bundled animated GLB companion model with `model_viewer_plus`.
Newly signed-in users select Milo or Suzu before entering Home. The choice is
saved per Firebase account and can be changed in Settings. Milo uses the
original boy GLB and the backend's Ash voice/persona; Suzu uses the girl GLB
and the backend's Nova voice/persona.
On iOS and Android, `model_viewer_plus` serves each selected GLB directly from
Flutter's bundled assets to its local WebView; the model is not converted to a
base64 data URL. If the WebView does not report a successful load within 30
seconds, the viewer reports a load error instead of leaving a blank preview.
At initial launch, the Home screen remains on Milo's themed loading screen until
the GLB viewer reports that the model is ready. It does not substitute the
2D avatar; if model initialization fails or takes longer than 30 seconds, the
loading screen stays visible and offers a retry. The Home camera uses the
loaded model's bounds for its target, orbit distance, and field of view so
different GLB dimensions are framed consistently from the first render.
Settings loads 3D previews for both companions without requiring selection.
The Voice screen uses only the GLB model (no character-image fallback), framed
smaller than Home. Its camera is framed farther out to keep both companions'
full bodies visible above the Voice controls, including during jump animations.
While the companion speaks, playback progress
drives per-word mouth movement and the `talk` animation. Suzu's GLB does not
contain facial morph targets, so the viewer animates its separate mouth mesh
from the playback progress. When speech ends in live mode, she returns to
`listen`. Suzu's GLB includes `idle`, `walk`, `run`, `wave`, and `jump` clips.
The viewer supplies procedural body motion for her missing `listen`, `talk`,
`dance`, `spin`, and `think` actions.

Companion names in Home, chat, the voice screen, and thinking indicators follow
the selected character. Chat and speech requests include the selected
companion; the backend uses its original Nova voice and character-specific
speech instructions for Suzu, and Ash for Milo.
Conversation history is stored locally under the signed-in Firebase user's ID;
it is not currently synchronized to a server or across devices. The old
unscoped local history is discarded because its account owner cannot be
verified. On startup, Milo waits for local preferences and the 3D model before
showing Home.
Firebase Authentication has a no-cost tier, while AI provider usage may incur
separate charges.

## Validate changes

```sh
flutter analyze
flutter test
```

Before publishing, replace the Android `applicationId` placeholder with an
identifier you control, set up a private release signing key, and verify the
production backend endpoint and Firebase OAuth fingerprints for that app ID.
