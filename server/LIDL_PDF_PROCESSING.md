# Lidl PDF-Verarbeitung

## Übersicht

Dieses Script verarbeitet die bereits erstellten Lidl-PDFs (aus `media/prospekte/lidl/`) und extrahiert **alle Angebote** mit OCR.

## Verwendung

### Automatisch (neueste PDF)

```bash
npm run process:lidl:pdf
```

### Spezifische PDF

```bash
node tools/leaflets/process_lidl_pdf.mjs media/prospekte/lidl/lidl_2025-W48.pdf
```

### Erneut verarbeiten (überschreibt bestehende Daten)

```bash
npm run process:lidl:pdf -- --force
```

## Funktionsweise

1. **PDF finden**: Sucht automatisch die neueste PDF in `media/prospekte/lidl/`
2. **PDF → Bilder**: Konvertiert jede Seite zu PNG-Bildern (Playwright)
3. **OCR**: Extrahiert Text aus jedem Bild (Tesseract.js)
4. **Parsing**: Findet Preise, Titel, Marken, Einheiten
5. **JSON speichern**: Speichert in `data/lidl/{year}/W{week}/offers_pdf.json`

## Ausgabe

- **JSON**: `data/lidl/{year}/W{week}/offers_pdf.json`
- **Temporäre Dateien**: Werden automatisch gelöscht

## Abhängigkeiten

- `playwright` (für PDF → PNG)
- `tesseract.js` (für OCR)
- `sharp` (für Bildverarbeitung)
- `pdf-lib` (für PDF-Info)

## Performance

- **Dauer**: ~1-2 Minuten pro Seite (OCR ist langsam)
- **31 Seiten**: ~30-60 Minuten

## Tipps

1. **Parallele Verarbeitung**: Script verarbeitet Seiten sequenziell (kann optimiert werden)
2. **Bereits verarbeitet**: Script überspringt bereits verarbeitete PDFs (außer mit `--force`)
3. **Kombinieren**: Die OCR-Daten können mit den Network-Interception-Daten kombiniert werden

## Kombination mit Network-Daten

Die Network-Interception-Daten (aus `fetch_lidl_leaflet.mjs`) sind oft genauer, aber unvollständig.
Die OCR-Daten sind vollständiger, aber weniger genau.

**Empfehlung**: Kombiniere beide:
1. Network-Daten als Basis (genauer)
2. OCR-Daten als Ergänzung (vollständiger)

