# Replicate API Fix - Runbook (Version-Hash)

## ✅ Änderungen

### 1. `tools/replicate_image.py`
- **Model-Auflösung**: `model_slug` (z.B. "black-forest-labs/flux-schnell") → `version_hash` via GET `/v1/models/{owner}/{name}`
- **Cache**: `_version_cache[model_slug] = version_hash` für Performance
- **Payload**: Nutzt `{"version": "<hash>", "input": {...}}` statt `{"model": ...}`
- **Rate Limit**: Robustes Exponential Backoff bei 429 oder "throttled"/"rate limit" (2s, 4s, 8s... max 60s, bis 10 Versuche)
- **Debug**: Ausgabe bei `DEBUG_IMAGES=1` (resolved_version, model, prompt_len, steps, HTTP status, error body)

### 2. `tools/replica_image.py`
- **Umgewandelt**: Alias/Wrapper für `ReplicateImageClient`
- **Zweck**: Rückwärtskompatibilität

### 3. `tools/test_replicate_payload.py`
- **Aktualisiert**: Prüft dass Payload `version` (Hash) enthält und KEIN `model`
- **Test**: Version-Auflösung mit Mock
- **Test**: Caching für mehrere Models

## 🔧 Verifikation

### Test 1: Unit Test (ohne API)
```bash
python3 tools/test_replicate_payload.py
```
**Erwartet**: ✅ ALLE TESTS BESTANDEN

### Test 2: Dry-Run mit einem Market
```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend none \
  --dry-run \
  --strict \
  --only aldi_nord
```
**Erwartet**: Validation erfolgreich, keine Bildgenerierung

### Test 3: Single Market Run mit Debug (aldi_nord)
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
  --throttle-ms 1000
```
**Erwartet**: 
- `[DEBUG] Resolving model: GET https://api.replicate.com/v1/models/black-forest-labs/flux-schnell`
- `[DEBUG] Resolved black-forest-labs/flux-schnell -> version <hash>`
- `[DEBUG] resolved_version=<hash> model=black-forest-labs/flux-schnell prompt_len=<n> steps=30`
- `[DEBUG] POST /v1/predictions with version=<hash>`
- Kein 422 Fehler ("version is required" oder "Additional property model is not allowed")
- Bilder werden generiert

## 📝 Wichtige Hinweise

1. **Version-Hash erforderlich**: Replicate API erwartet `version` (Hash), nicht `model`
2. **Automatische Auflösung**: Model-Slug wird beim ersten Aufruf zu Version-Hash aufgelöst und gecached
3. **Rate Limit**: Automatisches Backoff bei 429 oder "throttled"/"rate limit" (bis 10 Versuche, max 60s delay)
4. **Throttling**: Optional `--throttle-ms` um Rate Limits proaktiv zu vermeiden
5. **Debug**: Setze `DEBUG_IMAGES=1` für detaillierte Ausgabe (inkl. resolved version hash)

## 🐛 Troubleshooting

### 422 "version is required" oder "Additional property model is not allowed"
- ✅ Sollte jetzt nicht mehr vorkommen (Payload nutzt `version` statt `model`)
- Falls doch: Prüfe dass Model-Auflösung funktioniert (`DEBUG_IMAGES=1` zeigt resolved version)

### "Model not found: owner/name"
- Prüfe dass `--replicate-model` korrekt ist (z.B. `black-forest-labs/flux-schnell`)
- Prüfe API Token Berechtigungen

### Rate Limit Fehler
- Nutze `--throttle-ms 2000` (2 Sekunden Delay zwischen Bildern)
- Backoff wird automatisch angewendet (max 10 Versuche bei 429/"throttled")

### Connection Errors
- Prüfe `REPLICATE_API_TOKEN` Environment Variable
- Test: `export DEBUG_IMAGES=1` für detaillierte Logs
