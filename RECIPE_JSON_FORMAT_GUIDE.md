# Rezept JSON Format - Kompakte Spezifikation

## ✅ Pflichtfelder

```json
{
  "id": "R001",
  "title": "Rezeptname",
  "retailer": "ALDI NORD",
  "servings": 2,
  "durationMinutes": 10,
  "ingredients": [...],
  "steps": [...],
  "price_total_eur": 4.77,
  "price_total_before_eur": 6.57,
  "heroImageUrl": "server/media/recipe_images/aldi_nord/R001.webp"
}
```

## 📋 Feldbeschreibungen

### Basis-Infos
- **id** (string): Eindeutige Rezept-ID (z.B. "R001")
- **title** (string): Rezeptname
- **retailer** (string): Supermarkt (z.B. "ALDI NORD", "REWE")
- **servings** (int): Anzahl Portionen
- **durationMinutes** (int): Gesamtdauer in Minuten

### Zutaten (ingredients)

**Format 1: Angebots-Zutat** (from_offer: true)
```json
{
  "name": "Skyr Vanille",
  "amount": "150 g",
  "from_offer": true,
  "offer_id": "ALDI-001",
  "brand": "Milbona",
  "price_eur": 0.79,
  "price_before_eur": 1.09,
  "quantity": 150,
  "unit": "g"
}
```

**Pflicht für Angebots-Zutaten:**
- `name`, `amount`, `from_offer: true`
- `offer_id`, `price_eur`
- `brand` ODER `product`
- `quantity`, `unit` (optional, aber empfohlen)

**Format 2: Basis-Zutat** (from_offer: false)
```json
{
  "name": "Salz",
  "amount": "nach Bedarf",
  "from_offer": false
}
```

### Zubereitung
- **steps** (array[string]): Zubereitungsschritte

### Preise
- **price_total_eur** (number): Gesamtpreis (Angebotspreis)
- **price_total_before_eur** (number): Gesamtpreis vorher
- **savings_eur** (number, optional): Ersparnis

### Bilder
- **heroImageUrl** (string): Pfad zum Bild (z.B. "server/media/recipe_images/aldi_nord/R001.webp")

### Optional
- **notes** (string): Hinweise (z.B. "Basiszutaten werden vorausgesetzt")

## 🔑 Wichtige Regeln

1. **Zutaten nur einmal**: Alle Infos direkt in `ingredients`, NICHT zusätzlich in `offers_used`
2. **Preise immer vorhanden**: `price_total_eur` und `price_total_before_eur` müssen vorhanden sein
3. **Angebots-Zutaten**: Wenn `from_offer: true`, dann MUSS haben: `offer_id`, `price_eur`, `brand`
4. **Zubereitung**: `steps` muss vorhanden sein (Array mit Strings)
5. **Bilder**: `heroImageUrl` sollte vorhanden sein

## 📝 Komplettes Beispiel

Siehe: `RECIPE_JSON_FORMAT_EXAMPLE.json`
