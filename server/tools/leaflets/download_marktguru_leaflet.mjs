import fs from 'fs-extra';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import puppeteer from 'puppeteer';

// Resolve ESM-friendly __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ──────────────────────────────────────────────────────────────────────────────
// CLI args
// Usage:
//   node download_marktguru_leaflet.mjs <LEAFLET_ID> <OUT_DIR> [--max 300] [--headful] [--delay 250] [--debug]
const argv = process.argv.slice(2);
if (argv.length < 2) {
  console.error('Usage: node download_marktguru_leaflet.mjs <LEAFLET_ID> <OUT_DIR> [--max 300] [--headful] [--delay 250] [--debug]');
  process.exit(1);
}
const LEAFLET_ID = String(argv[0]).trim();
const OUT_DIR = path.resolve(argv[1]);
const MAX_PAGES = Number((argv.includes('--max') ? argv[argv.indexOf('--max') + 1] : 300)) || 300;
const DELAY = Number((argv.includes('--delay') ? argv[argv.indexOf('--delay') + 1] : 250)) || 250;
const HEADFUL = argv.includes('--headful');
const DEBUG = argv.includes('--debug');

const BASE_URL = `https://www.marktguru.de/leaflets/${LEAFLET_ID}`;
const pagesDir = path.join(OUT_DIR, 'pages');
const pdfPath = path.join(OUT_DIR, `leaflet_${LEAFLET_ID}.pdf`);

// ──────────────────────────────────────────────────────────────────────────────
// Utilities
function sha1(buf) {
  return crypto.createHash('sha1').update(buf).digest('hex');
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function ensureDirs() {
  await fs.ensureDir(OUT_DIR);
  await fs.ensureDir(pagesDir);
}

function extFromContentType(ct) {
  if (!ct) return '.bin';
  const t = ct.toLowerCase();
  if (t.includes('image/webp')) return '.webp';
  if (t.includes('image/jpeg')) return '.jpg';
  if (t.includes('image/png')) return '.png';
  return '.img';
}

async function saveDebug(pageIndex, html, screenshotBuf) {
  if (!DEBUG) return;
  const dbgDir = path.join(OUT_DIR, 'debug');
  await fs.ensureDir(dbgDir);
  if (html) await fs.writeFile(path.join(dbgDir, `page_${String(pageIndex).padStart(3, '0')}.html`), html, 'utf8');
  if (screenshotBuf) await fs.writeFile(path.join(dbgDir, `page_${String(pageIndex).padStart(3, '0')}.png`), screenshotBuf);
}

// ──────────────────────────────────────────────────────────────────────────────
// CORS-safe image loader
async function fetchImageSmart({ page, href, referer }) {
  // 1) Versuch: im Browser-Kontext
  try {
    const payload = await page.evaluate(async (u, ref) => {
      const res = await fetch(u, {
        headers: {
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'Referer': ref,
          'Cache-Control': 'no-cache',
        },
        credentials: 'include',
      });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const ab = await res.arrayBuffer();
      const ct = res.headers.get('content-type') || '';
      return { bytes: Array.from(new Uint8Array(ab)), ct };
    }, href, referer);
    return {
      ok: true,
      buffer: Buffer.from(payload.bytes),
      contentType: payload.ct || '',
      source: 'page',
    };
  } catch (e) {
    // 2) Node-Fetch (CORS umgehen)
    try {
      const res = await fetch(href, {
        headers: {
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'Referer': referer,
          'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        }
      });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const buffer = Buffer.from(await res.arrayBuffer());
      const contentType = res.headers.get('content-type') || '';
      return { ok: true, buffer, contentType, source: 'node' };
    } catch (e2) {
      return { ok: false, error: e2 };
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PDF generation
async function makePdfFromImages() {
  const images = (await fs.readdir(pagesDir))
    .filter((n) => n.match(/^p\d+\.(webp|jpe?g|png)$/i))
    .sort();
  if (!images.length) {
    console.warn('⚠️  Keine Bildseiten gefunden – PDF wird nicht erzeugt.');
    return false;
  }

  const parts = images.map((n) => path.join(pagesDir, n));

  // Try ImageMagick "magick"
  const okMagick = await new Promise((resolve) => {
    const ps = spawn('magick', [...parts, pdfPath], { stdio: 'inherit' });
    ps.on('error', () => resolve(false));
    ps.on('exit', (code) => resolve(code === 0));
  });
  if (okMagick) {
    console.log(`✅ Fertig: ${path.relative(process.cwd(), pdfPath)}`);
    return true;
  }

  // Fallback: Ghostscript
  console.warn('ℹ️  Fallback auf Ghostscript …');
  const okGs = await new Promise((resolve) => {
    const ps = spawn(
      'gs',
      [
        '-dBATCH',
        '-dNOPAUSE',
        '-sDEVICE=pdfwrite',
        `-sOutputFile=${pdfPath}`,
        ...parts,
      ],
      { stdio: 'inherit' }
    );
    ps.on('error', () => resolve(false));
    ps.on('exit', (code) => resolve(code === 0));
  });
  if (okGs) {
    console.log(`✅ Fertig (gs): ${path.relative(process.cwd(), pdfPath)}`);
    return true;
  }

  console.warn('⚠️  Konnte kein PDF erzeugen (weder magick noch gs erfolgreich).');
  return false;
}

// ──────────────────────────────────────────────────────────────────────────────
// Main
(async () => {
  await ensureDirs();
  console.log(`🚀 Starte Download für Leaflet ${LEAFLET_ID}`);

  const browser = await puppeteer.launch({
    headless: !HEADFUL,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled',
    ],
  });

  let downloaded = 0;
  try {
    const page = await browser.newPage();
    await page.setUserAgent(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    );
    await page.setViewport({ width: 1366, height: 900, deviceScaleFactor: 1 });
    await page.setExtraHTTPHeaders({ 'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8' });
    await page.setBypassCSP(true);

    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });

    // Cookies akzeptieren
    try {
      const cookieBtn = await page.$x("//button[contains(., 'Akzeptieren') or contains(., 'Einverstanden') or contains(., 'Alle akzeptieren')]");
      if (cookieBtn.length) await cookieBtn[0].click().catch(() => {});
    } catch {}

    // Trigger Lazy-Load
    await page.evaluate(() => new Promise((r) => {
      let y = 0, max = 2000, step = 200;
      const iv = setInterval(() => {
        window.scrollBy(0, step);
        y += step;
        if (y >= max) { clearInterval(iv); r(); }
      }, 120);
    }));

    // Download loop
    const MAX_MISSES = 3;
    let consecutiveMisses = 0;

    for (let i = 0; i < MAX_PAGES; i++) {
      const fnBase = `p${String(i).padStart(3, '0')}`;

      // Skip if already downloaded
      const existing = (await fs.readdir(pagesDir)).find(
        (n) => n.startsWith(fnBase + '.') && n.match(/\.(png|jpe?g|webp)$/)
      );
      if (existing) {
        console.log(`⏭️  Seite ${i} existiert bereits, überspringe (${existing})`);
        downloaded++;
        consecutiveMisses = 0;
        continue;
      }

      console.log(`📄 Lade Seite ${i} ...`);
      const imgPageUrl = `${BASE_URL}/page/${i}`;
      await page.goto(imgPageUrl, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch(() => {});
      await sleep(DELAY);

      const result = await page.evaluate(() => {
        const pick = () => {
          const candidates = Array.from(document.querySelectorAll('img, source, picture img'));
          candidates.sort(
            (a, b) => (b.naturalWidth * b.naturalHeight) - (a.naturalWidth * a.naturalHeight)
          );
          for (const el of candidates) {
            const src = el.getAttribute('src') || el.getAttribute('data-src') || '';
            if (!src) continue;
            if (/leaflets\/.+\/(page|image)\//.test(src) || /\/images\//.test(src) || /cdn/.test(src)) {
              return src;
            }
          }
          return candidates[0]?.getAttribute('src') || candidates[0]?.getAttribute('data-src') || null;
        };
        return pick();
      });

      if (!result) {
        const html = await page.content().catch(() => '');
        const png = await page.screenshot({ fullPage: true }).catch(() => null);
        await saveDebug(i, html, png);
        console.warn(`❌ Kein Bild gefunden, Stop bei Seite ${i}`);
        consecutiveMisses++;
        if (consecutiveMisses >= MAX_MISSES) break;
        else continue;
      }

      const imgSrc = new URL(result, page.url()).href;

      // Sicheren Download mit CORS-Bypass
      const dl = await fetchImageSmart({ page, href: imgSrc, referer: page.url() });
      if (!dl.ok) {
        const html = await page.content().catch(() => '');
        const png = await page.screenshot({ fullPage: true }).catch(() => null);
        await saveDebug(i, html, png);
        console.warn(`❌ Fehler beim Laden von Seite ${i}: ${dl.error?.message || 'Unbekannt'}`);
        consecutiveMisses++;
        if (consecutiveMisses >= MAX_MISSES) break;
        continue;
      }

      const bytes = dl.buffer;
      const ct = dl.contentType || '';
      const ext = extFromContentType(ct);
      const fn = path.join(pagesDir, `${fnBase}${ext}`);

      await fs.writeFile(fn, bytes);

      const hash = sha1(bytes);
      const hashFile = path.join(pagesDir, `${fnBase}.sha1`);
      const prev = (await fs.pathExists(hashFile)) ? (await fs.readFile(hashFile, 'utf8')).trim() : null;
      await fs.writeFile(hashFile, hash);
      if (prev && prev === hash) console.warn(`⚠️  Seite ${i}: identisch zu vorherigem Hash – mögliches Duplikat.`);

      console.log(`✅ Seite ${i} gespeichert (${path.relative(process.cwd(), fn)})`);
      downloaded++;
      consecutiveMisses = 0;
      await sleep(DELAY);
    }
  } finally {
    await browser.close().catch(() => {});
  }

  if (!downloaded) {
    console.warn('❌ Keine Seiten geladen – PDF wird übersprungen.');
    process.exit(2);
  }

  console.log('🧩 Erstelle PDF …');
  await makePdfFromImages();
  console.log(`ℹ️ Insgesamt ${downloaded} Seiten heruntergeladen und als PDF gespeichert.`);
})();

// Ensure ESM module context
export {};