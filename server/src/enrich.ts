// server/src/enrich.ts
import type { Offer } from './types.js';
import { BRAND_RULES } from './brandMap.js';
import type { BrandRule } from './brandMap.js';

/**
 * Normalize: lowercase + strip diacritics
 * This keeps enrichment deterministic and fast (sync).
 */
function normalize(input: string): string {
  return input
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '');
}

/** Decide a brand based on keyword rules in BRAND_RULES (synchronous). */
export function detectBrand(title: string): string | null {
  const t = normalize(title);
  for (const rule of BRAND_RULES) {
    for (const kwRaw of rule.keywords) {
      const kw = normalize(kwRaw);
      if (kw && t.includes(kw)) return rule.brand;
    }
  }
  return null;
}

/** Named export used by refresh.ts */
export function enrichOffers(list: Offer[]): Offer[] {
  return list.map(o => ({ ...o, brand: detectBrand(o.title) }));
}

/**
 * updateBrandMap: optional Admin-Hook
 * Erlaubt das Ersetzen der Keyword-Regeln zur Laufzeit, ohne den Prozess zu restarten.
 * (BRAND_RULES ist ein Array; 'const' verhindert nur das Reassignen der Variablen,
 * nicht aber das Mutieren des Inhalts.)
 */
export function updateBrandMap(nextRules: BrandRule[]): void {
  // defensive copy, simple validation
  const cleaned: BrandRule[] = [];
  for (const r of nextRules ?? []) {
    if (!r || typeof r.brand !== 'string' || !Array.isArray(r.keywords)) continue;
    cleaned.push({
      brand: r.brand,
      keywords: r.keywords
        .map(k => String(k).trim())
        .filter(Boolean),
    });
  }
  // Replace contents in-place so alle Importe weiterhin dieselbe Array-Referenz sehen
  BRAND_RULES.length = 0;
  BRAND_RULES.push(...cleaned);
}