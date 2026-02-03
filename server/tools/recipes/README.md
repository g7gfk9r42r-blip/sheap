# 🍳 Recipe Generator

Automatische Rezept-Generierung aus Supermarkt-Angeboten mit GPT-4.

## 🔒 Sicherheit

✅ **Nur echte Produkte** aus der JSON verwenden  
✅ **Preise validieren** (keine Erfindungen)  
✅ **Kalorien plausibel** (200-1500 kcal/Portion)  
✅ **JSON-Schema validieren**  
✅ **Fehler-Logs** für manuelle Prüfung

---

## 🚀 Installation

```bash
cd server/tools/recipes
npm install openai dotenv
```

---

## 📋 API-Key einrichten

1. Öffne `/server/.env`
2. Füge hinzu:

```env
OPENAI_API_KEY=sk-......
```

---

## 🎯 Verwendung

### Alle Supermärkte verarbeiten

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
node tools/recipes/generate_recipes.mjs
```

### Erwartete Ausgabe

```
🍳 RECIPE GENERATOR GESTARTET

═══════════════════════════════════════════════════════════
📁 Gefundene Supermärkte: aldi_nord, aldi_sued, lidl, netto

═══════════════════════════════════════════════════════════
🏪 VERARBEITE: ALDI_NORD
═══════════════════════════════════════════════════════════
✅ aldi_nord: 250 Angebote geladen
🥗 180/250 Lebensmittel gefiltert

🤖 Generiere Rezepte für aldi_nord...
✅ 50 Rezepte generiert

🔒 Validiere Rezepte für aldi_nord...
✅ 48/50 Rezepte valide
⚠️  2 Rezepte mit Problemen:
   - Pasta Carbonara: Unplausible Kalorien (1800)
   - Gemüse-Curry: Zutat nicht gefunden: Kokosmilch

✅ Rezepte gespeichert: server/media/prospekte/aldi_nord/aldi_nord_recipes.json
```

---

## 📁 Output-Struktur

```json
{
  "supermarket": "aldi_nord",
  "generatedAt": "2025-12-17T...",
  "totalRecipes": 48,
  "recipes": [
    {
      "id": "aldi_nord_001",
      "title": "Rinderrouladen mit Rotkohl",
      "description": "Klassisches deutsches Gericht",
      "servings": 4,
      "prepTime": 30,
      "cookTime": 90,
      "difficulty": "medium",
      "ingredients": [
        {
          "productId": 15,
          "name": "Rouladen vom Rind",
          "brand": "Netto",
          "amount": "800 g",
          "price": 11.92,
          "originalPrice": null,
          "retailer": "aldi_nord"
        },
        {
          "productId": 42,
          "name": "Rotkohl",
          "brand": "Eigenmarke",
          "amount": "400 g",
          "price": 0.99,
          "originalPrice": null,
          "retailer": "aldi_nord"
        }
      ],
      "totalPrice": 12.91,
      "totalSavings": 0,
      "nutrition": {
        "calories": 650,
        "protein": 45,
        "carbs": 30,
        "fat": 35
      },
      "instructions": [
        "Rouladen flach klopfen und mit Senf bestreichen",
        "Mit Speck, Zwiebeln und Gewürzgurken füllen",
        "Aufrollen und mit Küchengarn fixieren",
        "In heißem Öl von allen Seiten anbraten",
        "Mit Rotwein ablöschen und 90 Min schmoren",
        "Rotkohl erhitzen und mit den Rouladen servieren"
      ],
      "tags": ["deutsch", "klassisch", "festlich"]
    }
  ]
}
```

---

## ⚙️ Konfiguration

Passe in `generate_recipes.mjs` an:

```javascript
const CONFIG = {
  recipesPerSupermarket: 50,  // Anzahl Rezepte
  maxRetries: 3,
  minIngredients: 3,
  maxIngredients: 10,
  minCalories: 200,
  maxCalories: 1500,
};
```

---

## 🔧 Troubleshooting

### "OPENAI_API_KEY nicht gesetzt"

```bash
# .env Datei prüfen
cat server/.env

# Sollte enthalten:
OPENAI_API_KEY=sk-proj-...
```

### "Keine JSON gefunden"

```bash
# Prüfe ob Angebots-JSONs existieren:
ls -la server/media/prospekte/*/

# Sollte zeigen:
# aldi_nord/aldi_nord.json
# lidl/lidl.json
# etc.
```

### "Zu wenige Lebensmittel"

Das Script filtert automatisch Non-Food-Artikel. Wenn ein Prospekt hauptsächlich Haushaltswaren enthält, werden zu wenige Lebensmittel gefunden.

**Lösung:** Manuelle Anpassung der `foodKeywords` in `filterFoodItems()`.

---

## 📊 Performance

- **~50 Rezepte:** ca. 2-3 Min
- **Kosten:** ca. $0.50 pro Supermarkt
- **API-Calls:** 1 pro Supermarkt

---

## 🎯 Next Steps

Nach der Generierung:

1. **Rezepte prüfen:** `server/media/prospekte/*/recipes.json`
2. **In App testen:** Flutter App neu starten
3. **Bilder generieren:** (TODO: Separate Script)

---

## 📞 Support

Bei Problemen:
1. Logs prüfen
2. Validierungs-Fehler lesen
3. JSON manuell anpassen

