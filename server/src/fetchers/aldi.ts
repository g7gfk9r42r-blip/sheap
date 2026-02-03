import { Offer } from '../types.js';

export async function fetchOffers(weekKey: string): Promise<Offer[]> {
  const now = new Date().toISOString();
  return [
    {
      id: `ALDI-${weekKey}-1`,
      retailer: 'ALDI',
      title: 'Vollkornbrot 750g',
      price: 1.19,
      unit: '750g',
      validFrom: new Date().toISOString(),
      validTo: new Date(Date.now() + 6 * 24 * 3600 * 1000).toISOString(),
      imageUrl: 'https://placehold.co/200x120?text=ALDI+Brot',
      updatedAt: now,
    },
  ];
}

