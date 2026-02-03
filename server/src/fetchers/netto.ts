import { Offer } from '../types.js';

export async function fetchOffers(weekKey: string): Promise<Offer[]> {
  const now = new Date().toISOString();
  return [
    {
      id: `NETTO-${weekKey}-1`,
      retailer: 'NETTO',
      title: 'Milch 1L',
      price: 0.99,
      unit: '1L',
      validFrom: new Date().toISOString(),
      validTo: new Date(Date.now() + 6 * 24 * 3600 * 1000).toISOString(),
      imageUrl: 'https://placehold.co/200x120?text=NETTO+Milch',
      updatedAt: now,
    },
  ];
}

