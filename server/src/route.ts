import express from 'express';
import { promises as fs } from 'node:fs';
import { join, extname } from 'node:path';
import crypto from 'node:crypto';
// Use global fetch API from Node.js v18+ (no import needed)

// Where media is stored. For production with persistent disk, set MEDIA_DIR (preferred) or IMAGE_CACHE_DIR.
// Default: <repo>/roman_app/server/media
export const MEDIA_DIR =
  process.env.MEDIA_DIR || process.env.IMAGE_CACHE_DIR || join(process.cwd(), 'media');

// Cache für bereits verarbeitete URLs
const urlCache = new Map<string, string>();

export async function ensureMediaDir() {
  await fs.mkdir(MEDIA_DIR, { recursive: true });
}

// Statische Auslieferung mit Caching Headers
export function mountMedia(app: express.Express) {
  const staticMiddleware = express.static(MEDIA_DIR, {
    fallthrough: false,
    index: false,
    // Set sensible caching per file type.
    setHeaders(res, filePath) {
      const ext = extname(filePath).toLowerCase();
      // JSON should refresh frequently (weekly updates). Let clients revalidate.
      if (ext === '.json') {
        res.setHeader('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
        return;
      }
      // Images can be cached longer. If you overwrite files weekly, keep this moderate.
      if (ext === '.png' || ext === '.webp' || ext === '.jpg' || ext === '.jpeg') {
        res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=604800');
        return;
      }
      // Default for other static files.
      res.setHeader('Cache-Control', 'public, max-age=3600');
    },
  });

  // Serve under /media/*
  app.use('/media', staticMiddleware);
}

// Lädt ein Bild und gibt lokale URL zurück
export async function cacheImage(url: string): Promise<string> {
  // Prüfe Cache zuerst
  if (urlCache.has(url)) {
    return urlCache.get(url)!;
  }

  await ensureMediaDir();
  
  // Erstelle einen sicheren Dateinamen basierend auf URL-Hash
  const urlHash = crypto.createHash('sha256').update(url).digest('hex').substring(0, 16);
  
  // Versuche Dateierweiterung aus URL zu extrahieren
  let extension = '.jpg'; // Default
  try {
    const urlExt = extname(new URL(url).pathname).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(urlExt)) {
      extension = urlExt;
    }
  } catch {
    // URL parsing failed, use default
  }
  
  const fileName = `${urlHash}${extension}`;
  const filePath = join(MEDIA_DIR, fileName);
  
  try {
    // Prüfe ob Datei bereits existiert
    await fs.access(filePath);
    const localUrl = `/media/${fileName}`;
    urlCache.set(url, localUrl);
    return localUrl;
  } catch {
    // Datei existiert nicht, lade sie herunter
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Grocify-Bot/1.0',
          'Accept': 'image/*'
        },
        // Timeout nach 10 Sekunden
        signal: AbortSignal.timeout(10000)
      });
      
      if (!res.ok) {
        throw new Error(`Image fetch failed: ${res.status} ${res.statusText}`);
      }
      
      // Prüfe Content-Type
      const contentType = res.headers.get('content-type');
      if (!contentType || !contentType.startsWith('image/')) {
        throw new Error(`Invalid content type: ${contentType}`);
      }
      
      const buf = Buffer.from(await res.arrayBuffer());
      
      // Prüfe Dateigröße (max 5MB)
      if (buf.length > 5 * 1024 * 1024) {
        throw new Error('Image too large (>5MB)');
      }
      
      await fs.writeFile(filePath, buf);
      
      const localUrl = `/media/${fileName}`;
      urlCache.set(url, localUrl);
      
      console.log(`[cache] Cached image: ${url} -> ${localUrl} (${buf.length} bytes)`);
      return localUrl;
      
    } catch (error) {
      console.warn(`[cache] Failed to cache image ${url}:`, error);
      // Bei Fehlern die ursprüngliche URL zurückgeben
      return url;
    }
  }
}

// Cleanup-Funktion für alte Bilder (optional)
export async function cleanupOldImages(maxAgeMs: number = 7 * 24 * 60 * 60 * 1000) {
  try {
    const files = await fs.readdir(MEDIA_DIR);
    const now = Date.now();
    
    for (const file of files) {
      const filePath = join(MEDIA_DIR, file);
      const stats = await fs.stat(filePath);
      
      if (now - stats.mtime.getTime() > maxAgeMs) {
        await fs.unlink(filePath);
        console.log(`[cleanup] Removed old image: ${file}`);
      }
    }
  } catch (error) {
    console.warn('[cleanup] Failed to cleanup old images:', error);
  }
}