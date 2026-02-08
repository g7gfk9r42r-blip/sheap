# sheap – Release Guide (App Store + Play Store)

## 0) One-time prerequisites

### IDs
- Android `applicationId`: `com.sheap.app`
- iOS `CFBundleIdentifier`: `com.sheap.app`

### Firebase configs (must match IDs)
- `android/app/google-services.json` (Firebase Android app for `com.sheap.app`)
- `ios/Runner/GoogleService-Info.plist` (Firebase iOS app for `com.sheap.app`)

> These files should not be committed for public repos. Keep them local/CI secrets.

## 1) Remote-first weekly recipes (no store updates)

The app loads recipes **remote-first** via HTTP with weekly caching.

### Production base URL
Build the app with:
- `--dart-define=API_BASE_URL=https://g7gfk9r42r-blip.github.io/sheap`

Remote paths:
- `API_BASE_URL/media/prospekte/<market>/<market>_recipes.json`
- image paths can be `media/recipe_images/<market>/R###.png`

### Weekly update procedure
1) Replace inputs:
   - `weekly_raw/<market>.txt` (12 markets)
   - optional: `weekly_raw/lidl.pdf`
2) Run:

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."
export REPLICATE_API_TOKEN="..."
python3 tools/weekly_pro.py --image-backend replicate --strict --publish-server
```

3) Deploy `server/media/` to your hosting so it is reachable under `/media/...` on your `API_BASE_URL`.

## 2) Android (Play Store)

### Release signing (required)
Create `android/key.properties` (NOT committed):

```
storeFile=/absolute/path/to/keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Build:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://g7gfk9r42r-blip.github.io/sheap
```

## 3) iOS (App Store)

Build (no codesign for CI sanity):

```bash
flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://g7gfk9r42r-blip.github.io/sheap
```

For an IPA you need signing via Apple Developer account in Xcode.

## 4) Icons + Splash

Configured via:
- `flutter_launcher_icons`
- `flutter_native_splash`

Run (when dependencies are installed):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

TODO: Replace placeholder icon/splash with final 1024x1024 assets.


