# 🔥 Multiprocessing Prospekt Pipeline

Vollautomatische parallele Verarbeitung aller Prospekte mit AI Vision, OCR und HTML Parsing.

## Features

- ✅ **Parallele Verarbeitung**: Bis zu 20 Prospekte gleichzeitig
- ✅ **Auto-Discovery**: Findet automatisch alle Prospekt-Ordner
- ✅ **AI Vision Integration**: GPT-4o Vision für höchste Qualität
- ✅ **Auto-Recovery**: Fehlerbehandlung und Retry-Logik
- ✅ **Progress Tracking**: Echtzeit-Fortschrittsanzeige
- ✅ **Scheduler**: Automatische wöchentliche Runs

## Installation

```bash
pip install -r prospekt_pipeline/requirements.txt
```

## Verwendung

### Alle Prospekte verarbeiten

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
python3 -m prospekt_pipeline.multiprocessing.run_all
```

### Mit benutzerdefinierter Worker-Anzahl

```bash
python3 -m prospekt_pipeline.multiprocessing.run_all --workers 10
```

### Force Reprocessing

```bash
python3 -m prospekt_pipeline.multiprocessing.run_all --force
```

## Scheduler

### Manueller Start

```bash
# Läuft jeden Sonntag um 09:00
python3 -m prospekt_pipeline.multiprocessing.scheduler

# Benutzerdefinierte Zeit
python3 -m prospekt_pipeline.multiprocessing.scheduler --time "10:30" --day "monday"
```

### Cron Setup

```bash
# Crontab Eintrag für jeden Sonntag um 09:00
0 9 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && python3 -m prospekt_pipeline.multiprocessing.run_all >> logs/prospekt_pipeline.log 2>&1
```

## Konfiguration

Bearbeite `multiprocessing/config.py`:

- `CPU_LIMIT`: Anzahl paralleler Worker (default: 75% der CPUs, max 20)
- `BASE_DIR`: Basis-Verzeichnis für Prospekte
- `OUTPUT_DIR`: Output-Verzeichnis für JSON-Dateien
- `FILE_TIMEOUT`: Timeout pro Datei (Sekunden)

## Output

- **JSON-Dateien**: `data/angebote_{supermarket}.json`
- **Log-Datei**: `prospekt_pipeline/multiprocessing/last_run.json`

## Log Format

```json
{
  "timestamp": "2025-01-15T09:00:00",
  "status": "completed",
  "folders_total": 20,
  "folders_success": 18,
  "folders_failed": 2,
  "total_offers": 3420,
  "workers_used": 8,
  "results": [...]
}
```

## Troubleshooting

### Keine Prospekte gefunden

- Überprüfe `BASE_DIR` in `config.py`
- Stelle sicher, dass Ordnerstruktur `media/prospekte/{supermarket}/raw.pdf` existiert

### Out of Memory

- Reduziere `CPU_LIMIT` in `config.py`
- Verwende `--workers 4` für weniger parallele Prozesse

### AI Vision nicht aktiv

- Stelle sicher, dass `OPENAI_API_KEY` in `.env` gesetzt ist
- Pipeline fällt automatisch auf OCR/HTML zurück

