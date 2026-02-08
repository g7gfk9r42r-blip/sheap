# 📊 Visuelle Diagramme: Wöchentliche Rezepte ohne App-Update

## 1. Gesamtarchitektur

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    🖥️  Dein Laptop (Jeden Montag)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  $ ./weekly_deploy.sh                                                   │
│         │                                                                │
│         ├─→ python3 tools/weekly_pro.py --publish-server               │
│         │        │                                                       │
│         │        ├─→ Liest: weekly_raw/<market>.txt                    │
│         │        ├─→ Generiert: out_recipes/<market>_recipes.json      │
│         │        ├─→ Erstellt: assets/images/recipes/<market>_R###.png │
│         │        └─→ Kopiert nach:                                      │
│         │              server/media/prospekte/<market>/                │
│         │              server/media/recipe_images/<market>/            │
│         │                                                                │
│         ├─→ git add server/media/                                      │
│         ├─→ git commit -m "Weekly recipes W05"                         │
│         └─→ git push origin main                                       │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                  🌐 GitHub / Vercel (Auto-Deploy)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  GitHub: repo pushed                                                    │
│         ↓                                                                │
│  Vercel: detectet server/media/ changes                                 │
│         ↓                                                                │
│  Auto-Deploy zu Vercel CDN                                             │
│         ↓                                                                │
│  https://your-domain.com/media/prospekte/lidl/lidl_recipes.json        │
│  https://your-domain.com/media/recipe_images/lidl/R001.png            │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
        ↑
        │ (HTTP GET)
        │
┌──────────────────────────┬──────────────────────────┐
│                          │                          │
└─→ ┌─────────────────────┐│┌─────────────────────────┐
    │  📱 iOS App         ││    📱 Android App       │
    │  (App Store)        ││    (Play Store)         │
    │                     ││                         │
    │ Beim App-Start:     ││ Beim App-Start:         │
    │ 1. currentWeek =    ││ 1. currentWeek =        │
    │    isoWeekKey()     ││    isoWeekKey()         │
    │ 2. lastCachedWeek = ││ 2. lastCachedWeek =     │
    │    SharedPrefs      ││    SharedPrefs          │
    │ 3. if different:    ││ 3. if different:        │
    │    HTTP GET         ││    HTTP GET             │
    │ 4. Cache lokal      ││ 4. Cache lokal          │
    │ 5. Nutzer sieht:    ││ 5. Nutzer sieht:        │
    │    Neue Rezepte!    ││    Neue Rezepte!        │
    │    🎉               ││    🎉                   │
    └─────────────────────┘└─────────────────────────┘
```

---

## 2. Wöchentlicher Wechsel (Cache-Logik)

```
MONTAG (1. Jan 2026 = Start der Woche 1):

App-Start Mo, 09:00:
  ┌────────────────────────────────────────────────┐
  │ currentWeek = isoWeekKey(DateTime.now())       │
  │           = "2026-W01"                         │
  │                                                │
  │ lastCachedWeek = SharedPrefs.get('cache_week')│
  │              = "2025-W52"  (alte Woche!)       │
  │                                                │
  │ Prüfung: "2026-W01" != "2025-W52"             │
  │         ↓ JA → Unterschiedlich!               │
  │                                                │
  │ HTTP GET: https://server.com/media/prospekte/ │
  │           lidl/lidl_recipes.json               │
  │                    ↓                           │
  │           Antwortet: {"recipes": [R001, R002]}│
  │                    ↓                           │
  │ Cache speichern: SharedPrefs['cache_week']    │
  │              = "2026-W01"                      │
  │                    ↓                           │
  │ Nutzer sieht neue Rezepte! 🎉               │
  └────────────────────────────────────────────────┘

DI-SO (gleiche Woche):

App-Start Di, 10:00:
  ┌────────────────────────────────────────────────┐
  │ currentWeek = "2026-W01"                       │
  │ lastCachedWeek = "2026-W01"  (gleich!)        │
  │                                                │
  │ Prüfung: "2026-W01" == "2026-W01"             │
  │         ↓ NEIN → Gleich!                      │
  │                                                │
  │ Nutze Cache (lokale JSON + Bilder)            │
  │ Kein HTTP-Request!                            │
  │ Sofort geladen! ⚡                            │
  │ Funktioniert offline! 🚀                      │
  └────────────────────────────────────────────────┘

NÄCHSTER MONTAG (8. Jan 2026 = Start der Woche 2):

App-Start Mo, 09:00:
  ┌────────────────────────────────────────────────┐
  │ currentWeek = isoWeekKey(DateTime.now())       │
  │           = "2026-W02"  (NEUE WOCHE!)         │
  │                                                │
  │ lastCachedWeek = "2026-W01"  (alte Woche)     │
  │                                                │
  │ Prüfung: "2026-W02" != "2026-W01"             │
  │         ↓ JA → Unterschiedlich!               │
  │                                                │
  │ → Gleicher Prozess wie Montag davor            │
  │ → NEUE Rezepte werden geladen 🎉              │
  └────────────────────────────────────────────────┘
```

---

## 3. Dateistruktur nach weekly_deploy.sh

```
Vor (nur Assets, statisch):
┌─ /Users/romw24/.../roman_app/
├─ assets/recipes/
│  └─ lidl/
│     └─ lidl_recipes.json  (alte Rezepte, in App)
└─ assets/images/
   └─ recipes/
      └─ lidl_R001.png  (alte Bilder, in App)


Nach `./weekly_deploy.sh` (neu auf Server):
┌─ /Users/romw24/.../roman_app/
├─ server/media/  ← NEU!
│  ├─ prospekte/
│  │  └─ lidl/
│  │     └─ lidl_recipes.json  ← aktuelle Rezepte
│  ├─ recipe_images/
│  │  └─ lidl/
│  │     ├─ R001.png  ← aktuelle Bilder
│  │     ├─ R002.png
│  │     └─ ...
│  │
│  └─ [wird zu GitHub gepusht]
│         ↓
│     [wird zu Vercel deployt]
│         ↓
│     https://your-domain.com/media/prospekte/lidl/...
│     https://your-domain.com/media/recipe_images/lidl/...

├─ assets/recipes/  ← FALLBACK (alte Rezepte)
│  └─ lidl/lidl_recipes.json  (nur für wenn Server offline)
└─ assets/images/  ← FALLBACK
   └─ recipes/lidl_R001.png  (nur wenn Server offline)
```

---

## 4. HTTP-Request Fluss

```
┌─ App startet
│   │
│   ├─→ isoWeekKey(DateTime.now())  = "2026-W05"
│   │
│   ├─→ SharedPrefs.get('cache_week')  = "2026-W04"
│   │
│   ├─→ "2026-W05" != "2026-W04"?
│   │         ↓ JA
│   │
│   ├─→ SupermarketRecipeRepository.loadAllSupermarketRecipes()
│   │   │
│   │   ├─→ Für jeden Markt (lidl, rewe, aldi_sued, ...):
│   │   │
│   │   ├─→ HTTP GET ${basePath}/<market>/<market>_recipes.json
│   │   │   │
│   │   │   │ basePath = ${API_BASE_URL}/media/prospekte
│   │   │   │
│   │   │   └─→ GET https://your-domain.com/media/prospekte/lidl/lidl_recipes.json
│   │   │        │
│   │   │        ├─ Response: 200 OK
│   │   │        │  Content: {"recipes": [...], "generated": "2026-01-06"}
│   │   │        │
│   │   │        └─ Parse JSON
│   │   │
│   │   ├─→ Für jedes Rezept:
│   │   │   │
│   │   │   ├─ Image-URL: ${API_BASE_URL}/media/recipe_images/<market>/<id>.png
│   │   │   │
│   │   │   └─→ GET https://your-domain.com/media/recipe_images/lidl/R001.png
│   │   │        │
│   │   │        └─ Speichern in App-Cache (SharedPreferences + File)
│   │   │
│   │   └─→ SharedPrefs.set('cache_week', "2026-W05")
│   │
│   └─→ Nutzer-Interface aktualisieren
│       └─→ Neue Rezepte anzeigen 🎉
│
└─ App läuft weiter (offline OK dank Cache)
```

---

## 5. Deployment-Pipeline mit GitHub Actions (optional)

```
Du kommst jeden Montag um 09:00:

Step 1: Lokal generieren
┌────────────────────────────────┐
│ $ ./weekly_deploy.sh           │
│                                │
│ Generiert Rezepte + Bilder    │
│ Pusht zu GitHub               │
└────────────────────────────────┘
        ↓
GitHub (dein Repo)
        ↓
Step 2: GitHub Actions Trigger
┌────────────────────────────────┐
│ on: [push] zu main branch      │
│                                │
│ Workflow startet automatisch   │
└────────────────────────────────┘
        ↓
Step 3: GitHub Actions Job
┌────────────────────────────────┐
│ Lädt Repo herunter             │
│ Überprüft Änderungen           │
│ (optional: Tests)              │
│ Benachrichtigt Vercel          │
└────────────────────────────────┘
        ↓
Vercel (Auto-Deployment)
        ↓
Step 4: Vercel Build + Deploy
┌────────────────────────────────┐
│ Detectet server/media/ changes │
│                                │
│ Buildet Server                 │
│ Deployed zu Global CDN         │
│                                │
│ ~2 Minuten später              │
│ Live auf Vercel! ✅            │
└────────────────────────────────┘
        ↓
📱 Nutzer bekommen Benachrichtigung
   (optional: via App Push)
        ↓
Step 5: Nächster Montag
┌────────────────────────────────┐
│ Nutzer öffnet App              │
│ Neue Woche erkannt             │
│ Neue Rezepte geladen! 🎉      │
└────────────────────────────────┘
```

---

## 6. Fehler-Handling & Fallback

```
Normal (Server erreichbar):
┌─────────────────────────┐
│ App → Server            │
│   ↓ HTTP 200 OK         │
│ Rezepte geladen         │
│ Cache aktualisiert      │
│ Nutzer sieht neue! ✅   │
└─────────────────────────┘

Fehlerfall 1 (Server offline):
┌─────────────────────────────────────────┐
│ App → Server                            │
│   ↓ Netzwerk-Fehler (timeout)           │
│ Catch exception                         │
│   ↓                                     │
│ Nutze alten Cache (falls vorhanden)    │
│   ↓                                     │
│ Wenn kein Cache: Assets laden           │
│   ↓                                     │
│ Nutzer sieht alte Rezepte (OK!) ✅     │
│ App funktioniert trotzdem!              │
└─────────────────────────────────────────┘

Fehlerfall 2 (Falsche API_BASE_URL):
┌─────────────────────────────────────┐
│ API_BASE_URL = ""  (nicht gesetzt)  │
│   ↓                                 │
│ basePath = ""                       │
│   ↓                                 │
│ HTTP GET "" → fehlt URL             │
│   ↓                                 │
│ _serverOffline = true               │
│   ↓ Debug-Nachricht:                │
│ "⚠️ API_BASE_URL is not set"        │
│   ↓                                 │
│ Nutze Assets direkt                 │
│   ↓                                 │
│ Nutzer sieht App, aber alte Rezepte │
└─────────────────────────────────────┘

Fehlerfall 3 (Neue Woche, aber server/media nicht updated):
┌──────────────────────────────────────┐
│ Montag, neue Woche W05               │
│ App fragt: /media/prospekte/.../W05  │
│   ↓                                  │
│ Server antwortet: 404 Not Found      │
│ (weekly_deploy.sh nicht ausgeführt!) │
│   ↓                                  │
│ Nutze alten Cache (W04)              │
│   ↓                                  │
│ ⚠️ Nutzer sieht alte Rezepte         │
│ (aber App läuft weiter!)             │
│                                      │
│ Fix: weekly_deploy.sh ausführen ✅  │
└──────────────────────────────────────┘
```

---

## 7. Größenvergleich: Assets vs. Remote

```
IN DER APP (assets/):
┌────────────────────────────────────┐
│ assets/recipes/                    │
│   ├─ lidl_recipes.json        1 MB │
│   ├─ rewe_recipes.json        0.8MB│
│   └─ ... (11 Märkte)         ~8 MB │
│                                    │
│ assets/images/recipes/             │
│   ├─ lidl_R001.png            50KB │
│   ├─ lidl_R002.png            50KB │
│   └─ ... (100+ Bilder)      ~5 MB  │
│                                    │
│ TOTAL: ~13 MB (binär in App)      │
│                                    │
│ Update bedeutet: Neue App-Binary!  │
│ Play Store/App Store Upload!       │
│ Nutzer-Download: nächste Tage     │
└────────────────────────────────────┘

REMOTE (server/media/):
┌────────────────────────────────────┐
│ server/media/prospekte/            │
│   ├─ lidl/lidl_recipes.json   1 MB │
│   ├─ rewe/rewe_recipes.json  0.8MB │
│   └─ ...                     ~8 MB │
│                                    │
│ server/media/recipe_images/        │
│   ├─ lidl/R001.png            50KB │
│   ├─ lidl/R002.png            50KB │
│   └─ ... (100+ Bilder)      ~5 MB  │
│                                    │
│ TOTAL: ~13 MB (aber remote!)      │
│                                    │
│ Update bedeutet: Nur Git Push!     │
│ Server-Deploy: < 2 Minuten        │
│ Nutzer erhält sofort (nächster     │
│ App-Start) - kein App-Update!      │
└────────────────────────────────────┘
```

---

## 8. Timeline: Montag bis Sonntag

```
MONTAG (Woche W05 startet):

09:00  ← Du führst ./weekly_deploy.sh aus
       │ 1. Rezepte generiert
       │ 2. Nach server/media/ kopiert
       │ 3. Git push
       │ ↓

09:05  ← Vercel detectet Changes
       │ Auto-Deploy startet
       │ ↓

09:10  ← Neue Rezepte live auf Server
       │ https://your-domain.com/media/...
       │ ↓

09:15  ← Erste Nutzer öffnen App
       │ App erkennt: Neue Woche!
       │ Lädt neue Rezepte
       │ Sieht neue Inhalte! 🎉
       │ ↓

10:00  ← Alle Nutzer haben neue Rezepte
       │ (wenn App offen war)
       │ ↓

DI-SO  ← Nutzer öffnen App
       │ App nutzt Cache
       │ Schnell! ⚡
       │ Offline OK! 🚀
       │ ↓

NÄCHSTER MONTAG
       └─ Zyklus wiederholt
          Neue Rezepte für W06
```

---

## 9. Kosten-Vergleich: Alt vs. Neu

```
ALT (mit App-Update):
┌──────────────────────────────────┐
│ Jede Woche:                      │
│                                  │
│ 1. Rezepte generieren       5min │
│ 2. In App-Assets integr.   10min │
│ 3. App-Build               15min │
│ 4. zu Store uploaden        5min │
│ 5. Review-Prozess       1-7 Tage │
│ 6. Nutzer downloads      1-2 Tage│
│                                  │
│ TOTAL: 1-2 Wochen bis User sehen│
│ Jedes Update = Risiko!          │
│ Jedes Update = Build-Fehler OK? │
│                                  │
│ Kosten: Zeit + Fehler-Risiko    │
└──────────────────────────────────┘

NEU (Remote Content):
┌──────────────────────────────────┐
│ Jede Woche:                      │
│                                  │
│ 1. Rezepte generieren       5min │
│ 2. ./weekly_deploy.sh           │
│    = Auto-Upload + Deploy    5min│
│ 3. Live auf Server         5 min │
│                                  │
│ TOTAL: 15 Minuten               │
│ Nutzer sehen sofort beim       │
│ nächsten App-Start (Montag!)   │
│                                  │
│ Kosten: Nur Zeit (minimal)      │
│ Fehler-Risiko: Sehr niedrig     │
│                                  │
│ EINMALIGES App-Update nötig:    │
│ 1x iOS App Store Upload         │
│ 1x Android Play Store Upload    │
│ (Dann nie mehr!)                │
└──────────────────────────────────┘

ERSPARNIS:
- Zeit: 50 Minuten / Woche sparen
- Fehler-Risiko: 99% weniger
- Nutzer-Erlebnis: Sofort statt 1-2 Wochen
```

---

Diese Diagramme helfen dir, das System zu visualisieren und anderen zu erklären!
