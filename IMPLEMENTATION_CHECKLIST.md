# ✅ Implementierungs-Checklist: Wöchentliche Rezepte ohne App-Update

## 🎯 Ziel
Die App soll **automatisch** jede Woche neue Rezepte + Bilder vom Server laden, **ohne dass ein App-Update nötig ist**.

---

## Phase 1️⃣: Überprüfung (5 Minuten)

- [ ] **Überprüfe vorhandene Struktur:**
  ```bash
  ls -la /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/
  # Sollte leer sein oder alte Rezepte enthalten
  ```

- [ ] **weekly_pro.py existiert?**
  ```bash
  ls /Users/romw24/dev/AppProjektRoman/roman_app/tools/weekly_pro.py
  ```

- [ ] **supermarket_recipe_repository.dart existiert?**
  ```bash
  ls /Users/romw24/dev/AppProjektRoman/roman_app/lib/data/services/supermarket_recipe_repository.dart
  ```

---

## Phase 2️⃣: Backend-Setup (10 Minuten)

- [ ] **Ordnerstruktur erstellen:**
  ```bash
  cd /Users/romw24/dev/AppProjektRoman/roman_app
  mkdir -p server/media/prospekte
  mkdir -p server/media/recipe_images
  echo "✅ Ordner erstellt"
  ```

- [ ] **Test: weekly_pro.py mit --publish-server Flag:**
  ```bash
  cd /Users/romw24/dev/AppProjektRoman/roman_app
  
  # Nutze existierende weekly_raw Daten oder Mock-Daten:
  python3 tools/weekly_pro.py \
    --image-backend none \
    --publish-server \
    --week "2026-W05"
  
  # Überprüfen:
  ls -la server/media/prospekte/
  # Sollte mindestens 1 Markt mit Rezepten anzeigen
  ```

- [ ] **Überprüfe das Ergebnis:**
  ```bash
  # Mindestens eine Datei sollte existieren:
  cat server/media/prospekte/lidl/lidl_recipes.json | head -50
  
  # Sollte JSON sein mit:
  # - "id": "R001"
  # - "image_path": "media/recipe_images/lidl/R001.png"
  ```

---

## Phase 3️⃣: App-Integration (15 Minuten)

### Überprüfe App-Code:

- [ ] **supermarket_recipe_repository.dart prüfen:**
  ```bash
  grep -n "basePath" \
    /Users/romw24/dev/AppProjektRoman/roman_app/lib/data/services/supermarket_recipe_repository.dart
  
  # Sollte zeigen:
  # - Es gibt einen static String get basePath { ... }
  # - Der verweist auf ${API_BASE_URL}/media/prospekte
  ```

- [ ] **Discover-Screen nutzt SupermarketRecipeRepository?**
  ```bash
  grep -n "SupermarketRecipeRepository" \
    /Users/romw24/dev/AppProjektRoman/roman_app/lib/features/discover/presentation/discover_screen.dart
  
  # Sollte mindestens 1 Hit haben
  ```

- [ ] **App-Caching-Logik überprüfen:**
  ```bash
  grep -n "_cachePrefix\|_cacheWeekKey" \
    /Users/romw24/dev/AppProjektRoman/roman_app/lib/data/services/supermarket_recipe_repository.dart
  
  # Sollte zeigen:
  # - Pro-Woche Caching wird verwendet
  ```

---

## Phase 4️⃣: Lokales Testing (20 Minuten)

### Terminal 1: Server starten
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/media
python3 -m http.server 3000

# Überprüfen:
# http://localhost:3000/prospekte/lidl/lidl_recipes.json sollte JSON zeigen
```

### Terminal 2: Flutter App starten
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Wichtig: API_BASE_URL setzen!
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000

# oder für Emulator:
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://localhost:3000
```

### Terminal 3: Logs überprüfen
```bash
# Während die App lädt:
tail -f /var/log/system.log | grep -i "recipe\|cache\|media"

# Oder in Flutter Debug Console anschauen:
# Sollte anzeigen:
# "✅ Loaded recipes from remote: http://localhost:3000/media/prospekte/..."
# "📦 Cached for week: 2026-W05"
```

- [ ] **App startet ohne Fehler?** ✅ / ❌
- [ ] **Rezepte werden geladen (>0 Rezepte)?** ✅ / ❌
- [ ] **Images sind sichtbar?** ✅ / ❌
- [ ] **Debug-Logs zeigen Cache-Info?** ✅ / ❌

---

## Phase 5️⃣: Production-Build (30 Minuten)

### iOS

- [ ] **Stelle sicher: API_BASE_URL für deinen echten Server:**
  ```bash
  # Ersetze mit deinem echten Server:
  MY_SERVER="https://your-grocify-server.com"
  
  flutter build ios --release \
    --dart-define=API_BASE_URL=$MY_SERVER \
    --verbose
  ```

- [ ] **Überprüfe Build-Erfolg:**
  ```bash
  ls build/ios/iphoneos/Runner.app/
  # Sollte die App-Binaries anzeigen
  ```

- [ ] **Optional: Zu Xcode öffnen für weitere Konfiguration:**
  ```bash
  open ios/Runner.xcworkspace
  # Product → Archive → Validate → Upload
  ```

### Android

- [ ] **App Bundle erstellen:**
  ```bash
  MY_SERVER="https://your-grocify-server.com"
  
  flutter build appbundle --release \
    --dart-define=API_BASE_URL=$MY_SERVER \
    --verbose
  ```

- [ ] **Überprüfe Build-Erfolg:**
  ```bash
  ls build/app/outputs/bundle/release/
  # Sollte app-release.aab enthalten
  ```

---

## Phase 6️⃣: Server-Deployment (Variiert)

### Option A: Vercel (empfohlen - automatisch)
```bash
# Verel detectet automatically server/ Ordner
cd /Users/romw24/dev/AppProjektRoman/roman_app
git add server/media/
git commit -m "Initial server media setup"
git push

# Vercel buildet + deployed automatisch
# → https://your-app.vercel.app/media/prospekte/lidl/...
```

- [ ] **Vercel-Projekt konfiguriert?**
- [ ] **API_BASE_URL in Vercel Environment gesetzt?**
- [ ] **Media-Ordner wird gepusht?**

### Option B: Statischer Server (z.B. AWS S3, CloudFlare)
```bash
# Kopiere server/media/ dorthin
aws s3 sync server/media/ s3://my-bucket/media/

# API_BASE_URL = "https://my-bucket.s3.amazonaws.com"
```

- [ ] **Server/Bucket ist public?**
- [ ] **CORS aktiviert?** (wenn nötig)
- [ ] **HTTPS aktiviert?** ✅

### Option C: Eigener Server (Nginx, Apache)
```bash
# Kopiere zu /var/www/html/media/
rsync -avz server/media/ root@your-server:/var/www/html/media/

# API_BASE_URL = "https://your-server.com"
```

- [ ] **SSH-Zugang funktioniert?**
- [ ] **Rezepte sind öffentlich erreichbar?**

---

## Phase 7️⃣: Wöchentliche Automation (5 Minuten - einmalig)

### weekly_deploy.sh erstellen
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

cat > weekly_deploy.sh << 'EOF'
#!/bin/bash
set -e
cd "$(dirname "$0")"

if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ OPENAI_API_KEY nicht gesetzt!"
  exit 1
fi

WEEK=$(python3 -c "from datetime import datetime; print(datetime.now().strftime('%Y-W%V'))")
echo "📅 Generiere Rezepte für Woche: $WEEK"

python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server

git add server/media/ build_logs/
git commit -m "Weekly recipes: $WEEK" || true
git push

echo "✅ Wöchentliche Rezepte deployed!"
EOF

chmod +x weekly_deploy.sh
```

- [ ] **Script ist ausführbar?**
  ```bash
  ls -la weekly_deploy.sh
  # Sollte x-Permission haben
  ```

---

## Phase 8️⃣: Finale Tests vor Production (15 Minuten)

### Test 1: Frische Rezepte laden
```bash
# Auf Simulator/Device:
# - App starten
# - Zu "Rezepte" / "Entdecken" gehen
# - Scrolle runter
# - Neue Rezepte sollten sichtbar sein

# ✅ / ❌
```

### Test 2: Cache funktioniert
```bash
# - App schließen und wieder öffnen
# - Rezepte sollten sofort laden (aus Cache)
# - Keine Netzwerk-Anfrage mehr für die Woche

# ✅ / ❌
```

### Test 3: Images laden
```bash
# - Überprüfe dass Rezept-Bilder angezeigt werden
# - Nicht nur Placeholder

# ✅ / ❌
```

### Test 4: Fallback bei Server-Offline
```bash
# - App in Flugzeugmodus schalten
# - App neustarten
# - App sollte immer noch alte Rezepte anzeigen

# ✅ / ❌
```

---

## Phase 9️⃣: Production Launch (Variiert)

### iOS App Store

- [ ] **Zu App Store Connect hochladen:**
  - Xcode → Product → Archive
  - Organizer → Distribute App
  - Method: "App Store Connect"

- [ ] **Verpackung und Signieren:**
  - Team ID korrekt?
  - Provisioning Profile aktuell?

- [ ] **Test Flight für interne Tests:**
  ```bash
  # Erst zu TestFlight hochladen zum Testen
  # https://testflight.apple.com
  ```

- [ ] **Zu App Store einreichen:**
  - Screenshots aktualisiert?
  - Release Notes hinzufügen?
  - "Automatic Release" oder manuell?

### Google Play Store

- [ ] **Release Management:**
  ```bash
  # https://play.google.com/console
  # Uploads → Create new release
  # Select app-release.aab
  ```

- [ ] **Staging/Testing:**
  - Zu "Internal Testing" zuerst?
  - Beta-Testing aktivieren?

- [ ] **Production Release:**
  - "Review and release" → "Confirm release"

---

## Phase 🔟: Nach Launch (Wöchentliche Routine)

### Jeden Montag:

- [ ] **Rezepte generieren:**
  ```bash
  export OPENAI_API_KEY="sk-..."
  export REPLICATE_API_TOKEN="..."
  
  cd /Users/romw24/dev/AppProjektRoman/roman_app
  ./weekly_deploy.sh
  ```

- [ ] **Überprüfen dass deployed wurde:**
  ```bash
  curl https://your-server.com/media/prospekte/lidl/lidl_recipes.json \
    | jq '.recipes[0]'
  
  # Sollte neue Rezepte zeigen
  ```

- [ ] **Optional: Nutzer-Feedback überprüfen:**
  - App Store Reviews
  - Play Store Ratings
  - Analytics (neue Rezepte werden geladen?)

---

## Troubleshooting

### Problem: "API_BASE_URL is not set"
```
Lösung:
flutter run --dart-define=API_BASE_URL=http://localhost:3000
flutter build ios --dart-define=API_BASE_URL=https://your-server.com
```

### Problem: App lädt alte Rezepte
```
Lösung:
1. Cache löschen:
   App → Settings → Clear Cache
   oder: flutter clean

2. Forcerefresh setzen:
   Ändere in supermarket_recipe_repository.dart:
   forceRefresh = true
```

### Problem: Images laden nicht
```
Lösung:
1. Überprüfe dass server/media/recipe_images/<market>/ nicht leer ist
2. Überprüfe dass image_path im JSON korrekt ist:
   "image_path": "media/recipe_images/lidl/R001.png"
3. Test mit curl:
   curl https://your-server.com/media/recipe_images/lidl/R001.png \
     -H "Content-Type: image/png" \
     > /tmp/test.png && file /tmp/test.png
```

---

## ✅ Completion Checklist

Am Ende sollten alle ✅ sein:

- [ ] Backend-Setup (server/media/)
- [ ] weekly_pro.py mit --publish-server funktioniert
- [ ] Flutter App mit API_BASE_URL buildet
- [ ] Lokales Testing erfolgreich
- [ ] iOS App Store Upload vorbereitet
- [ ] Android Play Store Upload vorbereitet
- [ ] Server/Media wird gepusht bei jedem Deploy
- [ ] weekly_deploy.sh erstellt und getestet
- [ ] Erste Production-Rezepte deployed
- [ ] Nutzer können neue Rezepte laden

---

## 🎉 Du bist fertig!

**Ab jetzt:** Jede Woche `./weekly_deploy.sh` → Nutzer sehen neue Rezepte automatisch (kein App-Update nötig!)

**Viel Erfolg! 🚀**
