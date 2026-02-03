// tools/edeka/resolve_viewer.mjs
import puppeteer from "puppeteer";

const sleep = (ms)=>new Promise(r=>setTimeout(r,ms));

async function acceptConsent(page){
  try{
    await page.waitForTimeout(800);
    const x = await page.$x("//button[contains(., 'Zustimmen') or contains(., 'Akzeptieren') or contains(., 'Einverstanden') or contains(., 'Accept')]");
    if(x.length){ await x[0].click({delay:40}); await page.waitForTimeout(800); }
  }catch{}
}

async function main(){
  const marketUrl = process.argv[2];
  if(!marketUrl){
    console.error("Usage: node tools/edeka/resolve_viewer.mjs <EDEKA_MARKT_URL>");
    process.exit(1);
  }

  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox","--disable-setuid-sandbox","--lang=de-DE,de"],
    defaultViewport: { width: 1600, height: 1200, deviceScaleFactor: 2 },
  });
  try{
    const page = await browser.newPage();
    await page.setUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127 Safari/537.36");
    await page.setExtraHTTPHeaders({ "Accept-Language": "de-DE,de;q=0.9,en;q=0.8" });

    await page.goto(marketUrl, { waitUntil:"domcontentloaded", timeout:90000 });
    await acceptConsent(page);
    await page.waitForNetworkIdle({idleTime:1000, timeout:15000}).catch(()=>{});

    // 1) Versuche offensichtliche Links/Buttons zum Prospekt
    // Häufig: "Prospekt", "Angebote", "Blätterkatalog", "Prospekt ansehen"
    const candidates = await page.$$eval("a,button", els => els
      .filter(e=>{
        const t=(e.innerText||"").toLowerCase();
        const a=(e.getAttribute("href")||"")+(e.getAttribute("data-href")||"");
        return /prospekt|angebote|blätterkatalog|flyer/.test(t) || /prospekt|leaflet|flyer|angebote/.test(a);
      })
      .map(e=>e.href||e.getAttribute("href")||e.getAttribute("data-href")||"")
      .filter(Boolean)
    );

    // 2) Fallback: Suche im DOM nach iframes/embeds, die auf einen Viewer zeigen
    const frames = await page.$$eval("iframe, frame", els => els.map(e=>e.src).filter(Boolean));

    // 3) Konsolidiere & nimm den ersten „viewer“/„flyer“-Kandidaten
    const all = [...candidates, ...frames].filter(Boolean);
    // EDEKA nutzt häufig Pfade mit ".../view/flyer" oder ".../prospekt/..."
    const viewer = all.find(u=>/view\/flyer|prospekt|leaflet|angebote/i.test(u)) || all[0];

    if(!viewer){
      console.error("❌ Kein Viewer-Link gefunden. Öffne im Browser die Marktseite, navigiere zu 'Angebote/Prospekt' und kopiere dort die URL.");
      process.exit(2);
    }

    // Viele Links sind relativ → absolut machen
    const absolute = new URL(viewer, marketUrl).toString();
    console.log(absolute);
  } finally {
    await browser.close();
  }
}

main().catch(e=>{ console.error(e); process.exit(1); });

