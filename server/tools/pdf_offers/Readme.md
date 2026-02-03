#!/usr/bin/env node
/**
 * Download Lidl DE leaflet from the interactive viewer by screenshotting each page
 * and bundling into a single PDF.
 *
 * Usage:
 *   node download_lidl_viewer.mjs "<viewerUrl>" "<outDir>" [--max 120] [--delay 250] [--headful] [--debug]
 *
 * Example:
 *   node download_lidl_viewer.mjs \
 *     "https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1" \
 *     ../../media/prospekte/lidl/2025/W44 \
 *     --max 120 --delay 250 --headful --debug
 *
 * Requires: puppeteer, fs-extra, pdf-lib
 */
import fs from "fs";
import fse from "fs-extra";
import path from "path";
import process from "process";
import { fileURLToPath } from "url";
import puppeteer from "puppeteer";
import { PDFDocument } from "pdf-lib";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// --- CLI args ---
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("❌ Usage: node download_lidl_viewer.mjs \"<viewerUrl>\" \"<outDir>\" [--max N] [--delay MS] [--headful] [--debug]");
  process.exit(1);
}
const viewerUrl = args[0];
const outDir = args[1];

const getFlag = (name, def = null) => {
  const idx = args.indexOf(name);
  if (idx === -1) return def;
  const v = args[idx + 1];
  if (!v || v.startsWith("--")) return true;
  return v;
};

const MAX_PAGES = parseInt(getFlag("--max", 120), 10);
const DELAY_MS  = parseInt(getFlag("--delay", 250), 10);
const HEADFUL   = Boolean(getFlag("--headful", false));
const DEBUG     = Boolean(getFlag("--debug", false));

const log = (...m) => console.log(...m);
const dbg = (...m) => { if (DEBUG) console.log("[debug]", ...m); };

// Base URL (strip trailing /page/{n} if present)
const baseUrl = (() => {
  const m = viewerUrl.match(/^(.*?\/page)\/\d+(?:[/?#].*)?$/);
  return m ? m[1] : viewerUrl.replace(/\/+$/, "");
})();

// Prepare folders
const pagesDir = path.join(outDir, "pages");
await fse.ensureDir(pagesDir);

function pagePath(i) {
  return path.join(pagesDir, `p${String(i).padStart(3, "0")}.png`);
}

async function screenshotLargestImage(page, i) {
  // Pick the largest visible IMG on the page (Lidl viewer renders each page as a large IMG or CANVAS)
  const bbox = await page.evaluate(() => {
    const candidates = [
      ...Array.from(document.querySelectorAll("img")),
      ...Array.from(document.querySelectorAll("canvas")),
    ];
    let best = null;
    let bestArea = 0;
    for (const el of candidates) {
      const r = el.getBoundingClientRect();
      const style = window.getComputedStyle(el);
      const visible = style.visibility !== "hidden" && style.display !== "none" && r.width > 200 && r.height > 300;
      if (!visible) continue;
      const area = r.width * r.height;
      if (area > bestArea) {
        bestArea = area;
        best = { x: r.x + window.scrollX, y: r.y + window.scrollY, width: r.width, height: r.height };
      }
    }
    return best;
  });

  if (!bbox) return false;

  // Add small padding to avoid cropping artifacts
  const pad = 2;
  const clip = {
    x: Math.max(0, bbox.x - pad),
    y: Math.max(0, bbox.y - pad),
    width: bbox.width + pad * 2,
    height: bbox.height + pad * 2,
  };

  await page.screenshot({ path: pagePath(i), clip });
  return true;
}

async function toPdf(images, outPdf) {
  const pdf = await PDFDocument.create();
  for (const imgPath of images) {
    const bytes = await fse.readFile(imgPath);
    // png screenshots
    const img = await pdf.embedPng(bytes);
    const page = pdf.addPage([img.width, img.height]);
    page.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });
  }
  const pdfBytes = await pdf.save();
  await fse.writeFile(outPdf, pdfBytes);
}

(async () => {
  log(`🚀 Starte Lidl-Viewer Download`);
  log(`🔗 URL: ${viewerUrl}`);
  log(`📂 Ziel: ${outDir}`);

  const browser = await puppeteer.launch({
    headless: !HEADFUL ? "new" : false,
    defaultViewport: { width: 1280, height: 1800, deviceScaleFactor: 2 },
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
    ],
  });

  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(10000);

    const imagesTaken = [];
    for (let i = 1; i <= MAX_PAGES; i++) {
      const url = `${baseUrl}/${i}`;
      dbg(`➡️  Gehe zu ${url}`);
      try {
        await page.goto(url, { waitUntil: "networkidle2", timeout: 30000 });
      } catch (e) {
        log(`❌ Seite ${i}: Navigation fehlgeschlagen (${e.message}). Stoppe.`);
        break;
      }

      // Warten, bis irgendein großes Bild/Canvas gerendert ist
      try {
        await page.waitForFunction(() => {
          const els = [...document.querySelectorAll("img, canvas")];
          return els.some(el => {
            const r = el.getBoundingClientRect();
            return r.height > 400 && r.width > 250 && getComputedStyle(el).visibility !== "hidden" && getComputedStyle(el).display !== "none";
          });
        }, { timeout: 10000 });
      } catch {
        log(`⚠️  Seite ${i}: Kein großes Bild gefunden – vermutlich Ende des Prospekts.`);
        break;
      }

      const ok = await screenshotLargestImage(page, i);
      if (!ok) {
        log(`⚠️  Seite ${i}: Konnte kein Bild ausschneiden – beende Schleife.`);
        break;
      }
      imagesTaken.push(pagePath(i));
      log(`✅ Seite ${i} gespeichert (${path.basename(pagePath(i))})`);

      if (DELAY_MS > 0) await page.waitForTimeout(DELAY_MS);
    }

    if (imagesTaken.length === 0) {
      log("❌ Keine Seiten erfasst – breche ab.");
      return;
    }

    const outPdf = path.join(outDir, `leaflet_lidl.pdf`);
    log("🧩 Erstelle PDF …");
    await toPdf(imagesTaken, outPdf);
    log(`✅ Fertig: ${outPdf}`);
    log(`ℹ️ Insgesamt ${imagesTaken.length} Seiten in PDF übernommen.`);
  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error("💥 Unhandled error:", err);
  process.exit(1);
});
