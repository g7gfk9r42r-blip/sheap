# Weekly Recipe Image Pipeline – Replica – Offline Ready

## Übersicht

Vollautomatische Weekly-Pipeline für Rezept-Bilder über Replica API.

**WICHTIG:** Keine Rezepte werden erfunden, ergänzt oder entfernt. Output = exakt Input.

## Setup

### 1. Dependencies installieren

```bash
pip3 install -r tools/requirements.txt
```

### 2. Replica API Key setzen

```bash
export REPLICA_API_KEY="r8_..."
```

Oder in `.env` Datei:
```
REPLICA_API_KEY=r8_...
```

**API Key erhalten:** https://replicate.com/account/api-tokens

## Verwendung

### Basis-Kommando (mit Strict Mode)

```bash
python3 tools/weekly_refresh_replica.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replica \
  --strict
```

### Dry-Run (Test ohne Writes)

```bash
python3 tools/weekly_refresh_replica.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replica \
  --dry-run \
  --strict
```

### Nur bestimmte Markets

```bash
python3 tools/weekly_refresh_replica.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replica \
  --only aldi_nord,aldi_sued \
  --strict
```

### Bilder neu generieren

```bash
python3 tools/weekly_refresh_replica.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replica \
  --force-images \
  --strict
```

## Output-Struktur

Nach dem Run:

```
assets/
├── recipes/
│   ├── aldi_nord_recipes.json      # Aktualisiert mit image_path
│   ├── aldi_sued_recipes.json
│   └── ...
└── images/
    └── recipes/
        ├── aldi_nord/
        │   ├── R001.webp
        │   ├── R002.webp
        │   └── ...
        └── aldi_sued/
            ├── R001.webp
            └── ...
```

## Strict Mode

Mit `--strict`:
- ✅ Abbruch bei doppelten IDs
- ✅ Abbruch bei ungültigen IDs (nicht R001-R999)
- ✅ Abbruch bei fehlenden Pflichtfeldern
- ✅ Abbruch wenn Output-Anzahl != Input-Anzahl

## Beispielausgabe

```
🔄 Weekly Recipe Refresh Pipeline - Replica (Offline-First)
============================================================

🔍 Entdecke Markets in assets/prospekte...
   ✅ aldi_nord      : assets/prospekte/aldi_nord/aldi_nord_recipes.json
   ✅ aldi_sued      : assets/prospekte/aldi_sued/aldi_sued_recipes.json

📁 2 Market(s) gefunden

📋 Verarbeite aldi_nord...
   Input: assets/prospekte/aldi_nord/aldi_nord_recipes.json
   📚 49 Rezepte geladen
   ✅ 49 valide Rezepte
   ✅ Bild generiert: R001
   ✅ Bild generiert: R002
   ...
   ✅ Gespeichert: aldi_nord_recipes.json (49 Rezepte)

============================================================
📊 REPORT
============================================================

✅ Markets verarbeitet: 2

📚 Rezepte pro Market:
   aldi_nord: geladen=49, valide=49, invalide=0, output=49
   aldi_sued: geladen=75, valide=75, invalide=0, output=75

🖼️  Bilder:
   Generiert: 124
   Übersprungen: 0
   Fehlgeschlagen: 0

💾 Dateien geschrieben: 2

============================================================
```

## Wichtige Regeln

1. **Keine Rezepte erfinden:** Output-Anzahl = exakt Input-Anzahl
2. **IDs nicht ändern:** Recipe IDs bleiben unverändert
3. **ID-Format:** Nur R001-R999 sind gültig
4. **Keine Duplikate:** Strict Mode prüft auf doppelte IDs
5. **Bilder:** Ein Bild pro Rezept, Format WEBP

## Troubleshooting

### "REPLICA_API_KEY environment variable is required"
→ Setze `export REPLICA_API_KEY="r8_..."`

### "Replica API nicht erreichbar"
→ Prüfe Internet-Verbindung und API Key

### "Prediction timeout"
→ Replica API kann bei hoher Last langsam sein. Retry automatisch.

### "PIL (Pillow) not installed"
→ `pip3 install Pillow`

## Kosten

Replica API kostet pro Bild. Prüfe Preise auf: https://replicate.com/pricing

Für viele Bilder: Nutze `--dry-run` erst, um zu sehen wie viele Bilder generiert werden.
