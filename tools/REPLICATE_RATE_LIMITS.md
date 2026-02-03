# Replicate Rate Limits - Optimierung

## 📊 Replicate API Limits

### Standard Limits:
- **Predictions**: 600 requests/minute = **10 requests/second**
- **Andere Endpoints**: 3000 requests/minute = 50 requests/second
- **Burst**: Kurze Bursts über Limit möglich

### Limitierte Accounts:
- **Niedriges Credit**: Stärkere Rate Limits
- **Ohne Payment Method**: 1 request/second, max 6/minute

### Rate Limit Response:
```json
{"detail":"Request was throttled. Your rate limit resets in ~30s."}
```

## 🔧 Optimierte Throttling-Werte

### Standard (5 req/s = 300/min - sicher unter Limit):
```bash
--throttle-ms 200  # 200ms = 5 requests/second
```
**Empfohlen für normale Nutzung**

### Konservativ (2 req/s = 120/min):
```bash
--throttle-ms 500  # 500ms = 2 requests/second
```
**Für viele Bilder oder wenn Credit niedrig**

### Sehr konservativ (1 req/s = 60/min):
```bash
--throttle-ms 1000  # 1 Sekunde = 1 request/second
```
**Für limitierte Accounts oder sehr viele Bilder**

### Aggressiv (10 req/s = 600/min - am Limit):
```bash
--throttle-ms 100  # 100ms = 10 requests/second
```
**Nur wenn sicher, dass keine anderen Limits greifen**

## 🎯 Empfohlene Einstellungen

### Für normale Nutzung (Standard):
```bash
export REPLICATE_API_TOKEN="r8_..."

python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --replicate-model black-forest-labs/flux-schnell \
  --throttle-ms 200
```

### Für viele Bilder (100+):
```bash
--throttle-ms 500  # 2 req/s = sicherer
```

### Bei Rate Limit Warnings:
```bash
--throttle-ms 1000  # 1 req/s = sehr sicher
```

## 📈 Limit erhöhen

### Option 1: Payment Method hinzufügen
- Gehe zu https://replicate.com/account/billing
- Füge Payment Method hinzu
- → Erhöht Limits (keine 1 req/s Beschränkung mehr)

### Option 2: Credit Auto-Reload
- Setze Auto-Reload auf > $20
- → Verhindert stärkere Rate Limits bei niedrigem Credit

### Option 3: Kontakt Replicate
- Kontaktiere Replicate Support für höhere Limits
- Siehe: https://replicate.com/docs/reference/rate-limits

## 🐛 Was passiert bei Rate Limit?

1. **429 Response**: "Request was throttled. Your rate limit resets in ~30s."
2. **Retry-After**: Wird aus Error-Message extrahiert ("resets in ~30s")
3. **Backoff**: Exponential Backoff 5s → 10s → 20s → ... max 120s
4. **Max Versuche**: 10 Versuche, dann Abbruch

## 💡 Tipps

- **Starte konservativ**: Nutze `--throttle-ms 500` (2 req/s) für den Anfang
- **Beobachte Debug**: `DEBUG_IMAGES=1` zeigt alle Rate Limit Retries
- **Payment Method**: Füge Payment Method hinzu für höhere Limits
- **Credit Balance**: Halte Balance > $20 für normale Limits
