# 🚀 Setup: Wöchentliche Rezepte OHNE App-Update

## Problem
Du generierst wöchentlich Rezepte + Bilder mit `weekly_pro.py`, aber jedes Mal ein App-Update in Play Store/App Store zu machen ist ineffizient.

## Lösung: Remote Content + Caching
Die App soll:
1. **Beim App-Start** den Server abfragen, ob neue Rezepte für diese Woche existieren
2. **Automatisch laden** ohne App-Update
3. **Lokal cachen** pro Woche
4. **Fallback** auf Asset-Rezepte, wenn Server offline

---

## 1️⃣ Backend-Setup (einmalig)

### 1.1 Server strukturieren
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
mkdir -p server/media/prospekte
mkdir -p server/media/recipe_images
```

Die `weekly_pro.py` wird dann automatisch hier hin kopieren wenn du `--publish-server` nutzt.

### 1.2 Server-Ordnerstruktur überprüfen
```bash
ls -la server/media/prospekte/
# Sollte anzeigen:
# aldi_sued/aldi_sued_recipes.json
# lidl/lidl_recipes.json
# rewe/rewe_recipes.json
# etc.

ls -la server/media/recipe_images/
# Sollte anzeigen:
# aldi_sued/R001.png, R002.png...
# lidl/R001.png, R002.png...
# etc.
```

---

## 2️⃣ Wöchentlicher Prozess

### 2.1 Dein aktueller Befehl
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."
export REPLICATE_API_TOKEN="..."

# FÜGE DIESE FLAG HINZU:
python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server    # ← DIESE ZEILE
```

**Was `--publish-server` macht:**
- Generiert die Rezepte und Bilder (wie bisher)
- **Kopiert sie automatisch** nach `server/media/prospekte/<market>/`
- Reschreibt `image_path` in den JSONs auf `media/recipe_images/<market>/<R###>.png`

### 2.2 Report überprüfen
```bash
# Nach dem Lauf:
cat build_logs/weekly_pro_report_*.json | jq '.results[] | {published_ok, weekly_refresh_ok}'

# Soll anzeigen:
# "published_ok": true
# "weekly_refresh_ok": true
```

---

## 3️⃣ App-Setup (EINMALIGES Update nötig)

### 3.1 Dart-Umgebung für Production
**Vor dem App-Store/Play-Store Upload:**

```bash
# DEVELOPMENT (lokal testen mit localhost)
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000 \
  -d chrome

# PRODUCTION (für App Store / Play Store)
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-server.com  # ← setzen!

flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-server.com
```

⚠️ **Wichtig:** `API_BASE_URL` muss dort zeigen, wo du `server/media/` later deployst!

### 3.2 Wo kommt `API_BASE_URL` hin?
Die App benutzt automatisch:
```
${API_BASE_URL}/media/prospekte/<market>/<market>_recipes.json
${API_BASE_URL}/media/recipe_images/<market>/<R###>.png
```

Beispiel:
- `API_BASE_URL=https://grocify.example.com`
- App lädt: `https://grocify.example.com/media/prospekte/lidl/lidl_recipes.json`

---

## 4️⃣ Server deployen

### Option A: Dein aktueller Server (Node.js/Express)
```bash
# Rezepte/Bilder sind bereits im Repo
ls server/media/prospekte/lidl/lidl_recipes.json
ls server/media/recipe_images/lidl/

# Deploy auf Vercel/deinen Server:
git add server/media/
git commit -m "Weekly recipes for W05"
git push
```

### Option B: Statischer Server (empfohlen für CDN)
Falls du nur Dateien servieren möchtest, ohne den Node.js Server zu starten:

```bash
# Einfacher HTTP-Server (Python)
cd server/media
python3 -m http.server 3000

# Dann: API_BASE_URL=http://localhost:3000
```

---

## 5️⃣ Testing lokal

### 5.1 Dev-Server starten
```bash
# Terminal 1: Node.js Server
cd server
npm run dev
# oder für Media-only:
cd server/media && python3 -m http.server 3000

# Terminal 2: Flutter App
cd /Users/romw24/dev/AppProjektRoman/roman_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

### 5.2 Überprüfen ob App lädt
1. App starten
2. Zu "Entdecken" / "Rezepte" gehen
3. Debug-Console anschauen:
```
✅ Loaded recipes from remote: http://localhost:3000/media/prospekte/lidl/lidl_recipes.json
📦 Cached for week: 2026-W05
```

---

## 6️⃣ Debugging

### Problem: App lädt alte Rezepte
**Ursache:** Cache ist noch gültig (nur 1x pro Woche aktualisiert)

**Lösung (dev):**
```dart
// In supermarket_recipe_repository.dart
static Future<Map<String, List<Recipe>>> loadAllSupermarketRecipes({
  bool forceRefresh = true,  // ← setzen für dev
```

oder manuell clearen:
```bash
# Simulatoren-Daten löschen
flutter clean
```

### Problem: "API_BASE_URL is not set"
**Lösung:**
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

### Problem: Images laden nicht
**Überprüfe:**
1. `server/media/recipe_images/<market>/R###.png` existiert?
2. `image_path` im JSON ist korrekt: `media/recipe_images/lidl/R001.png`?
3. Server antwortet auf `GET /media/recipe_images/lidl/R001.png`?

```bash
# Testen:
curl http://localhost:3000/media/recipe_images/lidl/R001.png \
  -H "Content-Type: image/png" \
  > /tmp/test.png && file /tmp/test.png
```

---

## 7️⃣ Production Checklist

- [ ] `flutter build ios --dart-define=API_BASE_URL=https://your-domain.com`
- [ ] `flutter build apk --dart-define=API_BASE_URL=https://your-domain.com`
- [ ] `server/media/` liegt auf deinem Server unter `https://your-domain.com/media/`
- [ ] HTTP-Response-Header korrekt: `Content-Type: application/json` & `Content-Type: image/png`
- [ ] CORS aktiviert (wenn nötig): `Access-Control-Allow-Origin: *`
- [ ] Wöchentlich: `python3 weekly_pro.py --publish-server && git push`
- [ ] Nutzer bekommen neue Rezepte **automatisch** beim nächsten App-Start (Montag)

---

## 8️⃣ Wie das Caching funktioniert

```dart
// supermarket_recipe_repository.dart
static const String _cachePrefix = 'supermarket_recipes_cache_v3_';
static const String _cacheWeekKey = 'supermarket_recipes_cache_week_v3';

// Wochenlogik:
1. App startet → currentWeekKey = isoWeekKey(DateTime.now())  // z.B. "2026-W05"
2. Prüft: SharedPreferences["supermarket_recipes_cache_week_v3"] == "2026-W05"?
3. Wenn gleiche Woche → nutze Cache
4. Wenn neue Woche → HTTP-Request, dann cache neu + store week
```

**Ergebnis:**
- **Montag (neue Woche):** Nutzer aktualisieren beim App-Start → neue Rezepte laden
- **Di-So (gleiche Woche):** Nutzer sehen gecachte Rezepte (schnell, offline OK)
- **Nächster Montag:** Zyklus wiederholt

---

## 9️⃣ Fallback auf App-Assets

Falls Server offline ist, nutzt die App die alten Rezepte aus `assets/recipes/`:
```dart
// Im Code:
try {
  recipes = await loadFromRemote(url)
} catch (e) {
  debugPrint("Server offline, using app assets instead")
  recipes = await loadFromAssets()  // Fallback
}
```

Das heißt: **Die App funktioniert immer**, ältere Rezepte sind als Fallback vorhanden.

---

## TL;DR

```bash
# Jede Woche:
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."
export REPLICATE_API_TOKEN="..."

# Wichtig: --publish-server Flag hinzufügen
python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server

# Pushen
git add server/media/
git commit -m "Weekly recipes $(date +%Y-W%V)"
git push

# Fertig! ✅
# Nutzer bekommen neue Rezepte automatisch beim App-Start.
```
