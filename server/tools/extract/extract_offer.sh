#!/usr/bin/env bash
set -euo pipefail

IN_PDF="$1"         # z.B. media/prospekte/penny/2025/W44/leaflet.pdf
MARKET="$2"         # z.B. penny
OUT_JSON="$3"       # z.B. assets/offers/2025/W44/penny.json

WORKDIR="$(mktemp -d)"
cleanup(){ rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "▶️  ${MARKET}: $IN_PDF"

# Pass 0: Normalisieren → durch OCRmyPDF laufen lassen (macht PDF durchsuchbar, lässt Original-Bilder drin)
ocrmypdf --optimize 3 --fast-web-view 1 --deskew --rotate-pages --rotate-pages-threshold 12 \
         --language deu --output-type pdf "$IN_PDF" "$WORKDIR/ocr.pdf" >/dev/null 2>&1 || true

# Pass 1: eingebetteter Text (falls vorhanden)
pdftotext -layout "$WORKDIR/ocr.pdf" "$WORKDIR/txt1.txt" || true

# Pass 2: hochauflösend in Bilder → Tesseract (LSTM, deutsch)
mkdir -p "$WORKDIR/png"
pdftoppm -png -r 300 "$WORKDIR/ocr.pdf" "$WORKDIR/png/page" >/dev/null 2>&1 || true
> "$WORKDIR/txt2.txt"
for p in "$WORKDIR"/png/page-*.png; do
  [ -f "$p" ] || continue
  tesseract "$p" "$p" -l deu --oem 1 --psm 6 >/dev/null 2>&1 || true
  cat "${p%.png}.txt" >> "$WORKDIR/txt2.txt" || true
done

# Pass 3: Preis-Regexe (Euro-Varianten), Artikelzeilen heuristisch sammeln
cat "$WORKDIR"/txt*.txt 2>/dev/null | \
  sed 's/\r//g' | awk 'NF' > "$WORKDIR/all.txt"

# Preis-Muster: 1,23 € | € 1,23 | 12.34€ | 1^99 (Sonderdarstellung) etc.
grep -E -i '([0-9]{1,3}([.,][0-9]{2})) ?€|€ ?[0-9]{1,3}([.,][0-9]{2})|[0-9]{1,2}\^[0-9]{2}' "$WORKDIR/all.txt" \
  > "$WORKDIR/lines_with_price.txt" || true

# Pass 4: einfache Heuristik → Name (links), Preis (rechts), Menge/Einheit in Klammern
# (Für hohe Qualität wird das später durch Layout-Parser ersetzt; hier pragmatisch.)
python3 - "$WORKDIR/lines_with_price.txt" "$MARKET" << 'PY' > "$WORKDIR/tmp.json"
import sys, re, json, hashlib
path, market = sys.argv[1], sys.argv[2]
items = []
seen = set()
price_re = re.compile(r'(?P<price>\d{1,3}[.,]\d{2})\s*€|€\s*(?P<price2>\d{1,3}[.,]\d{2})|(?P<caret>\d{1,2})\^(?P<cents>\d{2})')

def norm_price(m):
    if m.group("price"): return m.group("price").replace(",", ".")
    if m.group("price2"): return m.group("price2").replace(",", ".")
    if m.group("caret"): return f"{m.group('caret')}.{m.group('cents')}"
    return None

with open(path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        line=line.strip()
        if not line: continue
        m = price_re.search(line)
        if not m: continue
        price = norm_price(m)
        if not price: continue
        # Name: bis zum Preis-Anteil
        name = line[:m.start()].strip(" -–•\t")
        # Fallback, wenn leer:
        if not name:
            name = "Unbenannt"

        # Menge/Einheit heuristisch
        qty = None
        m2 = re.search(r'(\d+\s*(g|kg|ml|l|Stk\.?|Packung|Dose|Flasche))', line, re.I)
        if m2: qty = m2.group(1)

        key = hashlib.sha1((name.lower()+"|"+price).encode()).hexdigest()[:12]
        if key in seen: continue
        seen.add(key)
        items.append({
            "market": market,
            "name": name,
            "price_eur": float(price),
            "quantity": qty,
            "raw": line
        })
print(json.dumps({"market": market, "items": items}, ensure_ascii=False, indent=2))
PY

# Pass 5: Deduplizieren / Sortieren
jq '{"market": .market, "items": ( .items | unique_by(.name, .price_eur) | sort_by(.name) ) }' "$WORKDIR/tmp.json" > "$OUT_JSON"

echo "✅ Offers → $OUT_JSON"