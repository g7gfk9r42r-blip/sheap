import fs from "fs/promises";
import path from "node:path";
import puppeteer from "puppeteer";

// ---------------------------- helpers ---------------------------------
function d(u) { try { return new URL(u).hostname; } catch { return ""; } }
function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

function looksLikeOffer(obj) {
  if (!obj || typeof obj !== "object") return false;
  const keys = Object.keys(obj).map(k => k.toLowerCase());
  const hasTitle = keys.some(k => /title|name|headline|productname/.test(k));
  const hasPrice = keys.some(k => /price|pricevalue|currentprice|price_from|pricefrom|priceamount|pricevaluefrom/.test(k));
  return hasTitle && hasPrice;
}

function* walk(o, seen = new WeakSet()) {
  if (!o || typeof o !== "object" || seen.has(o)) return;
  seen.add(o);
  if (Array.isArray(o)) {
    for (const x of o) yield* walk(x, seen);
  } else {
    yield o;
    for (const v of Object.values(o)) yield* walk(v, seen);
  }
}

function normalizeOffer(x) {
  const obj = x || {};
  const title = obj.title || obj.name || obj.headline || obj.productName || obj.product_title || null;
  const price = obj.price?.value ?? obj.currentPrice ?? obj.priceValue ?? obj.price_from ?? obj.priceFrom ?? obj.priceAmount ?? obj.priceValueFrom ?? null;
  const unit = obj.price?.unit ?? obj.unit ?? obj.priceUnit ?? null;
  const brand = obj.brand || obj.manufacturer || null;
  const image = obj.image?.url || obj.imageUrl || obj.image || null;
  const validFrom = obj.validFrom || obj.startDate || obj.valid_from || null;
  const validTo = obj.validTo || obj.endDate || obj.valid_to || null;
  return { title, price, unit, brand, image, validFrom, validTo, _raw: obj };
}

async function saveJSON(p, data) {
  await fs.mkdir(path.dirname(p), { recursive: true });
  await fs.writeFile(p, JSON.stringify(data, null, 2));
}

async function saveBuffer(p, buf) {
  await fs.mkdir(path.dirname(p), { recursive: true });
  await fs.writeFile(p, buf);
}

function firstRewePdfFromHtml(html) {
  const m = html.match(/https?:\/\/[^\s"'<>]+\.pdf/gi) || [];
  const candidates = m.filter(u => {
    const host = d(u);
    // only allow REWE PDF sources, avoid unrelated 'traces' or EU docs
    if (!/(\.|^)rewe\.(de|static)\b/i.test(host)) return false;
    // must be an offers/prospekt path
    if (!/(angebote|prospekt|wochenprospekt|handzettel|leaflet)/i.test(u)) return false;
    // exclude known non-prospekt PDFs
    if (/traces|certificate|eco|bio|sante|schutz/i.test(u)) return false;
    return true;
  });
  return candidates[0] || null;
}

async function clickConsent(page) {
  try {
    await sleep(800);
    // main document buttons
    const btns = await page.$x("//button[contains(., 'Zustimmen') or contains(., 'Akzeptieren') or contains(., 'Einverstanden') or contains(., 'Alle akzeptieren')]");
    if (btns.length) {
      await btns[0].click().catch(()=>{});
      await sleep(800);
    }
    await page.click("button[aria-label*='Zustimmen'], button[title*='Zustimmen']").catch(()=>{});

    // try iframes (CMP inside iframe)
    for (const f of page.frames()) {
      try {
        const h = await f.$x("//button[contains(., 'Zustimmen') or contains(., 'Akzeptieren') or contains(., 'Alle akzeptieren')]");
        if (h.length) { await h[0].click().catch(()=>{}); await sleep(800); }
      } catch {}
    }
  } catch {}
}

async function clickConsentDeep(page) {
  try {
    // common inline button first
    await clickConsent(page);
    // look for iframe-based CMPs
    const frames = page.frames();
    for (const f of frames) {
      try {
        const btn = await f.$x("//button[contains(., 'Zustimmen') or contains(., 'Akzeptieren') or contains(., 'Einverstanden')]");
        if (btn && btn.length) {
          await btn[0].click({ delay: 30 });
          await page.waitForTimeout(500);
          break;
        }
      } catch {}
    }
  } catch {}
}

async function clickOffersTab(page) {
  // Try to switch to "Angebote" / weekly offers tab if present
  const XPATHS = [
    "//a[contains(@role,'tab')][contains(., 'Angebote')]",
    "//button[contains(@role,'tab')][contains(., 'Angebote')]",
    "//a[contains(., 'Angebote')]",
    "//button[contains(., 'Angebote')]",
    "//a[contains(., 'Prospekt')]",
    "//button[contains(., 'Prospekt')]",
  ];
  for (const xp of XPATHS) {
    try {
      const els = await page.$x(xp);
      if (els.length) {
        await els[0].click({ delay: 40 });
        await sleep(800);
        return true;
      }
    } catch {}
  }
  return false;
}

async function clickLoadMore(page, rounds = 6) {
  // Try to reveal more items so that APIs fire
  const XPATHS = [
    "//button[contains(., 'Mehr anzeigen')]",
    "//button[contains(., 'Mehr laden')]",
    "//button[contains(., 'Weitere anzeigen')]",
  ];
  for (let i = 0; i < rounds; i++) {
    let clicked = false;
    for (const xp of XPATHS) {
      try {
        const els = await page.$x(xp);
        if (els.length) {
          await els[0].click({ delay: 40 });
          clicked = true;
          await sleep(700);
          break;
        }
      } catch {}
    }
    if (!clicked) break;
  }
}

// Capture JSON from network responses for rewe domains that look like offers
async function grabOffersFromNetwork(page, {timeoutMs = 15000, debugDir} = {}) {
  const jsonPayloads = [];
  function onResponse(resp) {
    try {
      const ct = (resp.headers()["content-type"] || "").toLowerCase();
      if (!/application\/json|ld\+json|text\/plain/.test(ct)) return;
      const url = resp.url();
      if (!/rewe\.(de|static)/i.test(d(url))) return;
      if (!/(offer|angebote|leaflet|promotion|promo|market|graphql|cms|content|bff|api)/i.test(url)) return;
      resp.json().then(data => jsonPayloads.push({ url, data })).catch(()=>{});
    } catch {}
  }
  page.on("response", onResponse);
  await sleep(timeoutMs);
  page.off("response", onResponse);

  // Always write debug files, even when empty
  if (debugDir) {
    const dump = jsonPayloads.map(p => ({ url: p.url, keys: Object.keys(p.data || {}) }));
    await saveJSON(path.join(debugDir, "network_index.json"), dump);
    await saveJSON(path.join(debugDir, "network_raw.json"), jsonPayloads.slice(0, 20));
  }
  const offers = [];
  for (const { data } of jsonPayloads) {
    for (const node of walk(data)) {
      if (looksLikeOffer(node)) offers.push(node);
    }
  }
  return offers;
}

// Parse from __NEXT_DATA__ / inline JSON
async function grabOffersFromDom(page, {debugDir} = {}) {
  let rawJson = null;
  try { rawJson = await page.$eval("#__NEXT_DATA__", el => el.textContent); } catch {}
  if (!rawJson) {
    try {
      const scripts = await page.$$eval('script[type="application/json"]', els => els.map(e => e.textContent || "").filter(Boolean));
      rawJson = scripts.find(s => s.length > 1000) || null;
    } catch {}
  }
  if (!rawJson) return [];

  try {
    const parsed = JSON.parse(rawJson);
    if (debugDir) await saveJSON(path.join(debugDir, "dom_raw.json"), parsed);

    if (debugDir) {
      try {
        const summary = Array.isArray(parsed)
          ? { type: "array", length: parsed.length }
          : { type: typeof parsed, keys: Object.keys(parsed || {}) };
        await saveJSON(path.join(debugDir, "dom_summary.json"), summary);
      } catch {}
    }

    const offers = [];
    for (const node of walk(parsed)) if (looksLikeOffer(node)) offers.push(node);
    return offers;
  } catch {
    return [];
  }
}

function isValidRewePdf(u) {
  try {
    const { hostname, pathname } = new URL(u);
    return /(rewe|cdn|static)\./i.test(hostname) &&
           /\.pdf$/i.test(pathname) &&
           /(prospekt|angebote|leaflet|wochenprospekt|handzettel)/i.test(pathname);
  } catch { return false; }
}

async function setMarketAndNavigate(page, marketId) {
  // if URL already canonical, keep it; else try to jump
  await page.evaluate((mid) => {
    try {
      localStorage.setItem('marketId', String(mid));
      localStorage.setItem('selectedMarketId', String(mid));
      localStorage.setItem('reweSelectedStoreId', String(mid));
    } catch {}
  }, marketId);
  await sleep(300);
}

// Try to jump to store-specific canonical offers URL if we only have ?market=...
async function maybeGoToCanonicalOffers(page, url, marketId) {
  // If the URL already contains a city/slug-style offers path, nothing to do.
  if (/\/angebote\/.+\/\d{5,}\/rewe-markt/i.test(url)) return;

  // Look for an offers link on the page that contains the market id
  try {
    const anchors = await page.$$eval('a[href*="/angebote/"]', as => as.map(a => a.getAttribute("href")));
    const cand = anchors.find(href => href && new RegExp(String(marketId)).test(href));
    if (cand) {
      const absolute = new URL(cand, page.url()).toString();
      await page.goto(absolute, { waitUntil: "domcontentloaded", timeout: 90000 });
      return;
    }
  } catch {}
}

// ------------------------------- main ----------------------------------
async function main() {
  const [, , url, outDir] = process.argv;
  if (!url || !outDir) {
    console.error("Usage: node tools/rewe/fetch_rewe_offers.mjs <offers_url_with_market> <out_dir>");
  process.exit(1);
}

  const absOut = path.resolve(outDir);
  await fs.mkdir(absOut, { recursive: true });
  const debugDir = path.join(absOut, "__debug");
  await fs.mkdir(debugDir, { recursive: true });

  await saveJSON(path.join(debugDir, "index.json"), { startedAt: new Date().toISOString(), inputUrl: url });

  const m = url.match(/market=(\d{5,})/);
  const marketId = m ? m[1] : null;

  const browser = await puppeteer.launch({
    headless: "new",
    args: [
      "--no-sandbox","--disable-setuid-sandbox","--lang=de-DE,de",
      "--disable-blink-features=AutomationControlled"
    ],
    defaultViewport: { width: 1600, height: 1400, deviceScaleFactor: 2.5 },
  });

  let page = null;
  try {
    page = await browser.newPage();
    await page.setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Safari/537.36");
    await page.setExtraHTTPHeaders({ "Accept-Language": "de-DE,de;q=0.9,en;q=0.8" });
    // anti-automation noise minimal halten
    await page.evaluateOnNewDocument(() => {
      Object.defineProperty(navigator, "webdriver", { get: () => false });
    });

    // 1) Open and accept consent
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 90000 });
    await clickConsent(page);

    // 2) Bind market + maybe jump to canonical store offers page
    if (marketId) {
      await setMarketAndNavigate(page, marketId);
      await maybeGoToCanonicalOffers(page, url, marketId);
    }

    // try to click an "Angebote"/"Prospekt" tab if present
    try {
      const candidates = [
        "//a[contains(., 'Angebote')]",
        "//button[contains(., 'Angebote')]",
        "//a[contains(., 'Prospekt')]",
        "//button[contains(., 'Prospekt')]",
        "//a[contains(., 'Handzettel')]",
      ];
      for (const xp of candidates) {
        const els = await page.$x(xp);
        if (els.length) { await els[0].click().catch(()=>{}); await sleep(1200); break; }
      }
    } catch {}

    await clickOffersTab(page).catch(()=>{});
    for (let i = 0; i < 6; i++) {
      await page.evaluate(() => window.scrollBy(0, window.innerHeight));
      await sleep(500);
    }
    await clickLoadMore(page, 8);
    // wait for network idle to let API/BFF calls finish
    try { await page.waitForNetworkIdle({ idleTime: 1500, timeout: 20000 }); } catch {}

    // 3) De-blur + Lazy-Load forcieren
    await page.addStyleTag({content: `
      * { filter: none !important; -webkit-filter: none !important; }
      [style*="filter"] { filter: none !important; -webkit-filter: none !important; }
      img[loading], img[decoding] { loading: eager !important; decoding: sync !important; }
    `});

    // ensure imgs actually load
    await page.evaluate(() => {
      document.querySelectorAll('img').forEach(img => {
        if (img.dataset && (img.dataset.src || img.dataset.lazySrc)) {
          img.src = img.dataset.src || img.dataset.lazySrc;
        }
      });
    });

    // langsam scrollen, damit IntersectionObserver feuern
    for (let i = 0; i < 4; i++) {
      await page.evaluate(() => window.scrollBy(0, window.innerHeight));
      await sleep(600);
    }
    await sleep(1200);
    await page.waitForNetworkIdle({ idleTime: 1200, timeout: 15000 }).catch(()=>{});

    // 4) Grab offers from network first; fall back to DOM
    let offers = await grabOffersFromNetwork(page, { timeoutMs: 12000, debugDir });
    if (!offers.length) {
      // try one more scroll round and wait
      for (let i = 0; i < 6; i++) {
        await page.evaluate(() => window.scrollBy(0, window.innerHeight));
        await sleep(600);
      }
      await page.waitForNetworkIdle({ idleTime: 1200, timeout: 15000 }).catch(()=>{});
      offers = await grabOffersFromNetwork(page, { timeoutMs: 12000, debugDir });
    }
    if (!offers.length) {
      offers = await grabOffersFromDom(page, { debugDir });
    }

    // 5) Normalize and save
    const normalized = offers.map(normalizeOffer);
    await saveJSON(path.join(absOut, "offers.json"), normalized);
    console.log(`✅ offers.json gespeichert (${normalized.length} Treffer)`);

    // 7) Try to find a strict REWE leaflet pdf
    const html = await page.content();
    const pdfUrl = (firstRewePdfFromHtml(html) || "");
    if (pdfUrl && isValidRewePdf(pdfUrl)) {
      try {
        const buf = await page.evaluate(async (u) => {
          const r = await fetch(u, { credentials: "omit" });
          const a = await r.arrayBuffer();
          return Array.from(new Uint8Array(a));
        }, pdfUrl);
        const pdfPath = path.join(absOut, "leaflet.pdf");
        await saveBuffer(pdfPath, Buffer.from(buf));
        const kb = Math.max(1, Math.round(buf.length / 1024));
        console.log(`✅ leaflet.pdf gespeichert (${kb} KB)`);
      } catch {
        console.log("⚠️  PDF-Link gefunden, Download blockiert – ignoriere PDF.");
      }
    } else {
      console.log("ℹ️  Kein eindeutiges REWE-Prospekt-PDF im HTML gefunden (API/HTML-Modus reicht).");
    }
  } finally {
    // Debug: final DOM & Screenshot ablegen
    try {
      if (debugDir && page) {
        await fs.writeFile(path.join(debugDir, "page.html"), await page.content());
        await page.screenshot({ path: path.join(debugDir, "page.png"), fullPage: true, captureBeyondViewport: true, fromSurface: true }).catch(()=>{});
        const hasNext = await page.$("#__NEXT_DATA__").catch(()=>null);
        await saveJSON(path.join(debugDir, "dom_summary.json"), { hasNextData: !!hasNext }).catch(()=>{});
        await saveJSON(path.join(debugDir, "final.json"), { finishedAt: new Date().toISOString() });
      }
    } catch {}
    await browser.close();
  }
}

main().catch(e => { console.error(e); process.exit(1); });