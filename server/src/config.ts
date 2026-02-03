/**
 * Zentrale Konfiguration für den Server
 */

export const ADMIN_SECRET = process.env.ADMIN_SECRET || '';

// Crawl4AI Konfiguration
export const CRAWL4AI_BASE_URL = process.env.CRAWL4AI_BASE_URL ?? 'http://localhost:11235';
export const CRAWL4AI_TOKEN = process.env.CRAWL4AI_TOKEN ?? process.env.CRAWL4AI_API_KEY ?? '';

// Datenbank-Pfade
export const DATA_DIR = process.env.DATA_DIR || 'data';

// Media-Pfade
export const MEDIA_DIR = process.env.MEDIA_DIR || 'media';

