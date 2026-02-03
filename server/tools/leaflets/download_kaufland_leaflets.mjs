import fs from 'fs-extra';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import puppeteer from 'puppeteer';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ──────────────────────────────────────────────────────────────
// CLI args
const argv = process.argv.slice(2);
if (argv.length < 2) {
  console.error('Usage: node download_marktguru_leaflet.mjs <LEAFLET_ID> <OUT_DIR> [--max 300] [--delay 250] [--headful] [--debug]');
  process.exit(1);
}
const LEAFLET_ID = String(argv[0]).trim();
const OUT_DIR = path.resolve(argv[1]);
const MAX_PAGES = Number((argv.includes('--max') ? argv[argv.indexOf('--max') + 1] : 300)) || 300;
const DELAY = Number((argv.includes('--delay') ? argv[argv.indexOf('--delay') + 1] : 300)) || 300;
const HEADFUL = argv.includes('--headful');
const DEBUG = argv.includes('--debug');

const BASE_URL = `https://www.marktguru.de/leaflets/${LEAFLET_ID}`;
const pagesDir = path.join(OUT_DIR, 'pages');
const pdfPath = path.join(OUT_DIR, `leaflet_${LEAFLET_ID}.pdf`);

// ──────────────────────────────────────────────────────────────
// Helpers
function sha1(buf) {
  return crypto.createHash('sha1').update(buf).digest('hex');
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function ensureDirs() {
  await fs.ensureDir(OUT_DIR);
  await fs.ensureDir(pagesDir);
}

function extFromContentType(ct) {
  if (!ct) return '.img';
  const t = ct.toLowerCase();
  if (t.includes('image/webp')) return '.webp';
  if (t.includes('image/jpeg')) return '.jpg';
  if (t.includes('image/png')) return '.png';
  return '.img';
}

function extFromUrl(urlStr) {
  try {
    const u = new URL(urlStr);
    const m = u.pathname.toLowerCase().match(/\.(webp|jpe?g|png)(?:$|\?)/);
    return m ? `.${m[1].replace('jpeg','jpg')}` : '.img';
  } catch {
    return '.img';
  }
}

function magicExtFromBuffer(buf) {
  if (!buf || buf.length < 12) return '.img';
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) return '.png';
  // JPEG: FF D8
  if (buf[0] === 0xFF && buf[1] === 0xD8) return '.jpg';
  // WEBP: RIFF .... WEBP
  if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 && buf.slice(8,12).toString() === 'WEBP') return '.webp';
  return '.img';
}

async function saveDebug(pageIndex, html, screenshotBuf) {
  if (!DEBUG) return;
  const dbgDir = path.join(OUT_DIR, 'debug');
  await fs.ensureDir(dbgDir);
  if (html) await fs.writeFile(path.join(dbgDir, `page_${String(pageIndex).padStart(3, '0')}.html`), html, 'utf8');
  if (screenshotBuf) await fs.writeFile(path.join(dbgDir, `page_${String(pageIndex).padStart(3, '0')}.png`), screenshotBuf);
}

async function fetchImageSmart({ href, referer }) {
  try {
    const res = await fetch(href, {
      headers: {
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': referer,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127 Safari/537.36',
        'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const arrayBuf = await res.arrayBuffer();
    const buffer = Buffer.from(arrayBuf);
    const ct = res.headers.get('content-type') || '';
    return { ok: true, buffer, contentType: ct };
  } catch (e) {
    return { ok: false, error: e };
  }
}

async function fixImgExtensions() {
  const files = (await fs.readdir(pagesDir)).filter((n) => n.endsWith('.img'));
  for (const name of files) {
    const full = path.join(pagesDir, name);
    const buf = await fs.readFile(full);
    const guessed = magicExtFromBuffer(buf);
    const target = full.replace(/\.img$/, guessed === '.img' ? '.webp' : guessed);
    if (target !== full) {
      await fs.move(full, target, { overwrite: true });
    }
  }
}

async function makePdfFromImages() {
  // First, rename any lingering .img files by magic sniffing
  await fixImgExtensions();

  const images = (await fs.readdir(pagesDir))
    .filter((n) => n.match(/^p\d+\.(webp|jpe?g|png)$/i))
    .sort();
  if (!images.length) {
    console.warn('⚠️  Keine Bildseiten gefunden – PDF wird nicht erzeugt.');
    return false;
  }

  const parts = images.map((n) => path.join(pagesDir, n));
  const okMagick = await new Promise((resolve) => {
    const ps = spawn('magick', [...parts, pdfPath], { stdio: 'inherit' });
    ps.on('error', () => resolve(false));
    ps.on('exit', (code) => resolve(code === 0));
  });
  if (okMagick) {
    console.log(`✅ Fertig: ${path.relative(process.cwd(), pdfPath)}`);
    return true;
  }

  console.warn('ℹ️  Fallback auf Ghostscript …');
  const okGs = await new Promise((resolve) => {
    const ps = spawn('gs', ['-dBATCH','-dNOPAUSE','-sDEVICE=pdfwrite',`-sOutputFile=${pdfPath}`,...parts], { stdio: 'inherit' });
    ps.on('error', () => resolve(false));
    ps.on('exit', (code) => resolve(code === 0));
  });
  if (okGs) {
    console.log(`✅ Fertig (gs): ${path.relative(process.cwd(), pdfPath)}`);
    return true;
  }
  console.warn('⚠️  Konnte kein PDF erzeugen.');
  return false;
}

// ──────────────────────────────────────────────────────────────
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
    const basePage = await browser.newPage();
    await basePage.setViewport({ width: 1280, height: 900, deviceScaleFactor: 1 });
    await basePage.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });

    // Try to accept cookies once
    try {
      const cookieBtn = await basePage.$x("//button[contains(., 'Akzeptieren') or contains(., 'Einverstanden') or contains(., 'Zustimmen')]");
      if (cookieBtn.length) await cookieBtn[0].click().catch(() => {});
    } catch {}

    for (let i = 0; i < MAX_PAGES; i++) {
      const fnBase = `p${String(i).padStart(3, '0')}`;
      const existing = (await fs.readdir(pagesDir)).find((n) => n.startsWith(fnBase + '.') && n.match(/\.(png|jpe?g|webp)$/));
      if (existing) {
        console.log(`⏭️  Seite ${i} existiert bereits, überspringe (${existing})`);
        downloaded++;
        continue;
      }

      let success = false;
      for (let attempt = 1; attempt <= 3; attempt++) {
        console.log(`📄 Lade Seite ${i} (Versuch ${attempt}/3) ...`);
        const page = await browser.newPage();
        try {
          await page.goto(`${BASE_URL}/page/${i}`, { waitUntil: 'domcontentloaded', timeout: 60000 });
          // wait a bit for image lazy-loading
          await page.waitForSelector('img', { timeout: 15000 }).catch(() => {});
          await sleep(DELAY);

          const imgSrc = await page.evaluate(() => {
            const imgs = Array.from(document.querySelectorAll('picture source, picture img, img'));
            // prefer largest by clientWidth*clientHeight
            const withSize = imgs.map(el => ({ el, w: el.naturalWidth || el.width || 0, h: el.naturalHeight || el.height || 0 }));
            withSize.sort((a,b) => (b.w*b.h) - (a.w*a.h));
            const el = withSize[0]?.el;
            if (!el) return null;
            const cand = el.getAttribute('srcset') || el.getAttribute('src') || el.getAttribute('data-src');
            const src = (cand || '').split(',').map(s=>s.trim().split(' ')[0]).filter(Boolean)[0];
            return src ? new URL(src, location.href).href : null;
          });

          if (!imgSrc) throw new Error('Kein Bild gefunden');

          const dl = await fetchImageSmart({ href: imgSrc, referer: page.url() });
          if (!dl.ok) throw dl.error;

          let ext = extFromContentType(dl.contentType);
          if (ext === '.img') ext = extFromUrl(imgSrc);
          if (ext === '.img') ext = magicExtFromBuffer(dl.buffer);
          if (ext === '.img') ext = '.webp'; // final fallback

          const fn = path.join(pagesDir, `${fnBase}${ext}`);
          await fs.writeFile(fn, dl.buffer);
          console.log(`✅ Seite ${i} gespeichert (${fn})`);
          success = true;
          downloaded++;
          await page.close();
          break;
        } catch (e) {
          console.warn(`⚠️  Fehler bei Seite ${i}, Versuch ${attempt}: ${e.message}`);
          await page.close().catch(() => {});
          await sleep(1000 * attempt);
        }
      }

      if (!success) {
        console.warn(`❌ Seite ${i} nach 3 Versuchen fehlgeschlagen – breche ab.`);
        break;
      }
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
  console.log(`ℹ️  Insgesamt ${downloaded} Seiten heruntergeladen und als PDF gespeichert.`);
})();

export {};