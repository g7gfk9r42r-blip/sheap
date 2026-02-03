export type Retailer = 'REWE' | 'EDEKA' | 'LIDL' | 'ALDI' | 'NETTO';

export type Offer = {
  id: string;
  retailer: Retailer;
  title: string;
  price: number;
  unit: string | null;
  validFrom: string;
  validTo: string;
  imageUrl: string;
  updatedAt: string;
  weekKey?: string;
  brand?: string | null; // <- ensure this exists
  originalPrice?: number | null;
  discountPercent?: number | string | null;
  category?: string | null;
  page?: number | null;
  metadata?: Record<string, unknown>;
};

export interface Recipe {
  id: string;
  title: string;
  description: string;
  ingredients: string[];
  retailer: Retailer;
  weekKey: string;
  createdAt: string; // ISO
}

export type OffersDB = {
  upsertOffers(retailer: Retailer, weekKey: string, offers: Offer[]): void;
  getOffers(retailer?: Retailer, weekKey?: string): Offer[];
};

export type DBAdapter = OffersDB & {
  upsertRecipes(recipes: any[]): void;
  getRecipes(retailer?: Retailer, weekKey?: string): any[];
  load(): Promise<void>;
  save(): Promise<void>;
};