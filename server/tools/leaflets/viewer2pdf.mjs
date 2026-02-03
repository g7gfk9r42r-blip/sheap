// tools/leaflets/viewer2pdf.mjs
import fs from "fs/promises";
import path from "node:path";
import puppeteer from "puppeteer";
import { PDFDocument } from "pdf-lib";

import crypto from "node:crypto";

// --- helpers ---
const host = (u) => {
  try { return new URL(u).host || ""; } catch { return ""; }
};
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
// Fallback, falls irgendwo noch waitForTimeout aufgerufen wird
const wait = sleep;

function parseFlags(argv){
  // naive flag parser: supports --key=value and --flag value
  const out = {};
  for(let i=0;i<argv.length;i++){
    const tok = argv[i];
    if(!tok.startsWith("--")) continue;
    const eq = tok.indexOf("=");
    if(eq>0){
      const k = tok.slice(2,eq);
      const v = tok.slice(eq+1);
      out[k] = v;
    }else{
      const k = tok.slice(2);
      const next = argv[i+1];
      if(next && !next.startsWith("--")) { out[k]=next; i++; }
      else { out[k] = true; }
    }
  }
  return out;
}
const num = (v, def) => (v==null?def:(isNaN(+v)?def:+v));
const boolFlag = (v) => {
  if (v === true || v === false) return !!v;
  if (v == null) return false;
  const s = String(v).trim().toLowerCase();
  return s === "1" || s === "true" || s === "yes" || s === "on";
};

// --- Filter Helpers ---
function toRegex(maybe) {
  if (!maybe) return null;
  try { return new RegExp(String(maybe), "i"); } catch { return null; }
}

// Site-Profile: Wie „weiterblättern“, was ist die Seite?
const SITE_PROFILES = [
  // Lidl: häufig Slick/Swiper/Canvas/Publitas/IPaper
  {
    match: /\blidl\./i,
    nextSelector: [
      'button[aria-label*="weiter" i]',
      'button[title*="weiter" i]',
      '.slick-next',
      '.swiper-button-next',
      '[data-testid="next"]',
      '.icon-arrow-right',
      'button[aria-label*="nächste seite" i]'
    ].join(','),
    pageContainer: [
      '.viewer',
      '[data-testid="viewer"]',
      '.slick-list',
      '.swiper',
      '.magazine, .flipbook, .catalog',
      'main,#main'
    ].join(','),
    maxPages: 180,
    preferImages: true
  },
  // EDEKA: ähnliche Viewer/Canvas/CDNs
  {
    match: /\bedeka\./i,
    nextSelector: [
      'button[aria-label*="weiter" i]',
      'button[title*="weiter" i]',
      '.slick-next',
      '.swiper-button-next',
      '[data-testid="next"]',
      'button[aria-label*="nächste seite" i]'
    ].join(','),
    pageContainer: [
      '.viewer',
      '[data-testid="viewer"]',
      '.slick-list',
      '.swiper',
      '.magazine, .flipbook, .catalog',
      'main,#main'
    ].join(','),
    maxPages: 180,
    preferImages: true
  },
];

function pickProfile(url){
  return SITE_PROFILES.find(p => p.match.test(host(url))) || {
    // Fallback: generisch
    nextSelector: 'button[aria-label*="weiter"], .next, [data-testid="next"]',
    pageContainer: 'main, #main, body',
    maxPages: 80
  };
}

function applyOverrides(profile, flags){
  const p = { ...profile };
  if(flags.next) p.nextSelector = String(flags.next);
  if(flags.container) p.pageContainer = String(flags.container);
  if(flags.max) p.maxPages = num(flags.max, p.maxPages || 80);
  return p;
}

async function ensureDir(p){ await fs.mkdir(path.dirname(p), { recursive:true }); }

async function antiBlur(page){
  await page.addStyleTag({content:"html{scroll-behavior:auto!important}*{transition:none!important;animation:none!important}"});
  await page.addStyleTag({content:`
    *{filter:none!important;-webkit-filter:none!important}
    [style*="filter"]{filter:none!important;-webkit-filter:none!important}
    img[loading]{loading:eager!important}
    img[decoding]{decoding:sync!important}
    html, body{background:#fff!important}
  `});
  // Force-lazy images
  await evalSafe(page, ()=>{
    document.querySelectorAll('img').forEach(img=>{
      const ds = img.dataset||{};
      if(ds.src) img.src = ds.src;
      if(ds.lazySrc) img.src = ds.lazySrc;
      if(ds.srcset) img.srcset = ds.srcset;
    });
  });
}

async function acceptConsent(page){
  try{
    await sleep(700);
    const x = await page.$x("//button[contains(., 'Zustimmen') or contains(., 'Akzeptieren') or contains(., 'Einverstanden') or contains(., 'Accept') or contains(., 'Agree') or contains(., 'I agree')]");
    if(x.length){ await x[0].click({delay:40}); await sleep(600); return; }
    await page.click("button[aria-label*='Zustimmen' i], button[title*='Zustimmen' i], button[aria-label*='Accept' i], button[title*='Accept' i]").catch(()=>{});
  }catch{}
}

async function closeOverlays(page){
  const tries = [
    "button[aria-label*='schließen' i]",
    "button[title*='schließen' i]",
    "[data-testid='close']",
    ".modal [data-testid='close']",
    "button.cookie-settings-save",
    "#onetrust-accept-btn-handler",
    "button[aria-label*='ok' i]"
  ];
  for(const sel of tries){
    try{ const el = await page.$(sel); if(el){ await el.click({delay:40}); await sleep(400);} }catch{}
  }
  try{
    await evalSafe(page, ()=>{
      document.querySelectorAll('.modal-backdrop,.backdrop,[class*="overlay"]').forEach(el=>{
        el.click?.(); el.remove?.();
      });
    });
  }catch{}
}

async function openFirstThumb(page, thumbSelList){
  for(const sel of thumbSelList||[]){ try{
    await page.waitForSelector(sel, {timeout:2500});
    const t = await page.$(sel); if(t){ await t.click({delay:40}); await sleep(500); return true; }
  }catch{} }
  return false;
}

// Falls die Seite echte PDFs lädt → sofort speichern
async function sniffAndDownloadPdf(page, outPdf, flags){
  const incRe = toRegex(flags["include-url"]);
  const excRe = toRegex(flags["exclude-url"]);

  let found = null;
  function onResponse(resp){
    try{
      const ct = (resp.headers()["content-type"]||"").toLowerCase();
      const url = resp.url();
      if (!(ct.includes("pdf") || /\.pdf(\?|$)/i.test(url))) return;
      if (excRe && excRe.test(url)) return;              // ausschließen
      if (incRe && !incRe.test(url)) return;             // nur bestimmte erlauben
      found = url;
    }catch{}
  }
  page.on("response", onResponse);
  await page.waitForNetworkIdle({idleTime:1200, timeout:10000}).catch(()=>{});
  page.off("response", onResponse);

  if(!found) return false;

  try{
    const bytes = await evalSafe(page, async (u)=>{
      const r = await fetch(u,{credentials:"omit"});
      const a = await r.arrayBuffer();
      return Array.from(new Uint8Array(a));
    }, found);
    await ensureDir(outPdf);
    await fs.writeFile(outPdf, Buffer.from(bytes));
    const kb = Math.max(1, Math.round(bytes.length/1024));
    console.log(`✅ Direktes PDF übernommen (${kb} KB): ${found}`);
    return true;
  }catch{
    return false;
  }
}

// --- NEW: network image collector ---
function byExt(u){ try{ return new URL(u).pathname.split(".").pop().toLowerCase(); }catch{ return ""; } }
function isPageImage(u){
  // Whitelist der typischen Bild-Endungen
  const ok = ["jpg","jpeg","png","webp","avif"];
  const ext = byExt(u);
  if(!ok.includes(ext)) return false;

  // Häufige Prospekt-CDNs/Patterns
  const hostOK = /(edeka|lidl|cloudfront|publitas|ipaper|issuu|yumpu|flippingbook|flipsnack|onstackit|onlinetouch|turn-page|cdn|assets)\./i.test(u);
  const pathOK = /(page-|seite|p=|leaflet|prospekt|flyer|catalog|catalogue|magazine|viewer|spread)/i.test(u);

  return hostOK || pathOK;
}

async function collectDomImages(page, prof, flags){
  // Sammelt src, srcset, background-image URLs innerhalb pageContainer
  const urls = await evalSafe(page, (sel)=>{
    const seen = new Set();
    const roots = Array.from(document.querySelectorAll(sel)).concat([document.body]);

    function add(u){
      if(!u) return;
      try {
        const a = new URL(u, location.href).href;
        seen.add(a);
      } catch {}
    }

    function fromStyle(el){
      const s = getComputedStyle(el);
      const bg = s.backgroundImage || "";
      // url("..."), url('...'), url(...)
      const m = Array.from(bg.matchAll(/url\((?:'|")?([^'")]+)(?:'|")?\)/gi));
      for(const x of m){ add(x[1]); }
    }

    for(const root of roots){
      // <img>
      root.querySelectorAll('img').forEach(img=>{
        add(img.src);
        const ss = img.srcset || "";
        ss.split(',').forEach(part=>{
          const u = part.trim().split(' ')[0];
          add(u);
        });
      });
      // <source> in <picture>
      root.querySelectorAll('source').forEach(src=>{
        const ss = src.srcset || "";
        ss.split(',').forEach(part=>{
          const u = part.trim().split(' ')[0];
          add(u);
        });
      });
      // background-image
      root.querySelectorAll('*').forEach(el=> fromStyle(el));
    }

    return Array.from(seen);
  }, prof.pageContainer);

  // Filter auf Seitenbilder
  return urls.filter(isPageImage);
}

async function fetchBytesInPage(page, url) {
  return await evalSafe(page, async (u) => {
    const r = await fetch(u, { credentials: "omit" });
    const a = await r.arrayBuffer();
    return Array.from(new Uint8Array(a));
  }, url).then(arr => Buffer.from(arr));
}

function sniffType(buf, url="") {
  const ext = url.split("?")[0].split(".").pop()?.toLowerCase() || "";
  const b = buf;
  const isPNG  = b.length>8  && b[0]===0x89 && b[1]===0x50 && b[2]===0x4E && b[3]===0x47;
  const isJPG  = b.length>3  && b[0]===0xFF && b[1]===0xD8 && b[2]===0xFF;
  const isRIFF = b.length>12 && b[0]===0x52 && b[1]===0x49 && b[2]===0x46 && b[3]===0x46;
  const riffWEBP = isRIFF && (b.slice(8,12).toString("ascii")==="WEBP");
  const isISOBase = b.length>12 && b.slice(4,8).toString("ascii")==="ftyp";
  const brand = isISOBase ? b.slice(8,12).toString("ascii") : "";
  const isAVIF = isISOBase && /avif|avis|mif1|heic/i.test(brand);

  if(isPNG) return "png";
  if(isJPG) return "jpg";
  if(riffWEBP || ext==="webp") return "webp";
  if(isAVIF || ext==="avif") return "avif";
  if(["png","jpg","jpeg","webp","avif"].includes(ext)) return ext.replace("jpeg","jpg");
  return "bin";
}

let _sharp = null;
async function toPNG(buf) {
  if(!_sharp) {
    try { _sharp = (await import('sharp')).default; }
    catch { _sharp = null; }
  }
  if(!_sharp) throw new Error("sharp nicht verfügbar");
  return await _sharp(buf).png().toBuffer();
}

async function tryAdvance(page, selectors, pauseMs){
  // 1) Klick auf Next
  const next = await page.$(selectors).catch(()=>null);
  if(next){
    await next.click({delay:50}).catch(()=>{});
    await sleep(pauseMs);
    return true;
  }

  // 2) Horizontal scroll (manche Viewer wechseln so die Seite)
  await page.mouse.move(400, 400).catch(()=>{});
  await page.mouse.wheel({ deltaX: 1000, deltaY: 0 }).catch(()=>{});
  await sleep(pauseMs);

  // 3) Tasten
  for(const key of ["ArrowRight","PageDown"," ","ArrowDown"]){
    await page.keyboard.press(key).catch(()=>{});
    await sleep(pauseMs);
  }
  return true;
}

async function collectViewerImages(page, prof, flags){
  const seen = new Set();
  const imgs = [];

  function onResponse(resp){
    try{
      const url = resp.url();
      if(isPageImage(url)) seen.add(url);
    }catch{}
  }
  page.on("response", onResponse);

  // initial laden + consent
  await acceptConsent(page);
  await antiBlur(page);

  // lazy triggern
  for(let i=0;i<6;i++){ await evalSafe(page, () => window.scrollBy(0, window.innerHeight)); await sleep(400); }

  // Klicken, bis keine neuen Bilder mehr auftauchen
  let lastCount = -1;
  for(let i=0;i<Number(flags.max||80); i++){
    await sleep(Number(flags.delay||800));
    if(seen.size === lastCount) {
      // noch ein paar letzte Wartezyklen
      await sleep(600);
      if(seen.size === lastCount) break;
    }
    lastCount = seen.size;
    await tryAdvance(page, prof.nextSelector, Number(flags.delay||800));
  }

  page.off("response", onResponse);

  // In stabile Reihenfolge bringen (versuche Zahl zu extrahieren)
  const arr = Array.from(seen);
  arr.sort((a,b)=>{
    const na = parseInt((a.match(/(\d{1,3})(?=\D*$)/)||[])[1]||"0",10);
    const nb = parseInt((b.match(/(\d{1,3})(?=\D*$)/)||[])[1]||"0",10);
    return na-nb || a.localeCompare(b);
  });

  // Bytes holen
  for(const u of arr){
    try{
      const buf = await fetchBytesInPage(page, u);
      imgs.push({ url:u, buf });
    }catch{}
  }
  return imgs;
}

async function evalSafe(page, fn, ...args){
  for(let i=0;i<5;i++){
    try { return await page.evaluate(fn, ...args); }
    catch(e){
      const msg = String(e || "");
      if (msg.includes('detached') || msg.includes('Execution context was destroyed')) {
        await page.waitForTimeout(400);
        continue;
      }
      throw e;
    }
  }
  return await page.evaluate(fn, ...args);
}


async function captureAllPages(url, outPdf, flags){
  const prof = applyOverrides(pickProfile(url), flags);
  const preferImages = boolFlag(flags["prefer-images"] ?? flags.preferImages) || prof.preferImages;

  if(flags.debug){
    try{ await fs.mkdir(path.join(path.dirname(outPdf), "__debug"), {recursive:true}); }catch{}
  }

  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox","--disable-setuid-sandbox","--lang=de-DE,de","--disable-blink-features=AutomationControlled"],
    defaultViewport: { width: 1600, height: 1400, deviceScaleFactor: num(flags.scale, 2.5) },
  });

  try{
    const page = await browser.newPage();
    await page.setUserAgent(String(flags.ua || "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127 Safari/537.36"));
    const lang = String(flags.lang || "de-DE,de;q=0.9,en;q=0.8");
    await page.setExtraHTTPHeaders({ "Accept-Language": lang });

    await page.goto(url, { waitUntil: "networkidle2", timeout: 120000 });

    const requireTitle = toRegex(flags["require-title"]);
    if (requireTitle) {
      const docTitle = await page.title().catch(()=> "");
      if (!requireTitle.test(docTitle)) {
        throw new Error(`Abbruch: document.title passt nicht. Titel="${docTitle}" verlangt="${requireTitle}"`);
      }
    }

    const debugDump = async () => {
      if(!flags.debug) return;
      try{
        const dd = path.join(path.dirname(outPdf), "__debug");
        await fs.writeFile(path.join(dd, "page.html"), await page.content());
        await fs.writeFile(path.join(dd, "dom_summary.json"), JSON.stringify({hasNextData: !!(await page.$(prof.nextSelector).catch(()=>null))}));
        const png = await page.screenshot({fullPage:true});
        await fs.writeFile(path.join(dd,"page.png"), png);
      }catch{}
    };

    await acceptConsent(page);
    await antiBlur(page);

    // sanftes Scrollen + Idle warten
    for(let i=0;i<8;i++){ await evalSafe(page, () => window.scrollBy(0, window.innerHeight)); await sleep(400); }
    await sleep(900);

    await debugDump();

    if (/\blidl\./i.test(url)) {
      await closeOverlays(page);
      await sleep(600);
    }

    // 1) Direktes PDF?
    if(await sniffAndDownloadPdf(page, outPdf, flags)) return;

    // 2) Netzwerk-Collector
    const useImages = String(flags.mode||"auto")==="images" || preferImages;
    const shotsDir = path.join(path.dirname(outPdf), "__shots");
    await fs.mkdir(shotsDir, { recursive:true });

    // 2a) Network-Images
    let netImgs = [];
    {
      const collected = await collectViewerImages(page, prof, flags);
      netImgs = collected;
    }

    // 2b) DOM-Images (ergänzen/vereinigen)
    let domUrls = await collectDomImages(page, prof, flags);
    const uniq = new Map();
    for(const it of netImgs){ uniq.set(it.url, it.buf); }
    for(const u of domUrls){
      if(!uniq.has(u)){
        try {
          const buf = await fetchBytesInPage(page, u);
          uniq.set(u, buf);
        } catch { /* ignore */ }
      }
    }

    let ordered = [];
    if(useImages && uniq.size){
      ordered = Array.from(uniq.entries()).sort((a,b)=>{
        const getN = u => parseInt((u.match(/(\d{1,3})(?=\D*$)/)||[])[1]||"0",10);
        return getN(a[0]) - getN(b[0]) || a[0].localeCompare(b[0]);
      });

      let idx = 0;
      for(const [u, rawBuf] of ordered){
        idx++;
        let buf = rawBuf;
        let typ = sniffType(buf, u);

        try {
          if (typ === "webp" || typ === "avif") {
            buf = await toPNG(buf);
            typ = "png";
          }
        } catch (e) {
          ordered[idx-1] = null;
          continue;
        }

        const outExt = (typ === "jpg") ? "jpg" : "png";
        const fp = path.join(shotsDir, `page-${String(idx).padStart(3,"0")}.${outExt}`);
        await fs.writeFile(fp, buf);
        ordered[idx-1] = [u, buf, typ, fp];
      }
    }

    let mergedItems = ordered.filter(Boolean);
    if(useImages && uniq.size){
      console.log(`ℹ️  Images-Collector: ${mergedItems.length} Seitenbilder erkannt (Network+DOM).`);
    }

    if (useImages && mergedItems.length >= 3) {
      const pdfDoc = await PDFDocument.create();
      for (const [, buf, typ] of mergedItems) {
        let img;
        if (typ === "jpg") {
          img = await pdfDoc.embedJpg(buf);
        } else {
          img = await pdfDoc.embedPng(buf);
        }
        const { width: w, height: h } = img.size();
        const pagePdf = pdfDoc.addPage([w, h]);
        pagePdf.drawImage(img, { x:0, y:0, width:w, height:h });
      }
      const pdfBytes = await pdfDoc.save();
      await ensureDir(outPdf);
      await fs.writeFile(outPdf, pdfBytes);
      console.log(`✅ Viewer-Seiten exportiert → ${outPdf} (${mergedItems.length} Seiten)`);
      return;
    }

    // --- NEU: alle Seiten erfassen mit Fokus + Change-Detection ---
    const pagesPNGs = [];
    const signatures = [];
    let pageCount = 0;
    const pause = num(flags.delay, 900); // etwas großzügiger

    for (let i = 0; i < prof.maxPages; i++) {
      // 1) Viewer-Container finden + Fokus setzen
      let container = null;
      try { await page.waitForSelector(prof.pageContainer, { timeout: 6000 }); } catch {}
      try {
        container = await page.$(prof.pageContainer);
        if (container) { await container.click({ delay: 40 }).catch(()=>{}); }
      } catch {}

      await sleep(300);

      // 2) Screenshot (vom Container, sonst Fullpage)
      let pngBuffer = null;
      try { if (container) pngBuffer = await container.screenshot({}); } catch {}
      if (!pngBuffer) {
        pngBuffer = await page.screenshot({ fullPage: true, captureBeyondViewport: true, fromSurface: true });
      }

      // 3) Duplikatserkennung (MD5). Wenn identisch zur letzten Seite, sind wir fertig
      const sig = crypto.createHash("md5").update(pngBuffer).digest("hex");
      if (signatures.length && signatures[signatures.length - 1] === sig) break;
      signatures.push(sig);

      const pngPath = path.join(shotsDir, `page-${String(i + 1).padStart(3, "0")}.png`);
      await fs.writeFile(pngPath, pngBuffer);
      pagesPNGs.push(pngPath);
      pageCount++;

      // 4) NÄCHSTE SEITE: erst Klick auf "Next", dann Keyboard-Fallback
      let advanced = false;
      // a) Next-Button
      try {
        const next = await page.$(prof.nextSelector);
        if (next) {
          await next.click({ delay: 60 }).catch(()=>{});
          await sleep(pause);
          const probe = container
            ? await container.screenshot({}).catch(()=>null)
            : await page.screenshot({ fullPage:false }).catch(()=>null);
          if (probe) {
            const probeSig = crypto.createHash("md5").update(probe).digest("hex");
            advanced = probeSig !== sig;
          }
        }
      } catch {}

      // b) Keyboard-Fallbacks, falls Klick nicht weiterblättert
      if (!advanced) {
        const keys = ["ArrowRight", "PageDown", " ", "ArrowDown"];
        for (const key of keys) {
          try { if (container) await container.click({ delay: 20 }); } catch {}
          await page.keyboard.press(key).catch(()=>{});
          await sleep(pause);

          const probe = container
            ? await container.screenshot({}).catch(()=>null)
            : await page.screenshot({ fullPage:false }).catch(()=>null);
          if (probe) {
            const probeSig = crypto.createHash("md5").update(probe).digest("hex");
            if (probeSig !== sig) { advanced = true; break; }
          }
        }
      }

      // c) Wenn immer noch nicht weiter → Schluss
      if (!advanced) break;

      // d) kleines „Wiggle“, damit die neue Seite sicher rendert
      try { await evalSafe(page, () => window.scrollBy(0, 60)); } catch {}
      await sleep(200);
      try { await evalSafe(page, () => window.scrollBy(0, -60)); } catch {}
      await sleep(250);
    }

    if (pageCount === 0) {
      throw new Error("Keine Seiten erkannt – Viewer-Selektoren anpassen.");
    }

    // PNGs → PDF
    const pdfDoc = await PDFDocument.create();
    for (const p of pagesPNGs) {
      const bytes = await fs.readFile(p);
      const img = await pdfDoc.embedPng(bytes);      // unsere Screenshots sind echte PNGs
      const { width, height } = img.size();
      const page = pdfDoc.addPage([width, height]);
      page.drawImage(img, { x: 0, y: 0, width, height });
    }
    const pdfBytes = await pdfDoc.save();
    await ensureDir(outPdf);
    await fs.writeFile(outPdf, pdfBytes);
    console.log(`✅ Viewer-Seiten exportiert → ${outPdf} (${pageCount} Seiten)`);

  } finally {
    await browser.close();
  }
}

async function main(){
  const argv = process.argv.slice(2);
  const url = argv[0];
  const outPdf = argv[1];
  if(!url || !outPdf){
    console.error("Usage: node tools/leaflets/viewer2pdf.mjs <viewer_url> <out_pdf> [--next=SEL] [--container=SEL] [--max=N] [--delay=ms] [--scale=2.5] [--ua=STR] [--lang=de-DE]");
    process.exit(1);
  }
  const flags = parseFlags(argv.slice(2));
  await captureAllPages(url, path.resolve(outPdf), flags);
}

main().catch(e=>{ console.error(e); process.exit(1); });