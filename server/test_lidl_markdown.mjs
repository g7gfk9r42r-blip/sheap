import fetch from "node-fetch";
import { writeFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import dotenv from "dotenv";

// Load environment variables from .env file
dotenv.config({ path: resolve(dirname(fileURLToPath(import.meta.url)), "..", ".env") });
dotenv.config({ path: resolve(dirname(fileURLToPath(import.meta.url)), "..", ".env.local"), override: false });

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const BASE = process.env.CRAWL4AI_BASE_URL || "http://localhost:11235";
const TOKEN = process.env.CRAWL4AI_TOKEN || process.env.CRAWL4AI_API_KEY || "";

async function main() {
  const url = "https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1";

  console.log("🧪 Lidl Markdown Test");
  console.log("URL:", url);
  console.log("Crawl4AI:", BASE);

  const body = {
    urls: [url],
    crawler_config: {
      type: "CrawlerRunConfig",
      params: {
        scan_full_page: true,
        wait_until: "domcontentloaded",
        simulate_user: true,
        magic: true,
        page_timeout: 90000,
        evaluate_js: true,
        scroll_page: true,
        max_scroll_height: 4000
      }
    }
  };

  const headers = { "Content-Type": "application/json" };
  if (TOKEN) {
    headers.Authorization = `Bearer ${TOKEN}`;
    headers["X-API-Key"] = TOKEN;
  }

  const res = await fetch(`${BASE}/crawl`, {
    method: "POST",
    headers,
    body: JSON.stringify(body)
  });

  if (!res.ok) {
    const errorText = await res.text();
    console.error("❌ Crawl4AI Fehler:", res.status, res.statusText);
    console.error("Antwort:", errorText.substring(0, 500));
    process.exit(1);
  }

  const json = await res.json();

  console.log("\n📊 Status Code:", res.status);

  const md = json?.results?.[0]?.markdown?.raw_markdown || "";
  console.log("\n📄 Markdown Vorschau (erste 500 Zeichen):");
  console.log("------------------------------------------------------------");
  console.log(md.substring(0, 500));
  console.log("\n📏 Markdown Länge:", md.length);

  // Extrahiere Bilder
  const result = json?.results?.[0] || {};
  const images = new Set();

  // Filter-Funktion für Lidl-Prospektbilder
  const isLidlImage = (url) => {
    if (!url || typeof url !== 'string') return false;
    return url.startsWith('https://lidl.leaflets.schwarz/') || 
           url.startsWith('https://imgproxy.leaflets.schwarz/');
  };

  // 1. Extrahiere aus media.images
  if (result.media?.images && Array.isArray(result.media.images)) {
    result.media.images.forEach(img => {
      if (typeof img === 'string' && isLidlImage(img)) {
        images.add(img);
      } else if (img?.url && isLidlImage(img.url)) {
        images.add(img.url);
      } else if (img?.src && isLidlImage(img.src)) {
        images.add(img.src);
      }
    });
  }

  // 2. Extrahiere aus cleaned_html per Regex
  const cleanedHtml = result.cleaned_html || result.html || '';
  if (cleanedHtml) {
    // Suche nach <img src="..."> Tags
    const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
    let match;
    while ((match = imgRegex.exec(cleanedHtml)) !== null) {
      const imgUrl = match[1];
      if (isLidlImage(imgUrl)) {
        images.add(imgUrl);
      }
    }

    // Suche auch nach data-src, srcset, etc.
    const dataSrcRegex = /<img[^>]+data-src=["']([^"']+)["'][^>]*>/gi;
    while ((match = dataSrcRegex.exec(cleanedHtml)) !== null) {
      const imgUrl = match[1];
      if (isLidlImage(imgUrl)) {
        images.add(imgUrl);
      }
    }

    // Suche nach absoluten URLs im HTML (falls srcset oder andere Attribute verwendet werden)
    const urlRegex = /https:\/\/(?:lidl|imgproxy)\.leaflets\.schwarz\/[^\s"'<>]+/gi;
    let urlMatch;
    while ((urlMatch = urlRegex.exec(cleanedHtml)) !== null) {
      const url = urlMatch[0];
      // Filtere aus: SVG-Logos, Icons, etc. (nur echte Prospektbilder)
      if (!url.includes('/assets/') && !url.includes('.svg')) {
        images.add(url);
      }
    }
  }

  // 3. Extrahiere auch aus Markdown (falls dort Bild-URLs enthalten sind)
  if (md) {
    const markdownUrlRegex = /https:\/\/(?:lidl|imgproxy)\.leaflets\.schwarz\/[^\s"'<>)]+/gi;
    let mdMatch;
    while ((mdMatch = markdownUrlRegex.exec(md)) !== null) {
      const url = mdMatch[0];
      if (!url.includes('/assets/') && !url.includes('.svg')) {
        images.add(url);
      }
    }
  }

  // Konvertiere Set zu Array und sortiere
  const imageArray = Array.from(images).sort();

  // Ausgabe
  console.log("\n🖼️  Prospekt-Bilder:");
  console.log("------------------------------------------------------------");
  if (imageArray.length > 0) {
    console.log(`✅ ${imageArray.length} Lidl-Prospektbilder gefunden`);
    console.log("\n📋 Erste 10 URLs (Vorschau):");
    imageArray.slice(0, 10).forEach((url, index) => {
      console.log(`   ${index + 1}. ${url}`);
    });
    if (imageArray.length > 10) {
      console.log(`   ... und ${imageArray.length - 10} weitere`);
    }

    // Speichere in lidl_images.json
    const outputData = {
      fetched_at: new Date().toISOString(),
      url: url,
      images: imageArray
    };

    const outputPath = resolve(__dirname, 'lidl_images.json');
    writeFileSync(outputPath, JSON.stringify(outputData, null, 2), 'utf-8');
    console.log(`\n💾 Bilder gespeichert in: ${outputPath}`);
  } else {
    console.log("⚠️  Keine Lidl-Prospektbilder gefunden");
    
    // Debug: Zeige verfügbare Felder
    console.log("\n🔍 Debug-Informationen:");
    if (result.media) {
      console.log("   media-Felder:", Object.keys(result.media).join(", "));
      if (result.media.images) {
        console.log("   media.images Typ:", Array.isArray(result.media.images) ? 'Array' : typeof result.media.images);
        console.log("   media.images Länge:", Array.isArray(result.media.images) ? result.media.images.length : 'N/A');
        if (Array.isArray(result.media.images) && result.media.images.length > 0) {
          console.log("   Erstes media.images Element:", JSON.stringify(result.media.images[0], null, 2));
        }
      }
    }
    if (result.cleaned_html || result.html) {
      const html = result.cleaned_html || result.html;
      const imgCount = (html.match(/<img/gi) || []).length;
      const lidlUrlCount = (html.match(/lidl\.leaflets\.schwarz/gi) || []).length;
      console.log("   HTML enthält:", imgCount, "<img> Tags");
      console.log("   HTML enthält:", lidlUrlCount, "Lidl-URL-Erwähnungen");
    }
  }

  console.log("\n🎉 Test abgeschlossen");
}

main().catch((err) => {
  console.error("❌ Fehler:", err);
});
