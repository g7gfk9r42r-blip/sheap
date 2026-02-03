import type { Offer, Retailer } from '../types.js';
import { adapter } from '../db.js';
import { getYearWeek } from '../utils/date.js';

export type ProspektOffer = {
  title: string;
  price: number;
  discount?: string | null;
  unit?: string | null;
  raw?: string;
};

export async function upsertOffers(
  retailer: string,
  rawOffers: ProspektOffer[],
): Promise<Offer[]> {
  const retailerKey = retailer.toUpperCase() as Retailer;
  const { weekKey } = getYearWeek();
  const now = new Date();
  const validFrom = now.toISOString();
  const validTo = new Date(now.getTime() + 6 * 24 * 60 * 60 * 1000).toISOString();

  const offers: Offer[] = rawOffers.map((offer, index) => ({
    id: buildOfferId(offer.title, weekKey, index),
    retailer: retailerKey,
    title: offer.title,
    price: offer.price,
    unit: offer.unit ?? null,
    validFrom,
    validTo,
    imageUrl: '',
    updatedAt: now.toISOString(),
    weekKey,
    brand: null,
    originalPrice: null,
    discountPercent: offer.discount ?? null,
    category: null,
    page: null,
    metadata: {
      source: 'prospektangebote',
      discount: offer.discount ?? null,
      raw: offer.raw ?? null,
    },
  }));

  adapter.upsertOffers(retailerKey, weekKey, offers);
  return offers;
}

function buildOfferId(title: string, weekKey: string, index: number) {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .substring(0, 40);
  return `PA-${weekKey}-${slug || 'offer'}-${index}`;
}
