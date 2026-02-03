/**
 * EDEKA Official API Client
 * 
 * Nutzt die offizielle EDEKA-API für Markt-Suche und Angebote.
 * Kein Scraping, keine PDFs - nur echte API-Daten.
 */

const EDEKA_API_BASE = 'https://www.edeka.de/api';
const DEFAULT_TIMEOUT_MS = 30000;
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

/**
 * EDEKA Market (aus Market-Search)
 */
export type EdekaMarket = {
  id: string;
  name: string;
  address: {
    street?: string;
    zipCode?: string;
    city?: string;
  };
  coordinates?: {
    latitude: number;
    longitude: number;
  };
  distance?: number; // in km
};

/**
 * EDEKA Market Details
 */
export type EdekaMarketDetails = EdekaMarket & {
  phone?: string;
  email?: string;
  openingHours?: string[];
  services?: string[];
};

/**
 * EDEKA Offer (aus Offers-API)
 */
export type EdekaOffer = {
  id: string;
  title: string;
  price: number;
  originalPrice?: number | null;
  discountPercent?: number | null;
  unit?: string | null;
  validFrom: string; // ISO date
  validTo: string; // ISO date
  imageUrl?: string | null;
  category?: string | null;
  brand?: string | null;
  description?: string | null;
};

/**
 * API Response Wrapper
 */
type ApiResponse<T> = {
  success: boolean;
  data?: T;
  error?: string;
};

/**
 * Retry-Logik mit Exponential Backoff
 */
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = MAX_RETRIES,
  delay: number = RETRY_DELAY_MS
): Promise<T> {
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      
      if (attempt < maxRetries - 1) {
        const waitTime = delay * Math.pow(2, attempt);
        console.log(`[EDEKA-API] Retry ${attempt + 1}/${maxRetries} nach ${waitTime}ms...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
  
  throw lastError || new Error('Unknown error after retries');
}

/**
 * HTTP Request mit Timeout und Error-Handling
 */
async function apiRequest<T>(
  url: string,
  options: RequestInit = {}
): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        ...options.headers,
      },
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    return data as T;
  } catch (err) {
    if (err instanceof Error && err.name === 'AbortError') {
      throw new Error(`Request timeout after ${DEFAULT_TIMEOUT_MS}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Sucht EDEKA-Märkte nach PLZ
 * 
 * @param plz Postleitzahl (z.B. "80331")
 * @returns Liste von EDEKA-Märkten
 */
export async function fetchMarketsByPLZ(plz: string): Promise<EdekaMarket[]> {
  console.log(`[EDEKA-API] Suche Märkte für PLZ: ${plz}`);
  
  const url = `${EDEKA_API_BASE}/marketsearch?zip=${encodeURIComponent(plz)}`;
  
  try {
    const data = await withRetry(() => apiRequest<EdekaMarket[] | { markets?: EdekaMarket[]; data?: EdekaMarket[] }>(url));
    
    // Handle verschiedene Response-Formate
    let markets: EdekaMarket[] = [];
    if (Array.isArray(data)) {
      markets = data;
    } else if (data.markets && Array.isArray(data.markets)) {
      markets = data.markets;
    } else if (data.data && Array.isArray(data.data)) {
      markets = data.data;
    }
    
    console.log(`[EDEKA-API] ${markets.length} Märkte gefunden für PLZ ${plz}`);
    return markets;
  } catch (err) {
    console.error(`[EDEKA-API] Fehler beim Suchen von Märkten für PLZ ${plz}:`, err);
    throw new Error(`Markt-Suche fehlgeschlagen: ${err instanceof Error ? err.message : String(err)}`);
  }
}

/**
 * Lädt Details für einen spezifischen Markt
 * 
 * @param marketId Markt-ID
 * @returns Markt-Details
 */
export async function fetchMarketDetails(marketId: string): Promise<EdekaMarketDetails> {
  console.log(`[EDEKA-API] Lade Details für Markt: ${marketId}`);
  
  const url = `${EDEKA_API_BASE}/markets/${encodeURIComponent(marketId)}`;
  
  try {
    const data = await withRetry(() => apiRequest<EdekaMarketDetails>(url));
    console.log(`[EDEKA-API] Details geladen für Markt ${marketId}`);
    return data;
  } catch (err) {
    console.error(`[EDEKA-API] Fehler beim Laden von Markt-Details für ${marketId}:`, err);
    throw new Error(`Markt-Details fehlgeschlagen: ${err instanceof Error ? err.message : String(err)}`);
  }
}

/**
 * Lädt alle Angebote für einen spezifischen Markt
 * 
 * @param marketId Markt-ID
 * @returns Liste von Angeboten
 */
export async function fetchMarketOffers(marketId: string): Promise<EdekaOffer[]> {
  console.log(`[EDEKA-API] Lade Angebote für Markt: ${marketId}`);
  
  const url = `${EDEKA_API_BASE}/offers?marketId=${encodeURIComponent(marketId)}`;
  
  try {
    const data = await withRetry(() => apiRequest<EdekaOffer[] | { offers?: EdekaOffer[]; data?: EdekaOffer[] }>(url));
    
    // Handle verschiedene Response-Formate
    let offers: EdekaOffer[] = [];
    if (Array.isArray(data)) {
      offers = data;
    } else if (data.offers && Array.isArray(data.offers)) {
      offers = data.offers;
    } else if (data.data && Array.isArray(data.data)) {
      offers = data.data;
    }
    
    console.log(`[EDEKA-API] ${offers.length} Angebote gefunden für Markt ${marketId}`);
    return offers;
  } catch (err) {
    console.error(`[EDEKA-API] Fehler beim Laden von Angeboten für ${marketId}:`, err);
    throw new Error(`Angebote laden fehlgeschlagen: ${err instanceof Error ? err.message : String(err)}`);
  }
}

