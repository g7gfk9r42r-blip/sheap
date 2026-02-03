/**
 * EDEKA Offer Normalizer
 * 
 * Konvertiert EDEKA-API-Offers in das interne Offer-Format.
 */

import type { Offer, Retailer } from '../types.js';
import type { EdekaOffer } from '../services/edeka_api.js';

/**
 * Normalisiert ein EDEKA-Offer in das interne Offer-Format
 * 
 * @param edekaOffer EDEKA-API-Offer
 * @param marketId Markt-ID
 * @param year Jahr
 * @param week Woche (als String, z.B. "48")
 * @returns Normalisiertes Offer
 */
export function normalizeEdekaOffer(
  edekaOffer: EdekaOffer,
  marketId: string,
  year: number,
  week: string
): Offer {
  const weekKey = `${year}-W${week}`;
  const now = new Date().toISOString();
  
  // Berechne discountPercent falls originalPrice vorhanden
  let discountPercent: number | string | null = edekaOffer.discountPercent ?? null;
  if (!discountPercent && edekaOffer.originalPrice && edekaOffer.price) {
    const discount = ((edekaOffer.originalPrice - edekaOffer.price) / edekaOffer.originalPrice) * 100;
    discountPercent = Math.round(discount);
  }
  
  // Erstelle eindeutige ID
  const id = `edeka-${marketId}-${edekaOffer.id}-${weekKey}`;
  
  return {
    id,
    retailer: 'EDEKA' as Retailer,
    title: edekaOffer.title.trim(),
    price: edekaOffer.price,
    unit: edekaOffer.unit || '',
    validFrom: edekaOffer.validFrom,
    validTo: edekaOffer.validTo,
    imageUrl: edekaOffer.imageUrl || '',
    updatedAt: now,
    weekKey,
    brand: edekaOffer.brand || null,
    originalPrice: edekaOffer.originalPrice ?? null,
    discountPercent,
    category: edekaOffer.category || null,
    page: null,
    metadata: {
      source: 'edeka-api',
      marketId,
      edekaOfferId: edekaOffer.id,
      description: edekaOffer.description || null,
    },
  };
}

