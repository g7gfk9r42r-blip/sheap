# 📱 Grocify: Wöchentliche Rezepte OHNE App-Update - Vollständige Lösung

## Das Problem
```
❌ Aktuell: Jede Woche → neue Rezepte + Bilder generieren → App-Code aktualisieren → Play Store/App Store Update
⏱️ Nachteil: ~3-7 Tage bis Nutzer Update erhalten + App-Review-Prozess
```

## Die Lösung
```
✅ Neu: Jede Woche → neue Rezepte + Bilder generieren → auf Server hochladen → App lädt automatisch
⚡ Vorteil: Nutzer sehen neue Rezepte sofort am nächsten Montag + kein App-Update nötig
```

---

## 🏗️ Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│                     Dein Laptop (Jeden Montag)                  │
├─────────────────────────────────────────────────────────────────┤
│  python3 tools/weekly_pro.py --publish-server                  │
│         ↓                                                         │
│  Generiert: out_recipes/<market>_recipes.json + images          │
│         ↓                                                         │
│  Kopiert zu: server/media/prospekte/<market>/                   │
│         ↓                                                         │
│  git push → GitHub/Vercel                                       │
└─────────────────────────────────────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│           Dein Server (https://your-domain.com)                 │
├─────────────────────────────────────────────────────────────────┤
│  /media/prospekte/lidl/lidl_recipes.json                        │
│  /media/recipe_images/lidl/R001.png, R002.png, ...              │
│                                                                   │
│  (Statisch serviert oder über Node.js/Express)                  │
└─────────────────────────────────────────────────────────────────┘
                                 ↑
                          (HTTP GET)
                                 │
                ┌────────────────┴────────────────┐
                │                                  │
        ┌───────▼────────┐           ┌────────────▼──────┐
        │  iOS App       │           │  Android App       │
        │  (App Store)   │           │  (Play Store)      │
        │                │           │                    │
        │ Beim Start:    │           │  Beim Start:       │
        │ - Frage Server │           │  - Frage Server    │
        │ - Cache neue   │           │  - Cache neue      │
        │   Rezepte      │           │    Rezepte         │
        └────────────────┘           └────────────────────┘
```

---

## 🔄 Wöchentlicher Workflow

### Montag, 09:00 Uhr
```bash
# 1. Auf deinem Laptop
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."
export REPLICATE_API_TOKEN="..."

# 2. Generiere + veröffentliche
./weekly_deploy.sh
# oder manuell:
python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server

# 3. Fertig!
```

### Montag, 10:00 Uhr (Nutzer-Perspektive)
```
1. Nutzer öffnet die App
2. App erkennt: "Neue Woche (W05), letzte cache war W04"
3. App fragt Server: "Hast du Rezepte für W05?"
4. Server antwortet: JA! (deine neuen Rezepte)
5. App downloaded + cached lokal
6. Nutzer sieht neue Rezepte! 🎉
```

---

## 📋 Setup-Checkliste

### ✅ Phase 1: Backend-Setup (einmalig)

- [ ] Ordnerstruktur erstellen:
  ```bash
  mkdir -p server/media/prospekte
  mkdir -p server/media/recipe_images
  ```

- [ ] `weekly_pro.py` mit `--publish-server` Flag testen:
  ```bash
  python3 tools/weekly_pro.py --publish-server --image-backend none
  ```

- [ ] Überprüfen, dass `server/media/` aktualisiert wurde

### ✅ Phase 2: App-Konfiguration (EINMALIGES Update)

- [ ] Flutter App mit `API_BASE_URL` builden:
  ```bash
  flutter build ios --release \
    --dart-define=API_BASE_URL=https://your-server.com
  
  flutter build apk --release \
    --dart-define=API_BASE_URL=https://your-server.com
  ```

- [ ] Zu App Store / Play Store uploaden

- [ ] **Nach diesem Upload:** Kein weiteres App-Update mehr nötig! 🎉

### ✅ Phase 3: Wöchentliche Automation

- [ ] Jede Woche:
  ```bash
  chmod +x weekly_deploy.sh
  ./weekly_deploy.sh
  ```

- [ ] Optional: GitHub Actions für automatische Uploads einrichten

---

## 🚀 Schnellstart (Copy-Paste)

### 1. Script erstellen
```bash
cat > /Users/romw24/dev/AppProjektRoman/roman_app/weekly_deploy.sh << 'EOF'
#!/bin/bash
set -e
cd /Users/romw24/dev/AppProjektRoman/roman_app

if [ -z "$OPENAI_API_KEY" ] || [ -z "$REPLICATE_API_TOKEN" ]; then
    echo "❌ OPENAI_API_KEY oder REPLICATE_API_TOKEN nicht gesetzt!"
    exit 1
fi

WEEK=$(python3 -c "from datetime import datetime; print(datetime.now().strftime('%Y-W%V'))")
echo "📅 Woche: $WEEK"

python3 tools/weekly_pro.py \
    --image-backend replicate \
    --strict \
    --publish-server

git add server/media/
git commit -m "Weekly recipes: $WEEK" || true
git push

echo "✅ Deployed!"
EOF

chmod +x weekly_deploy.sh
```

### 2. Erste Ausführung
```bash
export OPENAI_API_KEY="sk-xxx"
export REPLICATE_API_TOKEN="xxx"

./weekly_deploy.sh
```

### 3. Production-Build mit API_BASE_URL
```bash
# Für App Store / Play Store
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-domain.com

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-domain.com
```

---

## 🔍 Debugging

### App lädt alte Rezepte
```dart
// In supermarket_recipe_repository.dart, Zeile ~100:
static Future<Map<String, List<Recipe>>> loadAllSupermarketRecipes({
  bool forceRefresh = true,  // ← setzen für Dev
```

### "API_BASE_URL not set" Error
```bash
# Lösung:
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

### Server antwortet nicht
```bash
# Überprüfe:
curl https://your-domain.com/media/prospekte/lidl/lidl_recipes.json

# Sollte JSON zurückgeben, nicht HTML!
```

---

## 📊 Caching-Logik

```
Woche W04 → User lädt auf Dienstag → cached unter "W04"
  ↓
Jeden Tag Di-So: App nutzt Cache (schnell, offline OK)
  ↓
Montag nächste Woche → currentWeek = W05
  ↓
App erkennt: "Cache ist für W04, aber jetzt ist W05!"
  ↓
Macht HTTP-Request → neue Rezepte
  ↓
Cache aktualisiert unter "W05"
  ↓
Alle Di-So: nutzt neue W05-Rezepte
```

**Pro-Tipp:** Cache wird **pro ISO-Woche** erneuert, nicht täglich!

---

## 🛡️ Sicherheit & Best Practices

### 1. HTTPS verwenden
```bash
# Production MUSS HTTPS sein!
API_BASE_URL=https://your-domain.com  # ✅ Gut
API_BASE_URL=http://your-domain.com   # ❌ Nicht OK (Man-in-the-Middle)
```

### 2. CORS Headers setzen
```javascript
// server/index.js
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', 'https://your-domain.com');
  res.header('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.header('Cache-Control', 'public, max-age=604800');  // 1 Woche
  next();
});
```

### 3. Admin-Secret schützen
```bash
# weekly_pro.py darf nur du auf deinem Laptop ausführen!
# Nicht in CI/CD committen
echo "ADMIN_SECRET=..." >> .env
git add .gitignore  # Stelle sicher, dass .env ignoriert ist
```

---

## 📈 Skalierung

### Wenn deine App größer wird:

**Option 1: CDN verwenden** (schneller für globale Nutzer)
```bash
# Vercel CDN (auto)
git push → Vercel → automatisch global gecacht

# CloudFlare
# server/media/ auf CloudFlare Pages hosten
```

**Option 2: Mehrere Server-Regionen** (für Offline-Länder)
```bash
API_BASE_URL=https://eu.your-domain.com  # Europa
API_BASE_URL=https://asia.your-domain.com  # Asien
```

---

## ❓ FAQ

**F: Was passiert, wenn der Server offline ist?**
A: App nutzt automatisch die alten Asset-Rezepte als Fallback. Nutzer sehen nicht die neuesten Rezepte, aber die App funktioniert weiter.

**F: Wie oft checkt die App den Server?**
A: Nur 1x pro Woche (beim Wechsel zur neuen Woche). Danach 6 Tage offline OK.

**F: Kann ich manuell neue Rezepte laden?**
A: Ja, mit `forceRefresh=true` in der App. Oder: Nutzer kann Pull-to-Refresh verwenden.

**F: Muss ich Vercel verwenden?**
A: Nein! Jeder Server funktioniert. Vercel ist nur praktisch, weil Git-Push = Deploy.

**F: Was wenn ich die App offline machen möchte?**
A: Setze `API_BASE_URL=""` → App nutzt nur Asset-Rezepte.

---

## 🎯 Zusammenfassung

| Aspekt | Vorher ❌ | Nachher ✅ |
|--------|----------|----------|
| Update-Frequenz | 1x pro Monat | 1x pro Woche |
| Nutzer-Latenz | 3-7 Tage | < 1 Minute |
| App Store Review | Ja, jedes Mal | Nein, nur 1x |
| Rechenaufwand | Jedes Mal | 1x wöchentlich |
| Nutzer-Erlebnis | Statisch | Dynamisch, frisch |

---

## 📚 Weitere Ressourcen

- [WEEKLY_SERVER_SETUP.md](./WEEKLY_SERVER_SETUP.md) - Detailliertes Setup-Guide
- [BUILD_CONFIG.md](./BUILD_CONFIG.md) - Flutter Build-Konfiguration
- [tools/weekly_pro.py](./tools/weekly_pro.py) - Quellcode
- [lib/data/services/supermarket_recipe_repository.dart](./lib/data/services/supermarket_recipe_repository.dart) - App-Loader

---

**🎉 Viel Erfolg mit deinen wöchentlichen Rezepten!**
