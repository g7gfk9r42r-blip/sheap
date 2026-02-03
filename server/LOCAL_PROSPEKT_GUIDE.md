# Lokale Prospekt-Verarbeitung - Komplett-Guide

## 🎯 Beste Lösung: PDF verwenden!

**Warum PDF?**
- ✅ Alles eingebettet (keine dynamischen Inhalte)
- ✅ Einfach zu parsen
- ✅ 100% zuverlässig
- ✅ Legal (öffentliche PDF-Links)

## 📋 Workflow für EDEKA, Lidl, Rewe

### Option 1: PDF herunterladen (EMPFOHLEN)

1. **Gehe zu KaufDA oder Händler-Website**
2. **Öffne den Prospekt**
3. **Rechtsklick → "Link-Adresse kopieren"** (wenn PDF-Download verfügbar)
4. **Oder: "Speichern unter..." → Als PDF speichern**
5. **PDF in `media/prospekte/{retailer}/` ablegen**

### Option 2: HTML vollständig speichern (Fallback)

**WICHTIG**: Speichere als **"Webseite, vollständig"** (nicht nur HTML)!

1. **Chrome/Safari**: 
   - `Cmd+S` → **"Webseite, vollständig"** wählen
   - Speichere in `media/prospekte/{retailer}/`
   - Alle Assets werden mitgespeichert

2. **Firefox**:
   - `Cmd+S` → **"Webseite, vollständig"** wählen
   - Alle Bilder/Assets werden mitgespeichert

## 🚀 Verwendung

### Einzelne Datei verarbeiten

```bash
# PDF
npm run process:local file "media/prospekte/edeka/Berlin.pdf" EDEKA

# HTML (vollständig gespeichert)
npm run process:local file "media/prospekte/lidl/München.html" LIDL
```

### Verzeichnis verarbeiten

```bash
# Alle PDFs/HTMLs in einem Verzeichnis
npm run process:local dir "media/prospekte/rewe" REWE
```

## 📁 Verzeichnisstruktur

```
media/prospekte/
├── edeka/
│   ├── Berlin.pdf          ← PDF (EMPFOHLEN)
│   ├── Hamburg.pdf
│   └── München.html        ← HTML (mit Assets)
│       └── München_files/  ← Automatisch erstellt
│           ├── *.jpg
│           └── *.css
├── lidl/
│   └── ...
└── rewe/
    └── ...
```

## 🔍 Was wird extrahiert?

### Aus PDF:
- ✅ Produktname
- ✅ Preis
- ✅ Rabatt (falls vorhanden)
- ✅ Einheit (kg, l, Stück, etc.)
- ✅ Region

### Aus HTML:
- ✅ PDF-Links (falls vorhanden)
- ✅ Angebote (falls im HTML-Text)
- ⚠️ **WICHTIG**: Dynamische Inhalte (via JavaScript geladen) werden NICHT erkannt!

## ⚠️ Warum HTML problematisch sein kann

Moderne Webseiten laden Inhalte dynamisch:
- Bilder werden per JavaScript nachgeladen
- Angebote werden via API abgerufen
- Inhalte werden erst beim Scrollen geladen

**Lösung**: 
1. **PDF bevorzugen** (alles eingebettet)
2. **Oder**: HTML als "Webseite, vollständig" speichern (Assets werden mitgespeichert)
3. **Oder**: Playwright nutzen (aber das ist Scraping - weniger legal)

## 📊 Output

Alle extrahierten Angebote werden gespeichert unter:

```
data/{retailer}/{year}/W{week}/{dateiname}.json
```

Beispiel:
```
data/edeka/2025/W48/Berlin.json
```

## 🧪 Testen

```bash
# 1. Build
npm run build

# 2. Teste einzelne Datei
npm run process:local file "media/prospekte/edeka/kaufDA - EDEKA - Aktuelle Angebote.html" EDEKA

# 3. Prüfe Output
cat data/edeka/2025/W48/kaufDA*.json | jq '.offers | length'
```

## 💡 Best Practices

1. **PDF > HTML**: Nutze immer PDF, wenn verfügbar
2. **Vollständig speichern**: Bei HTML immer "Webseite, vollständig" wählen
3. **Regelmäßig aktualisieren**: Prospekte ändern sich wöchentlich
4. **Backup**: Behalte die Original-Dateien in `media/prospekte/`

## 🔗 Links

- [KaufDA EDEKA](https://www.kaufda.de/Geschaefte/Edeka)
- [Lidl Prospekte](https://www.lidl.de/c/prospekte/a10005965)
- [REWE Angebote](https://www.rewe.de/angebote/)

