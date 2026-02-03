## Firebase Runbook (roman_app)

Projektpfad: `/Users/romw24/dev/AppProjektRoman/roman_app`

### 1) Quick Checks (Dateien)
- **Android**: `android/app/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist`

### 2) iOS Plist Key Check (CONFIGURATION_NOT_FOUND / 17999)
Wenn `CLIENT_ID` / `REVERSED_CLIENT_ID` fehlen, ist die Plist sehr wahrscheinlich **falsch/unvollständig** → führt oft zu:
`FIRAuthErrorDomain Code=17999 CONFIGURATION_NOT_FOUND (HTTP 400)`.

```bash
plutil -p ios/Runner/GoogleService-Info.plist | grep -E "CLIENT_ID|REVERSED_CLIENT_ID|GOOGLE_APP_ID|BUNDLE_ID|PROJECT_ID"
```

Erwartung:
- `BUNDLE_ID` muss exakt dem Xcode Bundle Identifier entsprechen.
- `CLIENT_ID` und `REVERSED_CLIENT_ID` sollten vorhanden sein.

### 3) Android JSON Check
```bash
cat android/app/google-services.json | head
grep -E "\"project_id\"|\"mobilesdk_app_id\"|\"package_name\"" -n android/app/google-services.json
```

Erwartung:
- `package_name` == `applicationId` aus `android/app/build.gradle.kts`

### 4) Clean Build Reihenfolge (wichtig)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
flutter clean
flutter pub get
```

#### iOS Pods (full reset)
```bash
rm -rf ios/Pods ios/Podfile.lock
cd ios
pod deintegrate || true
pod install --repo-update
cd ..
```

Dann:
```bash
flutter run -d "iPhone 16e"
```

### 5) Wenn Podfile Fehler: `Generated.xcconfig must exist`
Fix:
1. `flutter pub get`
2. dann `cd ios && pod install --repo-update`

### 6) CocoaPods “base configuration … custom config set” Warning (Hinweis)
Das passiert, wenn Runner nicht die Pods `.xcconfig` inkludiert.
In diesem Repo sollten `ios/Flutter/Debug.xcconfig` und `ios/Flutter/Release.xcconfig` folgendes enthalten:

- `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"`
- `#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"`

Wenn das fehlt: am Ende der jeweiligen `.xcconfig` ergänzen und Pods neu installieren.


