/**
 * download_penny_prospekt.js
 * Vollautomatischer Downloader & PDF-Builder für Marktguru Prospekte.
 */

import fs from "fs-extra";
import puppeteer from "puppeteer";
import fetch from "node-fetch";
import { execSync } from "child_process";
import path from "path";

const LEAFLET_ID = "4066629"; // Penny Prospekt W44
const OUT_DIR = "../../media/prospekte/penny/2025/W44";
const MAX_PAGES = 80;

(async () => {
  const outPath = path.resolve(OUT_DIR);
  await fs.ensureDir(`${outPath}/pages`);

  const browser = await puppeteer.launch({
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  const page = await browser.newPage();
  await page.setUserAgent(
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128 Safari/537.36"
  );

  console.log("🚀 Lade Penny Prospekt ...");
  let downloaded = 0;

  for (let i = 0; i < MAX_PAGES; i++) {
    const url = `https://www.marktguru.de/leaflets/${LEAFLET_ID}/page/${i}`;
    try {
      const resp = await page.goto(url, { waitUntil: "networkidle2", timeout: 30000 });
      if (!resp || resp.status() >= 400) break;

      await page.waitForSelector("img", { timeout: 5000 }).catch(() => {});
      const imgUrl = await page.evaluate(() => {
        const imgs = Array.from(document.querySelectorAll("img"));
        let best = null;
        let bestArea = 0;
        for (const im of imgs) {
          const w = im.naturalWidth || im.width || 0;
          const h = im.naturalHeight || im.height || 0;
          const area = w * h;
          const src = im.currentSrc || im.src || "";
          if (src && area > bestArea && /leaflet|cdn|page|assets/i.test(src)) {
            best = src;
            bestArea = area;
          }
        }
        return best;
      });

      if (!imgUrl) {
        console.log(`❌ Kein Bild auf Seite ${i}, Stop.`);
        break;
      }

      const absUrl = new URL(imgUrl, url).toString();
      const ext = absUrl.match(/\.(webp|jpg|jpeg|png)/i)?.[1] || "jpg";
      const filename = `${outPath}/pages/p${String(i).padStart(3, "0")}.${ext}`;

      const res = await fetch(absUrl, {
        headers: { "User-Agent": "Mozilla/5.0", Referer: url },
      });
      if (!res.ok) break;

      const buf = await res.arrayBuffer();
      if (Buffer.from(buf).slice(0, 10).toString("utf8").includes("<!DOCTYPE")) {
        console.log(`⚠️  Seite ${i} ist kein echtes Bild.`);
        break;
      }

      await fs.writeFile(filename, Buffer.from(buf));
      console.log(`✅ Seite ${i} gespeichert (${filename})`);
      downloaded++;
    } catch (err) {
      console.log(`⚠️  Fehler bei Seite ${i}: ${err.message}`);
      break;
    }
  }

  await browser.close();
  console.log(`📄 ${downloaded} Seiten erfolgreich geladen.`);

  if (downloaded > 0) {
    console.log("🧩 Erstelle PDF ...");
    try {
      execSync(
        `magick ${outPath}/pages/* ${outPath}/penny_2025-W44.pdf`,
        { stdio: "inherit" }
      );
      console.log("✅ PDF fertig: penny_2025-W44.pdf");
    } catch (e) {
      console.log("❌ Fehler beim PDF-Bau:", e.message);
    }
  } else {
    console.log("⚠️ Keine Seiten geladen, PDF übersprungen.");
  }
})();