# Ohne App-Update (wöchentliche Rezepte): Wie es wirklich funktioniert

## Kurzfassung
- **Assets in der App** (`assets/...`) kannst du **nicht** nachträglich austauschen → dafür bräuchtest du jedes Mal ein App-Update.
- **Ohne App-Update** geht nur, wenn die App Rezepte/Bilder **remote** lädt (HTTP/CDN) und lokal cached.

## Was du schon im Code hast
Es existiert bereits ein HTTP-Loader mit Wochen-Cache:
- `lib/data/services/supermarket_recipe_repository.dart`

Der lädt (wenn verfügbar) von:
- `API_BASE_URL/media/prospekte/<market>/<file>.json`

und cached pro ISO-Woche.

## Empfohlener “Pro” Ansatz
1) **Einmaliges** App-Update:
   - App stellt (prod) `API_BASE_URL` auf deinen Server/CDN.
   - App nutzt remote-first loading (HTTP) + fallback auf Assets.
2) Ab dann **jede Woche**:
   - `python3 tools/weekly_pro.py ... --publish-server` generiert neue JSONs + Bilder **und** kopiert sie nach `server/media/`.
   - Du deployest nur den Ordner `server/media/` auf deinen Server unter `/media/...`.
   - Nutzer bekommen beim App-Start automatisch die neuen Rezepte (ohne Store-Update).


