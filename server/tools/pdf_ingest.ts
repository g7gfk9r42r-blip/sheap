// server/src/tools/pdf_ingest.ts
// Usage:
//   tsx src/tools/pdf_ingest.ts --retailer NORMA --week 2025-W44 --txt media/prospekte/norma/2025/W44/norma_2025-W44_AT.txt

import { readFileSync } from 'node:fs';
import { createHash } from 'crypto';
import { basename } from 'node:path';
import type { Offer, Retailer } from '../src/types.js';
import { upsertOffers } from '../src/sqlite.js';
import { enrichOffers } from '../src/enrich.js';

type Args = {
  retailer: Retailer;
  week: string;            // e.g. "2025-W44"
  txt: string;             // path to pdftotext output
};

function parseArgs(): Args {
  const a = process.argv.slice(2);
  const arg = (k: string) => {
    const i = a.indexOf(k);
    return i >= 0 ? a[i + 1] : undefined;
  };
  const retailer = (arg('--retailer') || '').toUpperCase() as Retailer;
  const week = arg('--week') || '';
  const txt = arg('--txt') || '';

  if (!retailer || !week || !txt) {
    console.error('Usage: tsx src/tools/pdf_ingest.ts --retailer <REWE|EDEKA|LIDL|ALDI|NETTO|NORMA> --week 2025-W44 --txt <file>');
    process.exit(1);
  }
  return { retailer, week, txt };
}

/** ISO-Week (YYYY-Www) -> Monday + Sunday (YYYY-MM-DD) */
function isoWeekBounds(weekKey: string): { from: string; to: string } {
  // weekKey "2025-W44"
  const m = /^(\d{4})-W(\d{2})$/.exec(weekKey);
  if (!m) {
    // fallback to "today .. +6d"
    const today = new Date();
    const from = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const to = new Date(from); to.setDate(from.getDate() + 6);
    return { from: from.toISOString().slice(0, 10), to: to.toISOString().slice(0, 10) };
  }
  const year = Number(m[1]);
  const week = Number(m[2]);

  // Algorithm: ISO week 1 = week with first Thursday in January
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const jan4Day = jan4.getUTCDay() || 7; // 1..7 (Mon..Sun)
  const mondayWeek1 = new Date(jan4);
  mondayWeek1.setUTCDate(jan4.getUTCDate() - (jan4Day - 1));

  const monday = new Date(mondayWeek1);
  monday.setUTCDate(mondayWeek1.getUTCDate() + (week - 1) * 7);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);

  const fmt = (d: Date) => d.toISOString().slice(0, 10);
  return { from: fmt(monday), to: fmt(sunday) };
}

function slugId(input: string): string {
  return createHash('sha1').update(input).digest('hex').slice(0, 16);
}

/**
 * Sehr einfache Heuristik:
 * - Preis-Zeilen erkennen (z. B. "14,99 €" oder "15,– €" etc.)
 * - Titel = vorherige nicht-leere Zeile
 * - Einheit heuristisch aus Titel ableiten (optional)
 *
 * Für bessere Qualität kann man retailer-spezifische Regeln ergänzen.
 */
function parseOffersFromLines(lines: string[], retailer: Retailer, weekKey: string): Offer[] {
  const { from: validFrom, to: validTo } = isoWeekBounds(weekKey);
  const offers: Offer[] = [];

  // Preis-Regex (deutsch): 12,34 €, 12,– €, 12 € usw.
  const priceRe = /(\d{1,3}(?:[.,]\d{2})?|(?:\d{1,3}))\s*[€]|(\d{1,3})[,\.]\s*–\s*[€]/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim().replace(/\s+/g, ' ');
    if (!line) continue;

    if (priceRe.test(line)) {
      // hole vorherige sinnvolle Zeile als Titel
      let j = i - 1;
      let title = '';
      while (j >= 0 && !title) {
        const prev = lines[j].trim();
        if (prev && !priceRe.test(prev)) title = prev.replace(/\s+/g, ' ');
        j--;
      }
      if (!title) {
        // fallback: nimm die Zeile selbst (nicht schön, aber robust)
        title = line;
      }

      // Preis herausziehen
      let price: number | null = null;
      const m = line.match(/(\d{1,3}(?:[.,]\d{2}))/);
      if (m) {
        price = parseFloat(m[1].replace(',', '.'));
      } else {
        const m2 = line.match(/(\d{1,3})\s*[€]/);
        if (m2) price = parseFloat(m2[1]);
      }
      if (price == null || Number.isNaN(price)) continue;

      // Einheit heuristisch (optionale Verbesserung)
      const unit = guessUnit(title);

      const id = slugId(`${retailer}|${weekKey}|${title}|${price}|${i}`);
      const offer: Offer = {
        id,
        retailer,
        title,
        price,
        unit,
        validFrom,
        validTo,
        imageUrl: '', // optional: später per pdfimages extrahieren
        updatedAt: new Date().toISOString(),
        weekKey,
        brand: null,
      };
      offers.push(offer);
    }
  }
  return offers;
}

function guessUnit(title: string): string {
  const t = title.toLowerCase();
  if (/\bkg\b|kilogramm|kg\b/.test(t)) return 'kg';
  if (/\bg\b/.test(t)) return 'g';
  if (/\bl\b|liter\b/.test(t)) return 'l';
  if (/\bml\b/.test(t)) return 'ml';
  if (/\bstk\b|stück\b/.test(t)) return 'Stk';
  if (/\bpack\b|packung\b/.test(t)) return 'Pack';
  return 'Stk';
}

async function main() {
  const { retailer, week, txt } = parseArgs();
  const raw = readFileSync(txt, 'utf8');
  const lines = raw.split(/\r?\n/);

  const parsed = parseOffersFromLines(lines, retailer, week);
  const enriched = enrichOffers(parsed); // setzt brand anhand deiner BRAND_RULES

  if (enriched.length === 0) {
    console.warn(`[ingest] Keine Angebote erkannt. Datei: ${basename(txt)}`);
  } else {
    upsertOffers(retailer, week, enriched);
    console.log(`[ingest] ${retailer} ${week}: ${enriched.length} Angebote upserted.`);
    // kleine Probe
    console.log(enriched.slice(0, 5).map(o => ({ title: o.title, price: o.price, brand: o.brand })));
  }
}

main().catch((e) => {
  console.error('[ingest] Fehler:', e);
  process.exit(1);
});