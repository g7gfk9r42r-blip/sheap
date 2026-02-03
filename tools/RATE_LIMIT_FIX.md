# Rate Limit Fix - Optimierungen

## ✅ Änderungen

### 1. Proaktives Throttling
- **VORHER**: Throttling nur nach erfolgreichem Download
- **JETZT**: Throttling VOR jedem Request (auch beim ersten)
- **Default**: `--throttle-ms` jetzt 2000ms (2 Sekunden) statt 0

### 2. Längeres Backoff bei Rate Limits
- **Max Backoff**: 60s → 120s erhöht
- **Rate Limit Backoff**: Startet mit 5s statt 2s (5s, 10s, 20s, 40s...)
- **Retry-After Header**: Wird aus Response gelesen und respektiert

### 3. Verbesserte Rate Limit Erkennung
- Erkennt 429 Status Code
- Erkennt "throttled" / "rate limit" im Error-Text
- Nutzt Retry-After Header falls vorhanden

## 🔧 Empfohlene Werte

### Für viele Bilder (100+):
```bash
--throttle-ms 5000  # 5 Sekunden zwischen Requests
```

### Für moderate Mengen (20-100 Bilder):
```bash
--throttle-ms 2000  # 2 Sekunden (Standard)
```

### Für wenige Bilder (< 20):
```bash
--throttle-ms 1000  # 1 Sekunde
```

## 📋 Beispiel-Kommandos

### Mit aggressivem Throttling (5s):
```bash
export REPLICATE_API_TOKEN="r8_..."
export DEBUG_IMAGES=1

python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --replicate-model black-forest-labs/flux-schnell \
  --only aldi_nord \
  --throttle-ms 5000
```

### Mit Standard-Throttling (2s):
```bash
export REPLICATE_API_TOKEN="r8_..."
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --replicate-model black-forest-labs/flux-schnell \
  --throttle-ms 2000
```

## 🐛 Was passiert bei Rate Limit?

1. **Erste Erkennung**: Request wird mit 429 zurückgewiesen
2. **Retry-After**: Falls Header vorhanden, wird dieser respektiert
3. **Backoff**: Exponential Backoff startet bei 5s (Rate Limit) oder 2s (andere Fehler)
4. **Max Versuche**: 10 Versuche bei Rate Limit, dann Abbruch
5. **Max Delay**: Bis zu 120 Sekunden Wartezeit zwischen Versuchen

## 💡 Tipps

- **Starte klein**: Teste mit `--only aldi_nord` und `--throttle-ms 5000`
- **Beobachte Debug**: `DEBUG_IMAGES=1` zeigt alle Retries und Wartezeiten
- **Erhöhe bei Bedarf**: Wenn weiterhin Rate Limits kommen, erhöhe `--throttle-ms` auf 10000 (10s)
- **Nacht-Processing**: Replicate API hat nachts (MEZ) oft weniger Last
