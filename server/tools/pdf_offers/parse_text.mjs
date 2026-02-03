// Sehr einfache, robuste Basis-Heuristiken. Danach iterativ verbessern.
export function parseOffers(fullText) {
    const lines = fullText
      .split('\n')
      .map(s => s.replace(/\s+/g, ' ').trim())
      .filter(Boolean);
  
    const items = [];
    for (let i = 0; i < lines.length; i++) {
      const L = lines[i];
  
      // Preis: 1,19 / 1.19 € / 1,19€ / 1.19*
      const mPrice = L.match(/(\d{1,3}(?:[.,]\d{2}))\s*(?:€|\*)?/);
      if (!mPrice) continue;
  
      // Filter rauschen (klassische Fallen: Telefonnummern, Datumsangaben)
      // Preis muss "realistisch" sein
      const price = parseFloat(mPrice[1].replace(',', '.'));
      if (!(price > 0.1 && price < 999)) continue;
  
      // Umkreis-Chunk (ein paar Zeilen davor/danach) durchsuchen:
      const windowStart = Math.max(0, i - 3);
      const windowEnd = Math.min(lines.length - 1, i + 4);
      const chunk = lines.slice(windowStart, windowEnd + 1).join(' • ');
  
      // Discount
      const mDisc = chunk.match(/-(\d{1,2})\s*%/);
      const discount_percent = mDisc ? parseInt(mDisc[1], 10) : undefined;
  
      // Einheit & Grundpreis
      let unit;
      const mUnit = chunk.match(/(\d+\s*(?:g|ml|kg|l))|(\d{2,4}\s*-\s*(?:g|ml))/i);
      if (mUnit) unit = mUnit[0].replace(/\s*-\s*/,' ');
  
      let price_per_unit;
      const mPpu = chunk.match(/(?:kg-Preis|l-Preis)\s*([\d.,]+\s*€\/(?:kg|l))/i);
      if (mPpu) price_per_unit = mPpu[1].replace(',', '.');
  
      // Produktname: 1–2 Zeilen vor dem Preis zusammensetzen
      const name = [lines[i-2], lines[i-1]]
        .filter(Boolean)
        .join(' ')
        .replace(/\s{2,}/g, ' ')
        .trim()
        .slice(0, 140);
  
      // Minimalanforderung: Name & Preis
      if (name && name.length >= 3) {
        items.push({
          name,
          price,
          unit,
          price_per_unit,
          discount_percent
        });
      }
    }
  
    // Deduplizieren: gleicher Name + gleicher Preis
    const key = (it) => `${it.name.toLowerCase()}|${it.price}`;
    const seen = new Set();
    const dedup = [];
    for (const it of items) {
      const k = key(it);
      if (seen.has(k)) continue;
      seen.add(k);
      dedup.push(it);
    }
  
    return dedup;
  }