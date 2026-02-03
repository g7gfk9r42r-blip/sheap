## Firebase Quickstart (1 Command)

Projekt: `/Users/romw24/dev/AppProjektRoman/roman_app`

### Ablage (neu, empfohlen)
- **iOS**: `firebase/Apple/GoogleService-Info.plist`
- **Android**: `firebase/Google/google-services.json`

### Ablage (Alternative – wie du es beschrieben hast)
- **iOS**: `apple/GoogleService_Info.plist`
- **Android**: `google/google_services.json`

### Web/Chrome
Wichtig: **Chrome = Web**. Wenn du in Chrome **Login + “eingeloggt bleiben”** willst, brauchst du **Firebase Web Auth config**.

#### Preview (ohne Login/Firebase)
Startet die App in Chrome, aber **ohne Firebase/Auth** (reiner Preview-Modus).

```bash
RUN_WEB=1 ./tools/run_with_firebase.sh
```

#### Chrome Login (ohne Firebase Web) – empfohlen wenn du nur Android+iOS Firebase willst
Startet Chrome mit **lokalem Login** (E‑Mail/Passwort wird lokal gespeichert, kein Firebase im Web).

```bash
RUN_WEB_LOCAL_AUTH=1 ./tools/run_with_firebase.sh
```

#### Chrome mit Firebase Auth (Login + Session-Persistenz)
1) In Firebase Console eine **Web App** anlegen und die Web-Config holen
2) In `roman_app/.env` eintragen:

```bash
FIREBASE_WEB_API_KEY=...
FIREBASE_WEB_APP_ID=...
FIREBASE_WEB_MESSAGING_SENDER_ID=...
FIREBASE_WEB_PROJECT_ID=...
FIREBASE_WEB_AUTH_DOMAIN=...
```

Dann starten:

```bash
RUN_WEB_AUTH=1 ./tools/run_with_firebase.sh
```

### Option 1 (automatisch)
```bash
./tools/run_with_firebase.sh
```

Das Script:
- findet die **neueste** `GoogleService-Info.plist` (Projekt + typische Ordner),
- validiert Pflicht-Keys (`API_KEY`, `PROJECT_ID`, `GOOGLE_APP_ID`, `BUNDLE_ID`),
- kopiert nach `ios/Runner/` (overwrite),
- kopiert `firebase/Google/google-services.json` nach `android/app/google-services.json` (overwrite),
- macht `flutter clean`, `flutter pub get`, `pod install`, `flutter run`.

### Option 2 (empfohlen, garantiert richtig)
```bash
export GOOGLE_SERVICE_PLIST="/voller/pfad/GoogleService-Info.plist"
./tools/run_with_firebase.sh
```

### Wenn es fehlschlägt
- **ℹ️ CLIENT_ID/REVERSED_CLIENT_ID fehlen** → ok für Email/Passwort (wird nur gewarnt).
- **❌ Pflicht-Keys fehlen** (`GOOGLE_APP_ID`, `API_KEY`, `PROJECT_ID`, `BUNDLE_ID`) → plist neu aus Firebase Console laden.
- **❌ Keine plist gefunden** → Env setzen:
  - `export GOOGLE_SERVICE_PLIST="/voller/pfad/GoogleService-Info.plist"`


