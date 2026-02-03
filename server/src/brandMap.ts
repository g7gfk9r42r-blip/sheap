// server/src/brandMap.ts
export type BrandRule = { brand: string; keywords: string[] };

// Mutierbares Array (kein freeze); Export ist const, Inhalt bleibt veränderbar
export const BRAND_RULES: BrandRule[] = [
  { brand: 'Goldähren', keywords: ['vollkornbrot', 'brot'] },
  { brand: 'Milbona',   keywords: ['joghurt'] },
  { brand: 'Milsani',   keywords: ['milch'] },
  { brand: 'REWE Bio',  keywords: ['rewe bio','bio äpfel','bio apfel'] },
  { brand: 'Viva',      keywords: ['bananen','banane'] },
];