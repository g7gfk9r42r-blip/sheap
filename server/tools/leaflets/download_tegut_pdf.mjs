#!/usr/bin/env node
// Download TEGUT PDF

import { chromium } from 'playwright';
import fs from 'fs/promises';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const viewerUrl = 'https://view.publitas.com/93620/2567758';
const outputPath = resolve(__dirname, '../../media/prospekte/tegut/tegut_2025-W48_Oberbayern.pdf');

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
const page = await context.newPage();

try {
  console.log('📥 Öffne Publitas Viewer...');
  await page.goto(viewerUrl, { waitUntil: 'networkidle', timeout: 30000 });
  
  // Warte auf Download-Button oder versuche PDF-URL zu finden
  console.log('🔍 Suche nach PDF-Download-Link...');
  
  // Versuche Download-Button zu finden und zu klicken
  const downloadButton = await page.locator('button:has-text("Download"), a:has-text("Download"), [data-download]').first().waitFor({ timeout: 5000 }).catch(() => null);
  
  if (downloadButton) {
    console.log('📥 Klicke auf Download-Button...');
    const download = await Promise.all([
      page.waitForEvent('download', { timeout: 30000 }),
      downloadButton.click()
    ]).then(([download]) => download);
    
    await fs.mkdir(dirname(outputPath), { recursive: true });
    await download.saveAs(outputPath);
  } else {
    // Versuche PDF-URL aus der Seite zu extrahieren
    console.log('🔍 Versuche PDF-URL aus der Seite zu extrahieren...');
    const pdfUrl = await page.evaluate(() => {
      // Suche nach PDF-Links
      const links = Array.from(document.querySelectorAll('a[href*=".pdf"], a[href*="/pdfs/"]'));
      return links[0]?.href || null;
    });
    
    if (pdfUrl) {
      console.log('📥 Gefundene PDF-URL:', pdfUrl);
      const response = await page.goto(pdfUrl, { waitUntil: 'networkidle', timeout: 30000 });
      const buffer = await response.body();
      await fs.mkdir(dirname(outputPath), { recursive: true });
      await fs.writeFile(outputPath, buffer);
    } else {
      throw new Error('PDF-URL konnte nicht gefunden werden');
    }
  }
  
  const stats = await fs.stat(outputPath);
  if (stats.size === 0) {
    throw new Error('Downloaded file is empty');
  }
  
  console.log('✅ PDF erfolgreich heruntergeladen:', outputPath);
  console.log('📊 Größe:', (stats.size / 1024 / 1024).toFixed(2), 'MB');
} catch (err) {
  console.error('❌ Fehler:', err.message);
  console.error('💡 Hinweis: Die URL könnte abgelaufen sein oder spezielle Authentifizierung erfordern.');
  process.exit(1);
} finally {
  await browser.close();
}

