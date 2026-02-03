#!/usr/bin/env node
/**
 * grab_pdf_from_viewer.mjs
 * Öffnet eine Prospekt-Viewer-URL, horcht auf Responses und speichert echte PDFs.
 *
 * Usage:
 *   node grab_pdf_from_viewer.mjs <viewer_url> <outfile.pdf> [--headful] [--wait 5000]
 */
import fs from "fs/promises";
import path from "node:path";
import fse from "fs-extra";
import puppeteer from "puppeteer";

const argv = process.argv.slice(2);
if (argv.length < 2) {
  console.error("Usage: node grab_pdf_from_viewer.mjs <viewer_url> <outfile.pdf> [--headful] [--wait 5000]");
  process.exit(1);
}
let VIEW_URL = argv[0];
let OUTFILE = argv[1];
let HEADFUL = argv.includes("--headful");
let WAIT = 5000;
const wIdx = argv.indexOf("--wait");
if (wIdx >= 0 && argv[wIdx+1]) WAIT = parseInt(argv[wIdx+1], 10) || 5000;

const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36";

const PDF_HINTS = [
  /\.pdf(\?|$)/i,
  /\/leaflets\/pdfs\//i,        // Lidl-ähnliche Pfade
  /\/prospekt.*\.pdf/i,
  /\/flyer.*\.pdf/i
];

function looksLikePdf(resp) {
  const url = resp.url();
  const ct = (resp.headers()["content-type"] || "").toLowerCase();
  if (ct.includes("application/pdf")) return true;
  return PDF_HINTS.some(rx => rx.test(url));
}

(async () => {
  await fse.ensureDir(path.dirname(path.resolve(OUTFILE)));

  const browser = await puppeteer.launch({
    headless: HEADFUL ? false : "new",
    args: [
      "--no-sandbox","--disable-setuid-sandbox","--disable-dev-shm-usage",
      "--lang=de-DE,de","--disable-blink-features=AutomationControlled"
    ],
    defaultViewport: { width: 1440, height: 1000, deviceScaleFactor: 2 },
  });

  let saved = false;
  try {
    const page = await browser.newPage();
    await page.setUserAgent(UA);
    await page.setExtraHTTPHeaders({ "Accept-Language":"de-DE,de;q=0.9,en;q=0.8" });
    await page.evaluateOnNewDocument(() => {
      Object.defineProperty(navigator, "webdriver", { get: () => false });
    });

    // Cookie-/Consent-Overlays hart verstecken
    await page.addStyleTag({ content: `
      [id*="cookie" i],[class*="cookie" i],[class*="consent" i],[id*="consent" i],
      [role="dialog"][aria-label*="cookie" i], .onetrust-pc-sdk, #onetrust-consent-sdk,
      #cookie-banner, .cookie-banner { display:none !important; opacity:0 !important; pointer-events:none !important; height:0 !important; }
    `});

    // Response-Sniffer
    page.on("response", async (resp) => {
      try {
        if (saved) return;
        if (!looksLikePdf(resp)) return;

        const buf = await resp.buffer();
        if (!buf || buf.length < 1000) return; // zu klein/leer

        await fs.writeFile(OUTFILE, buf);
        saved = true;
        const kb = Math.round(buf.length/1024);
        console.log(`✅ Echte PDF gespeichert: ${OUTFILE} (${kb} KB) ← ${resp.url()}`);
      } catch { /* ignore */ }
    });

    console.log(`🌐 Öffne Viewer: ${VIEW_URL}`);
    await page.goto(VIEW_URL, { waitUntil: "domcontentloaded", timeout: 60000 }).catch(()=>{});

    // Warten, scrollen, eventuelle Lazy-Loads & Buttons triggern
    const endAt = Date.now() + WAIT;
    while (Date.now() < endAt && !saved) {
      await page.evaluate(() => {
        window.scrollTo({ top: 0, behavior: "instant" });
        window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
      });
      await new Promise(r => setTimeout(r, 750));

      // Häufige Download-Button-Selektoren probieren (ohne Fehler, ohne Blockade)
      const selectors = [
        'a[download]',
        'a[href$=".pdf"]',
        'a[href*="/pdf"]',
        'button[aria-label*="Download" i]',
        'button:has(svg[aria-label*="download" i])',
        'a:has([data-icon="download"])'
      ];
      for (const sel of selectors) {
        try {
          const el = await page.$(sel);
          if (el) { await el.click({ delay: 30 }).catch(()=>{}); }
        } catch {}
      }
      await new Promise(r => setTimeout(r, 500));
    }

    if (!saved) {
      // Letzter Versuch: in iframes schauen und Links extrahieren
      try {
        const frames = page.frames();
        for (const fr of frames) {
          const links = await fr.$$eval('a[href]', as => as.map(a => a.href));
          const pdfLink = links.find(h => /\.pdf(\?|$)/i.test(h));
          if (pdfLink) {
            const res = await page.goto(pdfLink, { waitUntil: "networkidle2", timeout: 45000 }).catch(()=>null);
            if (res) {
              const buf = await res.buffer();
              await fs.writeFile(OUTFILE, buf);
              saved = true;
              const kb = Math.round(buf.length/1024);
              console.log(`✅ Echte PDF gespeichert: ${OUTFILE} (${kb} KB) ← direct ${pdfLink}`);
            }
            break;
          }
        }
      } catch {}
    }

    if (!saved) {
      console.log("⚠️ Keine echte PDF im Netzwerk gefunden. Tipp: Öffne den Viewer manuell, suche im DevTools-Network nach *.pdf und nutze diesen Link direkt mit curl.");
      process.exitCode = 2;
    }
  } finally {
    await browser.close().catch(()=>{});
  }
})();
