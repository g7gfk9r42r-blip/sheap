#!/usr/bin/env node
import fs from "fs/promises";
import path from "path";
import process from "process";
import { Buffer } from "node:buffer";
import puppeteer from "puppeteer";
import { PDFDocument } from "pdf-lib";

const DEFAULT_MAX_PAGES = 420;
const DEFAULT_DELAY = 1000;
const SCROLL_SELECTORS = [
  ".leaflet",
  ".pageflip",
  "[data-testid='leaflet-viewer']",
  ".viewer",
  "main",
  "body"
];
const CONSENT_KEYWORDS = [
  "akzeptieren",
  "einverstanden",
  "zustimmen",
  "alle akzeptieren"
];
const NEWSLETTER_CLOSE_SELECTORS = [
  "[data-testid='close']",
  "button[aria-label*='schließ' i]",
  "button[title*='schließ' i]",
  ".modal [role='button']",
  ".modal button",
  "[class*='close']",
  "[aria-label*='close' i]"
];
const NEXT_BUTTON_SELECTORS = [
  ".slick-next",
  ".swiper-button-next",
  "[data-testid='next']",
  "button[aria-label*='weiter' i]",
  "button[title*='weiter' i]"
];
const IMAGE_HOST_RE = /(mg2.*\.b-cdn\.net|cdn\.marktguru\.de)/i;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

let sharpModule = null;

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

function parseArgs(argv) {
  if (argv.length < 4) {
    console.error("Usage: node tools/leaflets/scrape_marktguru_leaflet.mjs <viewer_url> <out_pdf> [--max=420] [--delay=1000]");
    process.exit(1);
  }
  const viewerUrl = argv[2];
  const outPdf = argv[3];
  const flags = {};
  for (let i = 4; i < argv.length; i++) {
    const tok = argv[i];
    if (!tok.startsWith("--")) continue;
    const [key, value] = tok.slice(2).split("=");
    flags[key] = value ?? true;
  }
  const max = Number(flags.max ?? DEFAULT_MAX_PAGES) || DEFAULT_MAX_PAGES;
  const delay = Number(flags.delay ?? DEFAULT_DELAY) || DEFAULT_DELAY;
  return { viewerUrl, outPdf, max, delay };
}

async function closePopups(page) {
  for (let attempt = 0; attempt < 4; attempt++) {
    const closed = await page.evaluate((consentWords, closeSelectors) => {
      let count = 0;
      const lowerWords = consentWords;
      const buttons = Array.from(document.querySelectorAll("button, [role='button']"));
      for (const btn of buttons) {
        const text = (btn.innerText || btn.textContent || "").trim().toLowerCase();
        if (!text) continue;
        if (lowerWords.some(word => text.includes(word))) {
          btn.click();
          count++;
        }
      }
      for (const sel of closeSelectors) {
        const el = document.querySelector(sel);
        if (el) {
          el.dispatchEvent(new MouseEvent("click", { bubbles: true }));
          count++;
        }
      }
      const svgClose = document.querySelector("svg[aria-label*='schließ'], svg[aria-label*='close']");
      if (svgClose) {
        const parent = svgClose.closest("button,[role='button']");
        parent?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        count++;
      }
      return count;
    }, CONSENT_KEYWORDS, NEWSLETTER_CLOSE_SELECTORS);
    if (!closed) break;
    await sleep(400);
  }
}

async function discoverContainer(page) {
  return page.evaluate((selectors) => {
    const found = selectors
      .map(sel => document.querySelector(sel))
      .find(Boolean);
    const container = found || document.scrollingElement || document.body || document.documentElement;
    container.dataset.mgContainer = "true";
    container.setAttribute("data-mg-container", "true");
    return true;
  }, SCROLL_SELECTORS);
}

async function attemptAdvance(page) {
  const clicked = await page.evaluate((selectors) => {
    for (const sel of selectors) {
      const btn = document.querySelector(sel);
      if (btn) {
        btn.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        return true;
      }
    }
    return false;
  }, NEXT_BUTTON_SELECTORS);
  if (!clicked) {
    try { await page.keyboard.press("ArrowRight"); } catch {}
  }
}

async function getDomImageUrls(page) {
  return page.evaluate(() => {
    // sammelt die größte verfügbare Bild-URL pro <img> (srcset-aware)
    const urls = Array.from(document.images)
      .map(img => {
        // 1) bevorzugt currentSrc (Browser wählt beste srcset-Variante)
        let u = img.currentSrc || img.src || "";
        // 2) Falls kein currentSrc: srcset selbst parsen → größte Breite wählen
        if ((!u || u.endsWith(".svg")) && img.srcset) {
          const best = img.srcset
            .split(",")
            .map(s => s.trim().split(/\s+/))            // [url, "800w"]
            .map(([url, size]) => ({ url, w: parseInt(size, 10) || 0 }))
            .sort((a, b) => b.w - a.w)[0];              // größte Breite
          if (best?.url) u = best.url;
        }
        return u;
      })
      // nur echte Bild-CDNs zulassen (Marktguru nutzt u.a. mg2…b-cdn.net / cdn.marktguru.de)
      .filter(u =>
        /^https?:\/\//.test(u) &&
        /\.(jpe?g|webp|png)(\?|$)/i.test(u) &&
        /(b-cdn\.net|cdn\.marktguru\.de|mg\d.*cdn)/i.test(u)
      );
    return Array.from(new Set(urls));
  });
}

async function fetchImageBytes(page, url) {
  const result = await page.evaluate(async (targetUrl) => {
    try {
      const res = await fetch(targetUrl, { credentials: "omit" });
      if (!res.ok) return null;
      const contentType = res.headers.get("content-type") || "";
      const buffer = await res.arrayBuffer();
      return {
        contentType,
        data: Array.from(new Uint8Array(buffer))
      };
    } catch {
      return null;
    }
  }, url);
  if (!result || !result.data) return null;
  return {
    contentType: result.contentType || "",
    buffer: Buffer.from(result.data)
  };
}

async function collectImages(page, { delay, max }) {
  const collected = [];
  const seenUrls = new Set();
  let reachedLimit = false;

  const handler = async (response) => {
    try {
      const url = response.url();
      if (reachedLimit) return;
      if (!IMAGE_HOST_RE.test(url)) return;
      if (seenUrls.has(url)) return;
      const headers = response.headers();
      const contentType = headers["content-type"] || "";
      if (!/image\/(jpeg|jpg|png|webp)/i.test(contentType) && !/\.(jpe?g|png|webp)(\?|$)/i.test(url)) return;
      const buffer = await response.buffer();
      seenUrls.add(url);
      collected.push({ url, buffer, contentType });
      if (collected.length >= max) reachedLimit = true;
    } catch {
      // ignore single fetch errors
    }
  };

  page.on("response", handler);
  try {
    await closePopups(page);
    await discoverContainer(page);
    let stagnantRounds = 0;
    let lastCount = 0;
    for (let i = 0; i < max; i++) {
      await closePopups(page);
      await page.evaluate((selectors) => {
        const container = selectors
          .map(sel => document.querySelector(sel))
          .find(Boolean) || document.querySelector("[data-mg-container='true']");
        const target = container || document.querySelector("[data-mg-container='true']") || document.scrollingElement || document.body || document.documentElement;
        const before = target.scrollTop;
        target.scrollBy(0, target.clientHeight * 0.9 || window.innerHeight * 0.9);
        if (target.scrollTop === before) {
          window.scrollBy(0, window.innerHeight * 0.9);
        }
      }, SCROLL_SELECTORS);
      await attemptAdvance(page);
      await sleep(delay);
      const domUrls = await getDomImageUrls(page);
      for (const url of domUrls) {
        if (reachedLimit) break;
        if (seenUrls.has(url)) continue;
        const fetched = await fetchImageBytes(page, url);
        if (!fetched) continue;
        seenUrls.add(url);
        collected.push({ url, buffer: fetched.buffer, contentType: fetched.contentType });
        if (collected.length >= max) {
          reachedLimit = true;
          break;
        }
      }
      if (collected.length === lastCount) {
        stagnantRounds++;
      } else {
        stagnantRounds = 0;
      }
      lastCount = collected.length;
      if (stagnantRounds >= 3) break;
      if (collected.length >= max) break;
    }
    await sleep(1500);
    if (!reachedLimit) {
      const finalUrls = await getDomImageUrls(page);
      for (const url of finalUrls) {
        if (reachedLimit) break;
        if (seenUrls.has(url)) continue;
        const fetched = await fetchImageBytes(page, url);
        if (!fetched) continue;
        seenUrls.add(url);
        collected.push({ url, buffer: fetched.buffer, contentType: fetched.contentType });
        if (collected.length >= max) {
          reachedLimit = true;
          break;
        }
      }
    }
  } finally {
    page.off("response", handler);
  }
  return collected;
}

async function getSharp() {
  if (sharpModule !== null) return sharpModule;
  try {
    const mod = await import("sharp");
    sharpModule = mod.default;
  } catch {
    console.error("❌ Für die PNG-Konvertierung wird 'sharp' benötigt. Installiere es mit `npm install sharp`.");
    process.exit(5);
  }
  return sharpModule;
}

function inferExt(contentType, url) {
  if (/png/i.test(contentType) || /\.png(\?|$)/i.test(url)) return "png";
  if (/webp/i.test(contentType) || /\.webp(\?|$)/i.test(url)) return "webp";
  return "jpg";
}

async function writeImagesAsPng(collected, shotsDir) {
  await fs.rm(shotsDir, { recursive: true, force: true });
  await ensureDir(shotsDir);
  const outPaths = [];
  let index = 1;
  for (const entry of collected) {
    const ext = inferExt(entry.contentType, entry.url);
    let pngBuffer = entry.buffer;
    if (ext !== "png") {
      const sharp = await getSharp();
      pngBuffer = await sharp(entry.buffer).png().toBuffer();
    }
    const fileName = `page-${String(index).padStart(3, "0")}.png`;
    const outPath = path.join(shotsDir, fileName);
    await fs.writeFile(outPath, pngBuffer);
    outPaths.push(outPath);
    index++;
  }
  return outPaths;
}

function extractPageNumber(url, fallback) {
  const match = url.match(/(\d{1,4})(?=\D*$)/);
  if (!match) return fallback;
  return parseInt(match[1], 10);
}

async function buildPdfFromImages(imagePaths, outPdf) {
  const pdfDoc = await PDFDocument.create();
  for (const imagePath of imagePaths) {
    const buffer = await fs.readFile(imagePath);
    const image = await pdfDoc.embedPng(buffer);
    const { width, height } = image.size();
    const page = pdfDoc.addPage([width, height]);
    page.drawImage(image, { x: 0, y: 0, width, height });
  }
  const pdfBytes = await pdfDoc.save();
  await ensureDir(path.dirname(outPdf));
  await fs.writeFile(outPdf, pdfBytes);
}

async function main() {
  const { viewerUrl, outPdf, max, delay } = parseArgs(process.argv);
  const shotsDir = path.join(path.dirname(outPdf), "__shots");
  console.log(`➡️ Öffne Viewer: ${viewerUrl}`);
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: "new",
      defaultViewport: { width: 1400, height: 1100 },
      args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
    });
    const page = await browser.newPage();
    await page.setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36");
    await page.goto(viewerUrl, { waitUntil: "domcontentloaded", timeout: 90000 });
    await closePopups(page);
    const collected = await collectImages(page, { delay, max });
    collected.sort((a, b) => {
      const numA = extractPageNumber(a.url, Number.MAX_SAFE_INTEGER);
      const numB = extractPageNumber(b.url, Number.MAX_SAFE_INTEGER);
      if (numA !== numB) return numA - numB;
      return a.url.localeCompare(b.url);
    });
    console.log(`ℹ️  Gefundene Bild-Assets: ${collected.length}`);
    if (collected.length < 2) {
      console.error("❌ Zu wenige Seitenbilder gefunden (<2).");
      process.exit(2);
    }
    const ordered = collected;
    const imagePaths = await writeImagesAsPng(ordered, shotsDir);
    await buildPdfFromImages(imagePaths, outPdf);
    const stat = await fs.stat(outPdf);
    console.log(`✅ Fertig: ${outPdf}`);
    console.log(`ℹ️  PDF-Seiten: ${imagePaths.length}`);
    console.log(`ℹ️  Dateigröße: ${(stat.size / (1024 * 1024)).toFixed(2)} MB`);
  } finally {
    if (browser) {
      try { await browser.close(); } catch {}
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

