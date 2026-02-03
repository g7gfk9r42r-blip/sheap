# 🚀 LIDL PDF Extraktion - GPT Vision (PERFEKT!)

## ✅ Einfacher Start - Copy & Paste

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/lidl
export OPENAI_API_KEY="sk-..."
python3 extract_lidl_offers_vision.py
```

## 📋 Was passiert?

1. ✅ Findet automatisch die PDF im Ordner
2. ✅ Konvertiert PDF zu Bildern (300 DPI)
3. ✅ Teilt jede Seite in 6 Kacheln (2x3 Grid)
4. ✅ Analysiert jede Kachel mit GPT-4o Vision
5. ✅ Extrahiert ALLE Angebote mit vollständigen Informationen
6. ✅ Dedupliziert automatisch
7. ✅ Speichert in `lidl.txt` und `lidl.json`

## ⏱️ Dauer

- **~10-20 Minuten** für 57 Seiten
- Script zeigt Fortschritt live an
- Kann auch im Hintergrund laufen

## 📊 Output

- **`lidl.txt`** - Textformat (perfekt zum Lesen)
- **`lidl.json`** - JSON-Format (für Weiterverarbeitung)

## ✨ Was extrahiert wird

Jedes Angebot enthält:
- ✅ Produktname (vollständig)
- ✅ Angebotspreis
- ✅ Originalpreis (falls vorhanden)
- ✅ UVP (falls vorhanden)
- ✅ Preis pro Einheit
- ✅ Menge/Einheit
- ✅ Marke
- ✅ Kategorie
- ✅ **📱 LIDL PLUS Badge** (falls vorhanden)
- ✅ Rabatt-%
- ✅ Beschreibung
- ✅ Bedingungen
- ✅ Seiten-Nummer

## 💡 Tipp

Das Script läuft auch weiter, wenn du den Terminal schließst (im Hintergrund).
