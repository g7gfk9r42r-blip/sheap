#!/usr/bin/env bash
set -eo pipefail
IN_PDF="$1"; MARKET="$2"; OUT_JSON="$3"
WORKDIR="$(mktemp -d)"; trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$(dirname "$OUT_JSON")"

echo "▶️  ${MARKET}: $IN_PDF"
if [ ! -f "$IN_PDF" ]; then
  echo "{\"market\":\"$MARKET\",\"items\":[]}" > "$OUT_JSON"
  echo "⚠️  PDF fehlt → leeres JSON: $OUT_JSON"
  exit 0
fi

# Pass 1: OCR/Optimierung
ocrmypdf --optimize 3 --fast-web-view 1 --deskew --rotate-pages --rotate-pages-threshold 12 \
         --language deu --output-type pdf "$IN_PDF" "$WORKDIR/ocr.pdf" >/dev/null 2>&1 || cp "$IN_PDF" "$WORKDIR/ocr.pdf"

# Pass 2: Direkttext
pdftotext -layout "$WORKDIR/ocr.pdf" "$WORKDIR/txt1.txt" || true

# Pass 3: Rasterize
mkdir -p "$WORKDIR/png"
pdftoppm -png -r 300 "$WORKDIR/ocr.pdf" "$WORKDIR/png/page" >/dev/null 2>&1 || true

# Pass 4: Tesseract pro Seite
> "$WORKDIR/txt2.txt"
for p in "$WORKDIR"/png/page-*.png; do
  [ -f "$p" ] || continue
  tesseract "$p" "$p" -l deu --oem 1 --psm 6 >/dev/null 2>&1 || true
  cat "${p%.png}.txt" >> "$WORKDIR/txt2.txt" || true
done

# Combine & clean
cat "$WORKDIR"/txt*.txt 2>/dev/null | sed 's/\r//g' | awk 'NF' > "$WORKDIR/all.txt"

# Preis-Zeilen vorfiltern
grep -E -i '([0-9]{1,3}([.,][0-9]{2})) ?€|€ ?[0-9]{1,3}([.,][0-9]{2})|[0-9]{1,2}\^[0-9]{2}' "$WORKDIR/all.txt" \
  > "$WORKDIR/lines_with_price.txt" || true

# Pass 5: Heuristik → JSON
python3 - "$WORKDIR/lines_with_price.txt" "$MARKET" << 'PY' > "$WORKDIR/tmp.json"
import sys, re, json, hashlib
path, market = sys.argv[1], sys.argv[2]
items, seen = [], set()
price_re = re.compile(r'(?P<price>\d{1,3}[.,]\d{2})\s*€|€\s*(?P<price2>\d{1,3}[.,]\d{2})|(?P<caret>\d{1,2})\^(?P<cents>\d{2})')
qty_re = re.compile(r'(\d+\s*(?:g|kg|ml|l|Stk\.?|Packung|Dose|Flasche))', re.I)

def norm_price(m):
    if m.group("price"): return m.group("price").replace(",", ".")
    if m.group("price2"): return m.group("price2").replace(",", ".")
    if m.group("caret"): return f"{m.group('caret')}.{m.group('cents')}"
    return None

try:
  lines = open(path, "r", encoding="utf-8", errors="ignore").read().splitlines()
except FileNotFoundError:
  lines = []

for line in lines:
    line=line.strip()
    m = price_re.search(line)
    if not m: continue
    price = norm_price(m)
    name = line[:m.start()].strip(" -–•\t") or "Unbenannt"
    m2 = qty_re.search(line)
    qty = m2.group(1) if m2 else None
    key = hashlib.sha1((name.lower()+"|"+(price or "")).encode()).hexdigest()[:12]
    if key in seen: continue
    seen.add(key)
    try:
      pe = float(price) if price else None
    except:
      pe = None
    items.append({"market": market, "name": name, "price_eur": pe, "quantity": qty, "raw": line})

# rudimentäre Sortierung und Aufräumen
items = sorted(items, key=lambda x: (x["name"].lower(), x["price_eur"] if x["price_eur"] is not None else 9999))
print(json.dumps({"market": market, "items": items}, ensure_ascii=False, indent=2))
PY

# Dedupe über jq (nach name+price)
if command -v jq >/dev/null 2>&1; then
  jq '{"market": .market, "items": ( .items | unique_by(.name, .price_eur) ) }' "$WORKDIR/tmp.json" > "$OUT_JSON"
else
  cp "$WORKDIR/tmp.json" "$OUT_JSON"
fi

echo "✅ Offers → $OUT_JSON"

