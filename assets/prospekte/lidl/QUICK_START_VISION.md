# 🚀 LIDL PDF Extraktion mit GPT Vision - Quick Start

## ✅ Die perfekte Methode (wie früher!)

Dieses Script verwendet GPT-4o Vision um **ALLE Angebote** aus der LIDL-PDF zu extrahieren - genau wie früher, als es perfekt funktioniert hat!

## 📋 Voraussetzungen

### 1. API Key setzen

Der API-Key sollte bereits in `.env` sein. Falls nicht:

```bash
cd /Users/romw24/dev/AppProjektRoman
echo 'OPENAI_API_KEY=sk-proj-...' >> .env
```

### 2. PDF vorhanden

Die PDF sollte im Ordner `roman_app/server/media/prospekte/lidl/` liegen:
- `kaufDA - Lidl - LIDL LOHNT SICH.pdf` (oder andere `.pdf` Datei)

## 🚀 Ausführung

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/lidl

# Setze API Key (falls nicht in .env)
export OPENAI_API_KEY="sk-..."

# Führe Script aus
python3 extract_lidl_offers_vision.py
```

## ⏱️ Dauer

- **57 Seiten** × **6 Kacheln** = ~342 API-Calls
- **~10-20 Minuten** (abhängig von Rate Limits)
- Script zeigt Fortschritt an

## 📊 Output

Das Script erstellt:
- **`lidl.txt`** - Textformat mit allen Angeboten
- **`lidl.json`** - JSON-Format mit allen Daten

## ✨ Features

- ✅ **Pro Kachel Analyse** (2x3 Grid = 6 Kacheln pro Seite)
- ✅ **Maximale Genauigkeit** - erfasst jedes Angebot
- ✅ **Alle Informationen**: Preise, LIDL Plus, Marken, Kategorien, etc.
- ✅ **Automatische Deduplizierung**
- ✅ **Robuste Fehlerbehandlung** (Rate Limits, JSON-Parsing)
- ✅ **Fortschrittsanzeige**

## 🎯 Was extrahiert wird

Jedes Angebot enthält:
- Produktname (vollständig)
- Angebotspreis
- Originalpreis (falls vorhanden)
- UVP (falls vorhanden)
- Menge/Einheit
- Marke
- Kategorie
- **LIDL Plus Badge** (📱 LIDL PLUS / 📱 NUR LIDL PLUS)
- Rabatt-%
- Beschreibung
- Bedingungen
- Seiten-Nummer

## 💡 Tipp

Das Script läuft auch im Hintergrund weiter, wenn du den Terminal schließt. Die Ergebnisse werden trotzdem gespeichert!
