# 🚀 Quick Reference Card: Wöchentliche Rezepte

## TL;DR: Nur diese 3 Schritte!

### 🔧 Einmaliges Setup
```bash
mkdir -p /Users/romw24/dev/AppProjektRoman/roman_app/server/media/{prospekte,recipe_images}

flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-domain.com

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-domain.com
```

### 📅 Jede Woche (Montag, 09:00)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."
export REPLICATE_API_TOKEN="..."

python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server

git add server/media/
git commit -m "Weekly: $(date +%Y-W%V)"
git push
```

### ✅ Fertig!
Nutzer sehen neue Rezepte beim nächsten App-Start (kein App-Update nötig!)

---

## 🆘 Häufige Fehler

| Problem | Lösung |
|---------|--------|
| "API_BASE_URL not set" | `flutter run --dart-define=API_BASE_URL=http://localhost:3000` |
| App lädt alte Rezepte | `flutter clean` + App neu starten |
| Images anzeigen nicht | Überprüfe: `ls server/media/recipe_images/<market>/` nicht leer? |
| `weekly_pro.py` fehlt | `ls tools/weekly_pro.py` (Datei sollte existieren) |
| Git-Push schlägt fehl | `git status` → überprüfe unbekannte Änderungen |

---

## 📂 Wichtige Pfade

```
/Users/romw24/dev/AppProjektRoman/roman_app/
├─ tools/weekly_pro.py                    ← Rezept-Generator
├─ server/media/prospekte/                ← Neue Rezepte (Server)
├─ server/media/recipe_images/            ← Neue Bilder (Server)
├─ lib/data/services/supermarket_recipe_repository.dart  ← App-Loader
├─ WEEKLY_SERVER_SETUP.md                 ← Detailliertes Setup
├─ IMPLEMENTATION_CHECKLIST.md            ← Schritt-für-Schritt
└─ weekly_deploy.sh                       ← Automation Script
```

---

## 🔍 Debug-Befehle

```bash
# 1. Überprüfe ob weekly_pro.py funktioniert
python3 tools/weekly_pro.py --publish-server --image-backend none

# 2. Überprüfe ob Rezepte auf Server sind
curl https://your-domain.com/media/prospekte/lidl/lidl_recipes.json

# 3. Überprüfe ob Images vorhanden
ls -la server/media/recipe_images/lidl/ | wc -l

# 4. Überprüfe ob App lädt
flutter logs | grep -i "recipe\|cache\|media"

# 5. Überprüfe ob Cache funktioniert
grep -n "supermarket_recipes_cache" lib/data/services/supermarket_recipe_repository.dart
```

---

## 🌐 Server-URLs (für dein Setup)

```
API_BASE_URL = https://your-domain.com

Rezepte:
https://your-domain.com/media/prospekte/lidl/lidl_recipes.json
https://your-domain.com/media/prospekte/rewe/rewe_recipes.json
... (alle Märkte)

Images:
https://your-domain.com/media/recipe_images/lidl/R001.png
https://your-domain.com/media/recipe_images/lidl/R002.png
... (alle Bilder)
```

---

## 📱 App-Verhalten

```
┌─ App startet
│
├─ Berechne currentWeek (z.B. "2026-W05")
│
├─ Lese lastCachedWeek aus SharedPrefs
│
├─ Wenn unterschiedlich:
│  ├─ HTTP GET /media/prospekte/<market>_recipes.json
│  ├─ Speichere Cache für diese Woche
│  └─ Zeige neue Rezepte
│
└─ Wenn gleich:
   └─ Nutze Cache (schnell, offline OK)
```

---

## ⚙️ Umgebungsvariablen

```bash
# .env oder export vor weekly_pro.py:
export OPENAI_API_KEY="sk-proj-..."
export REPLICATE_API_TOKEN="..."
export API_BASE_URL="https://your-domain.com"  # Optional

# Für Flutter Build:
flutter build ios --dart-define=API_BASE_URL=https://your-domain.com
```

---

## 📊 Checklist vor Production

- [ ] `server/media/prospekte/` hat Rezepte?
- [ ] `server/media/recipe_images/` hat Bilder?
- [ ] `API_BASE_URL` ist richtig gesetzt?
- [ ] iOS App Store Upload mit `--dart-define=API_BASE_URL=...`?
- [ ] Android Play Store Upload mit `--dart-define=API_BASE_URL=...`?
- [ ] Erste Rezepte mit `./weekly_deploy.sh` deployed?
- [ ] App lädt remote Rezepte (Debug anschauen)?
- [ ] Cache funktioniert (2. App-Start zeigt Cache)?

---

## 🎯 Erfolgs-Kriterien

✅ = Alles OK

- [ ] ✅ `weekly_pro.py --publish-server` läuft ohne Fehler
- [ ] ✅ `server/media/` wird zu GitHub gepusht
- [ ] ✅ Vercel deployed automatisch (optional)
- [ ] ✅ `curl` auf Server-URL gibt JSON zurück
- [ ] ✅ App lädt Rezepte mit `API_BASE_URL`
- [ ] ✅ Images werden angezeigt
- [ ] ✅ Cache funktioniert (2x App öffnen = schneller)
- [ ] ✅ Offline-Modus funktioniert (Fallback zu Assets)
- [ ] ✅ Nutzer sehen neue Rezepte ohne App-Update 🎉

---

## 🚨 Emergency: Rezepte sind falsch

```bash
# 1. Überprüfe generated_at
curl https://your-domain.com/media/prospekte/lidl/lidl_recipes.json \
  | jq '.generated_at'

# 2. Wenn veraltet:
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 tools/weekly_pro.py --publish-server
git push

# 3. Vercel deployt automatisch (1-2 min)

# 4. User sehen sofort bei nächstem App-Start
```

---

## 📞 Support-Matrix

| Issue | Cause | Fix |
|-------|-------|-----|
| App lädt alte Rezepte | Cache-Week gleich | `flutter clean` |
| App crasht beim Laden | JSON-Parse-Fehler | Überprüfe JSON-Syntax |
| Images anzeigen nicht | image_path falsch | Überprüfe `server/media/recipe_images/` |
| Network-Timeout | Server offline | Nutze Fallback (lokale Assets) |
| weekly_pro.py crash | OPENAI_API_KEY fehlt | `export OPENAI_API_KEY=...` |
| Build-Fehler iOS | Deployment-Target | Überprüfe ios/Podfile |

---

## 🎓 Weitere Ressourcen

1. **Vollständiges Setup:** [WEEKLY_SERVER_SETUP.md](./WEEKLY_SERVER_SETUP.md)
2. **Checkliste:** [IMPLEMENTATION_CHECKLIST.md](./IMPLEMENTATION_CHECKLIST.md)
3. **Diagramme:** [DIAGRAMS_WEEKLY_RECIPES.md](./DIAGRAMS_WEEKLY_RECIPES.md)
4. **Build-Config:** [BUILD_CONFIG.md](./BUILD_CONFIG.md)
5. **Überblick:** [WEEKLY_RECIPES_SOLUTION.md](./WEEKLY_RECIPES_SOLUTION.md)

---

## 💡 Pro-Tipps

```bash
# 1. Alias für schnelle Deployment
alias weekly-deploy="cd /Users/romw24/dev/AppProjektRoman/roman_app && ./weekly_deploy.sh"

# 2. Automatischer Cron (Linux/Mac)
# Jede Woche Montag 09:00
# 0 9 * * 1 cd /path && ./weekly_deploy.sh

# 3. GitHub Actions für automatische CI/CD
# .github/workflows/weekly-recipes.yml

# 4. Vercel Preview URLs für QA
# Jeder Push = automatische Preview-URL

# 5. Sentry für Error-Tracking
# Fehler im App-Loading trackbar
```

---

**Viel Erfolg! 🚀**

*Letzte Aktualisierung: 2026-02-04*
