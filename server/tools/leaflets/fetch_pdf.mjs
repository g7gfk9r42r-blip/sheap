import fs from "fs/promises";
import path from "path";
import fse from "fs-extra";
import puppeteer from "puppeteer";

const [, , URL, OUTFILE] = process.argv;
if (!URL || !OUTFILE) {
  console.error("Usage: node fetch_pdf.mjs <url> <outfile.pdf>");
  process.exit(1);
}

const isPdf = (u) => /\.pdf(\?|$)/i.test(u);
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36";

async function fetchBinary(u) {
  const res = await fetch(u, { headers: { "user-agent": UA } });
  if (!res.ok) throw new Error("HTTP " + res.status + " for " + u);
  return Buffer.from(await res.arrayBuffer());
}

(async () => {
  await fse.ensureDir(path.dirname(OUTFILE));

  if (isPdf(URL)) {
    const buf = await fetchBinary(URL);
    await fs.writeFile(OUTFILE, buf);
    console.log("✅ PDF gespeichert:", OUTFILE);
    return;
  }

  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox","--disable-setuid-sandbox","--lang=de-DE,de"],
    defaultViewport: { width: 1440, height: 1000, deviceScaleFactor: 2 }
  });
  try {
    const page = await browser.newPage();
    await page.setUserAgent(UA);
    await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 60000 }).catch(()=>{});
    // Banner verstecken
    try {
      await page.addStyleTag({content: `
        [id*="cookie" i],[class*="cookie" i],[role="dialog"],[aria-label*="cookie" i]{
          display:none !important; visibility:hidden !important; opacity:0 !important; pointer-events:none !important;
        }`});
    } catch {}
    try { await page.waitForNetworkIdle({ idleTime: 1200, timeout: 20000 }); } catch {}

    // PDF-Link suchen
    const pdfHref = await page.evaluate(()=>{
      const as = [...document.querySelectorAll('a[href$=".pdf"], a[href*=".pdf?"]')];
      return as.length ? as[0].href : null;
    });

    if (pdfHref) {
      const buf = await (await fetch(pdfHref)).arrayBuffer();
      await fs.writeFile(OUTFILE, Buffer.from(buf));
      console.log("✅ PDF (aus Link) gespeichert:", OUTFILE);
    } else {
      // sauberer Print-Fallback
      const client = await page.target().createCDPSession();
      const { data } = await client.send("Page.printToPDF", {
        printBackground: true, scale: 1,
        paperWidth: 8.27, paperHeight: 11.69,
        marginTop:0, marginBottom:0, marginLeft:0, marginRight:0
      });
      await fs.writeFile(OUTFILE, Buffer.from(data, "base64"));
      console.log("✅ PDF (print) gespeichert:", OUTFILE);
    }
  } finally {
    await browser.close();
  }
})();
