# Build-Konfigurations-Snippets

## iOS App Store Build

```bash
# Pro-Tipp: API_BASE_URL setzen für Remote-Rezepte
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-grocify-server.com \
  --dart-define=API_BASE_URL_FALLBACK=https://cdn.your-domain.com

# Optional: Mit Code-Signing
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-grocify-server.com \
  --codesign \
  --verbose
```

## Android Play Store Build

```bash
flutter build appbundle \
  --dart-define=API_BASE_URL=https://your-grocify-server.com \
  --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

## Web-Build (für interne Tests)

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://your-grocify-server.com \
  --base-href="/grocify/"

# Deploy zu Vercel:
vercel deploy --prod build/web
```

## GitHub Actions Workflow

Erstelle `.github/workflows/build-and-deploy.yml`:

```yaml
name: Build & Deploy

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.2'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build iOS
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
        run: |
          flutter build ios --release \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }}
      
      - name: Build Android
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
        run: |
          flutter build appbundle --release \
            --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }}
      
      - name: Upload to TestFlight
        # Verwende fastlane oder dein CI/CD Tool
        run: |
          fastlane ios beta \
            --api_key_path "${{ secrets.APP_STORE_CONNECT_KEY }}"
      
      - name: Upload to Play Store
        # Verwende fastlane oder dein CI/CD Tool
        run: |
          fastlane android beta \
            --json_key "${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}"
```

### Secrets zu GitHub Actions hinzufügen:
```bash
# Settings → Secrets → New repository secret
API_BASE_URL = "https://your-grocify-server.com"
APP_STORE_CONNECT_KEY = <dein_p8_key>
GOOGLE_PLAY_SERVICE_ACCOUNT = <dein_json_key>
```

## Development Environment

### .env (local development)
```
API_BASE_URL=http://localhost:3000
FLUTTER_ENV=development
```

### .env.production (vor App Store Upload)
```
API_BASE_URL=https://your-domain.com
FLUTTER_ENV=production
```

### Verwendung in Flutter:
```dart
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000'  // Dev-Default
);

// In Release-Build MUSS API_BASE_URL gesetzt sein!
```

## Build-Größe Optimierung

```bash
# APK-Größe überprüfen
flutter build apk --release --analyze-size

# iOS-Größe (Xcode):
flutter build ios --release
# Xcode: Product → Build Folder

# Web-Größe
flutter build web --release
# Output in: build/web
```

## Troubleshooting Build-Fehler

### "API_BASE_URL not set" Error

```dart
// Überprüfe in supermarket_recipe_repository.dart:
// static String get basePath { ... }

// Fix:
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

### iOS Build fehlgeschlagen

```bash
# Clean + Rebuild
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
flutter build ios --release --verbose
```

### Android Build fehlgeschlagen

```bash
# Gradle-Cache clearen
rm -rf build
flutter clean
flutter build appbundle --release --verbose
```
