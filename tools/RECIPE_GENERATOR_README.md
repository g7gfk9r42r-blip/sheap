# Recipe Generator from Raw Prospekt Data

Automatische Generierung von 50-100 strukturierten Rezepten aus Prospekt-Rohdaten mittels LLM (OpenAI GPT-4).

## Überblick

Dieses Tool nimmt **unstrukturierten Text** aus Prospekten (z.B. OCR-Output, manuell kopierter Text) und generiert daraus:
- 50-100 vollständige Rezepte
- Strukturiert nach JSON-Schema
- Mit Zutaten-Matching zu Angeboten
- Inklusive Nährwertschätzungen
- Kategorisiert (Breakfast, Lunch, Dinner, Snack)
- Mit Kochanleitung

## Voraussetzungen

### Python-Pakete

```bash
pip install openai
```

### OpenAI API-Key

```bash
export OPENAI_API_KEY="sk-..."
```

Kosten pro Aufruf (abhängig vom Modell):
- **GPT-4o**: ~$0.50-1.50 pro Lauf (Input + Output ~50k tokens)
- **GPT-4-turbo**: ~$1-3 pro Lauf
- **GPT-3.5-turbo**: ~$0.10-0.30 pro Lauf (schneller, aber weniger qualitativ)

## Verwendung

### Basis-Beispiel

```bash
python tools/generate_recipes_from_raw.py \
  --input server/alle_angebote_komplett.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --output server/media/prospekte/aldi_nord/recipes_2025-W52.json
```

### Mit bereits geparsten Angeboten

Wenn Sie bereits strukturierte Angebote haben (z.B. aus `offers.json`):

```bash
python tools/generate_recipes_from_raw.py \
  --input server/alle_angebote_komplett.txt \
  --supermarket rewe \
  --week 2025-W52 \
  --known-offers server/offers.json \
  --output recipes_rewe.json
```

### Andere Modelle

```bash
# GPT-3.5 (schneller, günstiger)
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket edeka \
  --week 2025-W52 \
  --model gpt-3.5-turbo \
  --output recipes.json

# GPT-4-turbo (langsamer, teurer, bessere Qualität)
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket tegut \
  --week 2025-W52 \
  --model gpt-4-turbo \
  --output recipes.json
```

### Verbose-Modus

```bash
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket lidl \
  --week 2025-W52 \
  --verbose
```

## Input-Format

### Raw Text File

Die Input-Datei sollte Angebots-Text enthalten wie:

```
ALDI NORD - Aktionswoche KW 52

Hähnchen-Brustfilet
frisch, 1-kg-Packung
5.99 EUR (1 kg = 5.99)

Basmati Reis
Golden Sun, 1-kg-Beutel
versch. Sorten
1.99 EUR

Tomaten
Cherry, 500-g-Schale
0.99 EUR

Mozzarella
Italienischer, 125-g-Packung
0.79 EUR (100 g = 0.63)

...
```

### Known Offers JSON (Optional)

Wenn bereits geparste Angebote vorhanden:

```json
[
  {
    "offerId": "offer-001",
    "title": "Hähnchen-Brustfilet",
    "brand": null,
    "packaging": "1-kg-Packung",
    "price_now": 5.99,
    "category_guess": "Fleisch",
    "is_food": true
  },
  ...
]
```

## Output-Format

### Struktur

```json
{
  "supermarket": "aldi_nord",
  "weekKey": "2025-W52",
  "generated_at": "2025-12-22T12:00:00",
  "recipe_count": 75,
  "recipes": [
    {
      "id": "aldi_nord-2025-W52-001",
      "title": "Hähnchen-Reis-Bowl mit Tomaten",
      "description": "Proteinreiche Bowl mit zartem Hähnchen, Basmati-Reis, frischen Cherry-Tomaten und Mozzarella - perfekt für ein ausgewogenes Mittagessen.",
      "supermarket": "aldi_nord",
      "weekKey": "2025-W52",
      "category": "Lunch",
      "dietTags": ["high-protein", "balanced"],
      "servings": 2,
      "prepMinutes": 15,
      "cookMinutes": 25,
      "difficulty": "easy",
      "ingredients": [
        {
          "name": "Hähnchen-Brustfilet",
          "amount": 300,
          "unit": "g",
          "isPantry": false,
          "offerRef": "offer-001",
          "offerMatchNote": "ALDI Nord: Hähnchen-Brustfilet frisch 1kg"
        },
        {
          "name": "Basmati Reis",
          "amount": 150,
          "unit": "g",
          "isPantry": false,
          "offerRef": "offer-002",
          "offerMatchNote": "ALDI Nord: Golden Sun Basmati Reis 1kg"
        },
        {
          "name": "Cherry-Tomaten",
          "amount": 200,
          "unit": "g",
          "isPantry": false,
          "offerRef": "offer-003",
          "offerMatchNote": "ALDI Nord: Cherry Tomaten 500g"
        },
        {
          "name": "Mozzarella",
          "amount": 125,
          "unit": "g",
          "isPantry": false,
          "offerRef": "offer-004",
          "offerMatchNote": "ALDI Nord: Mozzarella italienisch 125g"
        },
        {
          "name": "Olivenöl",
          "amount": 2,
          "unit": "el",
          "isPantry": true,
          "offerRef": null,
          "offerMatchNote": null
        },
        {
          "name": "Salz & Pfeffer",
          "amount": 1,
          "unit": "tl",
          "isPantry": true,
          "offerRef": null,
          "offerMatchNote": null
        }
      ],
      "steps": [
        "Reis nach Packungsanweisung kochen (ca. 15 Minuten).",
        "Hähnchenbrust in mundgerechte Stücke schneiden und mit Salz und Pfeffer würzen.",
        "Olivenöl in einer Pfanne erhitzen und Hähnchen bei mittlerer Hitze ca. 8-10 Minuten braten bis es durchgegart ist.",
        "Cherry-Tomaten halbieren, Mozzarella in Scheiben schneiden.",
        "Reis in Bowls verteilen, Hähnchen, Tomaten und Mozzarella darauf anrichten. Mit etwas Olivenöl beträufeln."
      ],
      "offerBreakdown": [
        {
          "offerRef": "offer-001",
          "usedFor": "Protein-Komponente",
          "storeHint": "Kühltheke / Frisches Fleisch"
        },
        {
          "offerRef": "offer-002",
          "usedFor": "Kohlenhydrat-Basis",
          "storeHint": "Trockenware / Reis & Nudeln"
        },
        {
          "offerRef": "offer-003",
          "usedFor": "Gemüse-Komponente",
          "storeHint": "Obst & Gemüse Abteilung"
        },
        {
          "offerRef": "offer-004",
          "usedFor": "Topping",
          "storeHint": "Molkerei / Käse"
        }
      ],
      "nutrition": {
        "kcal_total": 1200,
        "kcal_per_serving": 600,
        "kcal_source": "estimated",
        "kcal_confidence": "medium"
      },
      "qualityChecks": {
        "minIngredientsOk": true,
        "nonFoodFiltered": true,
        "jsonValid": true
      }
    }
  ]
}
```

## Prompt-Engineering

### Prompt-Template anpassen

Das Prompt-Template liegt in `tools/recipe_generator_prompt.txt`. Sie können es anpassen für:

**Mehr/Weniger Rezepte:**
```
Genau 50–100 ausgewogene Rezepte
→ Genau 100–150 ausgewogene Rezepte
```

**Andere Kategorien:**
```
category: "Breakfast"|"Lunch"|"Dinner"|"Snack"
→ category: "Breakfast"|"Lunch"|"Dinner"|"Snack"|"Dessert"|"Appetizer"
```

**Strengere Kalorienvorgaben:**
```
Kalorien dürfen NICHT frei erfunden werden.
→ Kalorien MÜSSEN aus verlässlicher Quelle stammen. Wenn unsicher: Rezept überspringen.
```

**Deutsche Ausgabe:**
```
"difficulty": "easy"|"medium"|"hard"
→ "difficulty": "einfach"|"mittel"|"schwer"
```

## Qualitätskontrolle

### Automatische Validierung

Das Script validiert automatisch:
- ✅ JSON ist parsbar
- ✅ Mindestens 3 Zutaten pro Rezept
- ✅ Mindestens 4 Kochschritte
- ✅ Nährwerte vorhanden
- ✅ Supermarket/Week korrekt gesetzt

### Manuelle Review

Nach der Generierung sollten Sie prüfen:

```bash
# Anzahl Rezepte
jq '.recipe_count' recipes.json

# Kategorien-Verteilung
jq '[.recipes[].category] | group_by(.) | map({category: .[0], count: length})' recipes.json

# Rezepte ohne Offers
jq '[.recipes[] | select([.ingredients[] | select(.offerRef != null)] | length == 0)]' recipes.json

# Durchschnittliche Kalorien
jq '[.recipes[].nutrition.kcal_per_serving] | add / length' recipes.json
```

## Integration mit Nutrition Enrichment

Sie können die generierten Rezepte mit der Nutrition Pipeline anreichern:

```bash
# 1. Rezepte generieren
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --output recipes_raw.json

# 2. Mit echten Nährwerten anreichern
python tools/enrich_nutrition.py \
  --root . \
  --file recipes_raw.json

# Ergebnis: recipes_raw_nutrition.json mit echten API-Daten
```

## Troubleshooting

### "OpenAI API key required"

➜ API-Key fehlt:
```bash
export OPENAI_API_KEY="sk-..."
```

### "Too few recipes generated"

➜ Mögliche Ursachen:
- Input-Text zu kurz/wenig Angebote
- Model-Limit erreicht (max_tokens zu niedrig)
- Prompt-Template zu strikt

➜ Lösungen:
- `--max-tokens 20000` erhöhen
- Prompt-Template anpassen (Mindestanzahl runtersetzen)
- Input-Text mit mehr Angeboten füttern

### "JSON parse error"

➜ LLM hat kein valides JSON ausgegeben
- Häufig bei gpt-3.5-turbo (weniger zuverlässig)
- Lösung: `--model gpt-4o` verwenden
- Oder: Prompt-Template verschärfen ("Du darfst NIEMALS Text außerhalb des JSON ausgeben")

### Kosten zu hoch

➜ GPT-4 ist teuer
- Für Tests: `--model gpt-3.5-turbo` (10x günstiger)
- Für Produktion: Batch-Processing (mehrere Wochen gleichzeitig)
- Alternative: Lokale LLMs (Llama 3, Mistral) - siehe unten

## Alternative: Lokale LLMs

Wenn OpenAI-Kosten zu hoch:

### Option 1: Ollama (lokal)

```bash
# Installieren: https://ollama.ai
ollama pull llama3:70b

# Script anpassen für ollama-Endpunkt
# (erfordert Code-Modifikation in generate_recipes_from_raw.py)
```

### Option 2: Azure OpenAI

```bash
# Azure OpenAI API nutzen
export AZURE_OPENAI_ENDPOINT="..."
export AZURE_OPENAI_KEY="..."

# Script anpassen für Azure
# (erfordert Code-Modifikation)
```

## Performance

- **Input**: 5000 Zeichen Rohtext
- **GPT-4o**: ~30-60 Sekunden, ~$0.80
- **GPT-4-turbo**: ~60-120 Sekunden, ~$2
- **GPT-3.5-turbo**: ~15-30 Sekunden, ~$0.15

## Beispiel-Workflow

```bash
# Wöchentlicher Prospekt-Processing für ALDI Nord

# 1. Rohdaten extrahieren (existierendes Script)
./server/extract_aldi_nord.sh > raw_kw52.txt

# 2. Rezepte generieren
python tools/generate_recipes_from_raw.py \
  --input raw_kw52.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --output server/media/prospekte/aldi_nord/recipes_kw52_raw.json \
  --verbose

# 3. Mit echten Nährwerten anreichern
python tools/enrich_nutrition.py \
  --root server/media/prospekte/aldi_nord \
  --only-kw kw52 \
  --verbose

# 4. In App-Assets kopieren
cp server/media/prospekte/aldi_nord/recipes_kw52_raw_nutrition.json \
   assets/recipes/aldi_nord_kw52_2025.json

# 5. Fertig! App neu starten.
```

## Lizenz

Teil des `roman_app` Projekts.

