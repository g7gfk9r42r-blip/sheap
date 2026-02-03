import fs from "fs";
import path from "path";
import fse from "fs-extra";
import crypto from "crypto";
import puppeteer from "puppeteer";

// ----- CLI -----
const [, , START_URL, OUT_DIR, ...rest] = process.argv;
if (!START_URL || !OUT_DIR) {
  console.error("Usage: node download_lidl_viewer.mjs <viewer-url> <out-dir> [--max N] [--delay MS] [--headful] [--debug] [--pager] [--pager-strict] [--start N]");
  process.exit(1);
}
const opts = { max: 120, delay: 250, headful: false, debug: false, pager: false, pagerStrict: false, start: null, retries: 3, dpr: 2, vw: 1920, vh: 2200, force: false, to: null, freshPerPage: false, incognito: false };
for (let i = 0; i < rest.length; i++) {
  const k = rest[i];
  if (k === "--headful") opts.headful = true;
  else if (k === "--debug") opts.debug = true;
  else if (k === "--max") opts.max = parseInt(rest[++i] || "120", 10);
  else if (k === "--delay") opts.delay = parseInt(rest[++i] || "250", 10);
  else if (k === "--pager") opts.pager = true;
  else if (k === "--pager-strict") opts.pagerStrict = true;
  else if (k === "--start") opts.start = parseInt(rest[++i] || "1", 10); // Viewer-Seitenzahl (1-basiert)
  else if (k === "--retries") opts.retries = parseInt(rest[++i] || "3", 10);
  else if (k === "--dpr") opts.dpr = parseInt(rest[++i] || "2", 10);
  else if (k === "--vw")  opts.vw  = parseInt(rest[++i] || "1920", 10);
  else if (k === "--vh")  opts.vh  = parseInt(rest[++i] || "2200", 10);
  else if (k === "--force") opts.force = true;
  else if (k === "--to") opts.to = parseInt(rest[++i] || null, 10);
  else if (k === "--fresh-per-page") opts.freshPerPage = true;
  else if (k === "--incognito") opts.incognito = true;
}

// ----- Helpers -----
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ensureDir = async (dir) => fse.ensureDir(dir);
const zero = (n) => String(n).padStart(3, "0");

function cacheBust(u) {
  return u + (u.includes("?") ? "&" : "?") + "nocache=" + Date.now();
}

async function safeExists(p) { try { await fse.access(p); return true; } catch { return false; } }

async function nextImageIndex(pagesDir) {
  await ensureDir(pagesDir);
  const files = (await fse.readdir(pagesDir)).filter(f => /^p\d{3}\.png$/i.test(f));
  if (files.length === 0) return 0;
  const max = files.map(f => parseInt(f.slice(1,4),10)).reduce((a,b)=>Math.max(a,b), 0);
  return max + 1;
}

async function clickIfExists(page, selectorOrText) {
  try {
    if (selectorOrText.startsWith("//")) {
      const el = await page.$x(selectorOrText);
      if (el && el[0]) { await el[0].click({ delay: 50 }); return true; }
      return false;
    } else {
      const el = await page.$(selectorOrText);
      if (el) { await el.click({ delay: 50 }); return true; }
      return false;
    }
  } catch { return false; }
}

async function tryConsent(page) {
  const candidates = [
    'button#onetrust-accept-btn-handler',
    'button[aria-label="Einverstanden"]',
    'button[aria-label="Akzeptieren"]',
    '//button[contains(., "Akzeptieren")]',
    '//button[contains(., "Zustimmen")]',
  ];
  for (const c of candidates) {
    const ok = await clickIfExists(page, c);
    if (ok) { await sleep(500); if (opts.debug) console.log("✅ Consent geklickt:", c); break; }
  }
}

async function humanize(page) {
  await page.setUserAgent(
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
  );
  await page.evaluateOnNewDocument(() => {
    Object.defineProperty(navigator, "webdriver", { get: () => false });
  });
  // Removed hardcoded viewport to respect CLI options
}

async function hideOverlays(page) {
  try {
    await page.addStyleTag({ content: `
      #onetrust-banner-sdk,
      #onetrust-consent-sdk,
      [id*="cookie" i],
      [class*="cookie" i],
      .ot-sdk-container,
      .ot-sdk-row,
      .ot-sdk-three,
      .ot-sdk-six,
      .consent,
      .cookie-banner,
      .cookie,
      .banner,
      [role="dialog"][aria-label*="Cookie" i] {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
      }
    `});
  } catch {}
}

async function waitForVisibleContent(page, timeout = 12000) {
  // Warte auf sichtbare Bilder/Canvas/Text – verhindert „weiße“ Screenshots
  const sels = [
    'img[src^="blob:"], img[src*="flyer"], img[decoding], canvas',
    '[data-testid="flyer-page"] img, [data-testid="flyer-page"] canvas',
    'main img, main canvas'
  ];
  const start = Date.now();
  while (Date.now() - start < timeout) {
    for (const sel of sels) {
      const ok = await page.$eval(sel, el => {
        const r = el.getBoundingClientRect();
        return r.width > 30 && r.height > 30 && window.getComputedStyle(el).visibility !== 'hidden';
      }).catch(() => false);
      if (ok) return true;
    }
    await sleep(300);
  }
  return false;
}

async function getFlyerContainer(page) {
  const candidates = [
    '[data-testid="flyer-page"]',
    '[data-testid="flyer-canvas"]',
    '[data-testid="page"]',
    'div[aria-label*="Seite"]',
    '.swiper-slide-active [data-testid="flyer-page"]'
  ];
  for (const sel of candidates) {
    const el = await page.$(sel);
    if (el) return el;
  }
  return null;
}

async function ensureOutDirs(baseOut) {
  const pagesDir = path.join(baseOut, "pages");
  await ensureDir(baseOut);
  await ensureDir(pagesDir);
  return { pagesDir };
}

async function makeFreshPage(browserOrCtx) {
  const page = await browserOrCtx.newPage();
  try { await page.setCacheEnabled(false); } catch {}
  page.setDefaultNavigationTimeout(120000);
  await humanize(page);
  // leichte UA-Variation pro Tab, um Heuristiken zu umgehen
  try {
    const ua = await page.evaluate(() => navigator.userAgent);
    const salt = Math.floor(Math.random() * 1000);
    await page.setUserAgent(ua + " " + salt);
  } catch {}
  try {
    await page.setViewport({ width: opts.vw, height: opts.vh, deviceScaleFactor: opts.dpr });
  } catch {}
  return page;
}

// ---------- STRICT PAGER (URL /page/{n}) ----------
async function pagerByUrl(browserOrCtx, page, startUrl, pagesDir, maxPages, delay, debug) {
  if (debug) console.log("🧭 Starte STRICT-Pager (URL page/{n}, container screenshot, force/TO unterstützt, fresh-per-page:", !!opts.freshPerPage, ")");

  let pg = page;
  if (opts.freshPerPage) {
    try { await pg.close(); } catch {}
    pg = await makeFreshPage(browserOrCtx);
  }

  const base = startUrl.replace(/\/page\/\d+(?!\d)/, "/page/{n}");

  // Auto-Resume: existierende PNGs bestimmen
  let nextIdx = await nextImageIndex(pagesDir); // 0-basiert für pNNN.png
  // Mapping: Viewer-Seite (1-basiert) = nextIdx + 1, außer --start wurde gesetzt
  let startPage = opts.start && Number.isInteger(opts.start) && opts.start > 0 ? opts.start : (nextIdx + 1);

  const endPage = (opts.to && Number.isInteger(opts.to) && opts.to >= startPage)
    ? opts.to
    : (startPage + maxPages - 1);

  if (debug) console.log(`🔁 Resume: nextIdx=${nextIdx} ⇒ starte bei Viewer-Seite ${startPage}`);

  let lastHash = null;

  for (let viewerPage = startPage; viewerPage <= endPage; viewerPage++) {
    const url = base.replace("{n}", String(viewerPage));
    if (opts.freshPerPage) {
      try { await pg.close(); } catch {}
      pg = await makeFreshPage(browserOrCtx);
    }
    if (debug) console.log("➡️  Öffne Seite", viewerPage, url);

    let success = false;
    for (let attempt = 1; attempt <= (opts.retries || 3); attempt++) {
      let resp;
      try {
        const navUrl = cacheBust(url);
        resp = await pg.goto(navUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
      } catch (e) {
        const needsFresh = e && /Target closed|detached Frame/i.test(String(e.message || e));
        if (needsFresh) {
          if (debug) console.log("♻️  Neuer Tab wegen Target closed/detached Frame …");
          try { await pg.close(); } catch {}
          pg = await makeFreshPage(browserOrCtx);
          continue; // retry this attempt with fresh page
        }
        if (debug) console.log(`⚠️  Nav-Fehler (Versuch ${attempt}) –`, e.message);
      }
      if (!resp) {
        await sleep(300 + attempt * 200);
        continue;
      }
      const status = resp.status();
      if (status >= 400) { if (debug) console.log("⚠️  HTTP", status, "– Stop"); break; }

      if (viewerPage === startPage && attempt === 1) {
        await tryConsent(pg);
        try { await pg.waitForNetworkIdle({ idleTime: 1200, timeout: 20000 }); } catch {}
        await hideOverlays(pg);
      }
      // Ensure overlays are hidden on every attempt
      await hideOverlays(pg);

      // zusätzliche Anti-Blank-Wartezeit und Scroll
      await sleep(Math.max(300, delay));
      try { await waitForVisibleContent(pg, 15000); } catch {}
      try { await pg.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 3)); } catch {}
      await sleep(150 + attempt * 150);

      const fileIdx = viewerPage - 1;
      const outPng = path.join(pagesDir, `p${zero(fileIdx)}.png`);

      if (await safeExists(outPng) && !opts.force) {
        if (debug) console.log(`⏭️  existiert bereits → ${path.basename(outPng)}`);
        success = true;
        break; // Datei schon da → zur nächsten Seite
      }

      let buf;
      try {
        // Prefer the flyer container for higher DPI and no cookie banners
        const container = await getFlyerContainer(pg);
        if (container) {
          try { await container.scrollIntoViewIfNeeded(); } catch {}
          buf = await container.screenshot({ type: "png" });
        } else {
          buf = await pg.screenshot({ type: "png", fullPage: true });
        }
      } catch (e) {
        const needsFresh = e && /Target closed|detached Frame/i.test(String(e.message || e));
        if (needsFresh) {
          if (debug) console.log("♻️  Neuer Tab wegen Target closed/detached Frame …");
          try { await pg.close(); } catch {}
          pg = await makeFreshPage(browserOrCtx);
          continue; // retry this attempt with fresh page
        }
        if (debug) console.log(`⚠️  Screenshot-Fehler (Versuch ${attempt}) –`, e.message);
        await sleep(250 + attempt * 200);
        continue;
      }

      // Blank/Identisch-Heuristik
      const curHash = crypto.createHash("sha1").update(buf).digest("hex");
      if (looksBlankPng(buf) || curHash === lastHash) {
        if (debug) console.log(`⚠️  leer/identisch (hash) – Versuch ${attempt}`);
        await sleep(250 + attempt * 250);
        try { await pg.reload({ waitUntil: "domcontentloaded", timeout: 60000 }); } catch {}
        await hideOverlays(pg);
        try { await waitForVisibleContent(pg, 8000); } catch {}
        lastHash = curHash; // update to avoid infinite loop on truly identical pages
        continue;
      }

      // gut → speichern
      await fse.writeFile(outPng, buf);
      console.log(`✅ Seite ${viewerPage} gespeichert (${outPng})`);
      lastHash = curHash;
      success = true;

      if (opts.freshPerPage) {
        try { await pg.close(); } catch {}
        pg = await makeFreshPage(browserOrCtx);
      }

      break;
    }

    if (!success) {
      if (debug) console.log(`🛑  Seite ${viewerPage}: alle Versuche fehlgeschlagen – Stop.`);
      break;
    }

    await sleep(Math.max(300, delay));
  }
}

// ---------- Pager per Button/Keys (Fallback) ----------
async function clickAny(page, selectors) {
  for (const sel of selectors) {
    try {
      if (sel.startsWith("//")) {
        const [el] = await page.$x(sel);
        if (el) { await el.click({ delay: 50 }); return true; }
      } else {
        const el = await page.$(sel);
        if (el) { await el.click({ delay: 50 }); return true; }
      }
    } catch {}
  }
  return false;
}

async function paginateAndCapture(page, pagesDir, maxPages, delay, debug) {
  if (debug) console.log("🧭 Pager-Fallback (Next-Button/Keys)");

  const nextSelectors = [
    'button[aria-label="Nächste Seite"]',
    '[data-testid="next-page"]',
    'button[title="Weiter"]',
    '//button[contains(., "Weiter")]',
    '//button[contains(., "Nächste")]'
  ];

  let nextIdx = await nextImageIndex(pagesDir); // 0-basiert
  let lastHash = null, dupCount = 0;

  for (let i = 0; i < maxPages; i++) {
    await hideOverlays(page);
    await sleep(Math.max(250, delay));
    const container = await getFlyerContainer(page);

    let buf;
    if (!container) {
      if (debug) console.log(`⚠️  kein Container – FullPage`);
      buf = await page.screenshot({ type: 'png', fullPage: true });
    } else {
      try { await container.scrollIntoViewIfNeeded(); } catch {}
      await sleep(120);
      buf = await container.screenshot({ type: 'png' });
    }

    const hash = crypto.createHash("sha1").update(buf).digest("hex");
    if (hash === lastHash) {
      dupCount += 1;
      if (dupCount >= 2) { if (debug) console.log("🛑  Wiederholt identisch – Stop."); break; }
    } else { dupCount = 0; lastHash = hash; }

    const p = path.join(pagesDir, `p${zero(nextIdx)}.png`);
    if (await safeExists(p)) { if (debug) console.log(`⏭️  existiert bereits → ${path.basename(p)}`); }
    else { await fse.writeFile(p, buf); console.log(`✅ gespeichert (${p})`); }
    nextIdx += 1;

    const clicked = await clickAny(page, nextSelectors);
    if (!clicked) {
      try { await page.keyboard.press('ArrowRight'); } catch {}
      await sleep(120);
      try { await page.keyboard.press('PageDown'); } catch {}
      await sleep(Math.max(300, delay));
    }
  }
}

// ---------- Main ----------
async function run() {
  const outDir = path.resolve(OUT_DIR);
  const { pagesDir } = await ensureOutDirs(outDir);

  const browser = await puppeteer.launch({
    headless: !opts.headful ? "new" : false,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-blink-features=AutomationControlled",
      "--lang=de-DE,de",
      "--window-size=1366,860",
    ],
    defaultViewport: { width: opts.vw, height: opts.vh, deviceScaleFactor: opts.dpr },
  });

  // optional incognito context
  const browserOrCtx = opts.incognito ? await browser.createIncognitoBrowserContext() : browser;

  try {
    const page = await makeFreshPage(browserOrCtx);

    if (opts.debug) console.log("FLAGS:", JSON.stringify(opts));

    if (opts.pagerStrict) {
      await pagerByUrl(browserOrCtx, page, START_URL, pagesDir, opts.max, opts.delay, opts.debug);
      console.log("🧩 Fertig (STRICT). PNGs in:", pagesDir);
      return;
    }

    if (opts.pager) {
      await page.goto(START_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await hideOverlays(page);
      await tryConsent(page);
      try { await page.waitForNetworkIdle({ idleTime: 1200, timeout: 20000 }); } catch {}
      await hideOverlays(page);
      await tryConsent(page);
      await paginateAndCapture(page, pagesDir, opts.max, opts.delay, opts.debug);
      console.log("🧩 Fertig. PNGs in:", pagesDir);
      return;
    }

    // Normaler Modus: versuchen, viele Container zu sichten – sonst Fallback
    if (opts.debug) console.log("🌐 Öffne:", START_URL);
    await page.goto(START_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
    await hideOverlays(page);
    await tryConsent(page);
    try { await page.waitForNetworkIdle({ idleTime: 1200, timeout: 20000 }); } catch {}
    await hideOverlays(page);
    await tryConsent(page);

    const handles = await page.$$('[data-testid="flyer-page"]');
    if (handles.length === 0) {
      if (opts.debug) console.log("⚠️  Keine Container – Pager-Fallback");
      await paginateAndCapture(page, pagesDir, opts.max, opts.delay, opts.debug);
      console.log("🧩 Fertig. PNGs in:", pagesDir);
      return;
    }

    // Wenn Container da sind: Screenshot je Container (mit Resume)
    let nextIdx = await nextImageIndex(pagesDir);
    const max = Math.min(handles.length, opts.max);
    for (let i = 0; i < max; i++) {
      const handle = handles[i];
      try { await handle.scrollIntoViewIfNeeded(); } catch {}
      await sleep(opts.delay);
      const p = path.join(pagesDir, `p${zero(nextIdx)}.png`);
      if (await safeExists(p)) { if (opts.debug) console.log(`⏭️  existiert bereits → ${path.basename(p)}`); }
      else {
        await handle.screenshot({ path: p, type: "png" });
        console.log(`✅ gespeichert (${p})`);
      }
      nextIdx += 1;
      await sleep(opts.delay);
    }

    console.log("🧩 Fertig. PNGs in:", pagesDir);
  } catch (err) {
    console.error("❌ Fehler:", err.message);
    if (opts.debug) console.error(err);
  } finally {
    await browser.close();
  }
}

function looksBlankPng(buf) {
  // Heuristik: sehr kleine PNGs sind oft weiße/Placeholder-Screenshots
  if (!buf || buf.length < 80000) return true; // ~80 KB Schwelle
  return false;
}

run();