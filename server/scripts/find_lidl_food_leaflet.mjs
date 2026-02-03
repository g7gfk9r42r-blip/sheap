#!/usr/bin/env node
/**
 * Findet die richtige Lidl-Prospekt-URL für Lebensmittel-Angebote
 * 
 * Usage:
 *   node scripts/find_lidl_food_leaflet.mjs
 */

import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function findFoodLeafletUrl() {
  console.log('🔍 Suche nach Lebensmittel-Prospekt-URL...\n');
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
  });
  const page = await context.newPage();
  
  try {
    // Öffne Lidl-Prospekt-Übersicht
    await page.goto('https://www.lidl.de/c/online-prospekte/s10005610', {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });
    
    await page.waitForTimeout(3000);
    
    // Suche nach Lebensmittel-Prospekten
    const foodLeaflets = await page.evaluate(() => {
      const leaflets = [];
      const links = document.querySelectorAll('a[href*="/l/prospekte/"], a[href*="/prospekt/"]');
      
      for (const link of links) {
        const href = link.href;
        const text = (link.textContent || '').toLowerCase();
        const parentText = (link.closest('article, .product, .flyer-card, [class*="prospekt"]')?.textContent || '').toLowerCase();
        
        // Prüfe ob Lebensmittel-bezogen
        const foodKeywords = [
          'aktionsprospekt', 'lebensmittel', 'nahrung', 'essen',
          'milch', 'brot', 'käse', 'fleisch', 'obst', 'gemüse',
        ];
        
        const isFood = foodKeywords.some(keyword => 
          text.includes(keyword) || parentText.includes(keyword)
        );
        
        if (isFood && href.includes('/l/prospekte/') || href.includes('/prospekt/')) {
          leaflets.push({
            url: href,
            title: text,
          });
        }
      }
      
      return leaflets;
    });
    
    if (foodLeaflets.length > 0) {
      console.log('✅ Lebensmittel-Prospekte gefunden:\n');
      foodLeaflets.slice(0, 5).forEach((leaflet, index) => {
        console.log(`${index + 1}. ${leaflet.title}`);
        console.log(`   ${leaflet.url}\n`);
      });
      
      const firstUrl = foodLeaflets[0].url;
      console.log(`💡 Verwende diese URL in .env:\n`);
      console.log(`LIDL_LEAFLET_URL=${firstUrl}\n`);
      
      return firstUrl;
    } else {
      console.log('⚠️  Keine Lebensmittel-Prospekte gefunden');
      console.log('💡 Versuche Standard-URL...\n');
      
      // Versuche Standard-Prospekt-URL
      const standardUrl = 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
      
      await page.goto(standardUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(3000);
      
      // Prüfe ob Lebensmittel vorhanden sind
      const hasFood = await page.evaluate(() => {
        const text = document.body.textContent || '';
        const foodKeywords = ['milch', 'brot', 'käse', 'fleisch', 'obst', 'gemüse', 'lebensmittel'];
        return foodKeywords.some(keyword => text.toLowerCase().includes(keyword));
      });
      
      if (hasFood) {
        console.log('✅ Standard-URL enthält Lebensmittel');
        console.log(`LIDL_LEAFLET_URL=${standardUrl}\n`);
        return standardUrl;
      } else {
        console.log('⚠️  Standard-URL enthält keine Lebensmittel');
        console.log('💡 Bitte manuell die richtige Prospekt-URL in .env setzen\n');
        return null;
      }
    }
    
  } catch (error) {
    console.error('❌ Fehler:', error.message);
    return null;
  } finally {
    await browser.close();
  }
}

findFoodLeafletUrl().then(url => {
  if (url) {
    console.log('✅ Fertig! Verwende die obige URL in deiner .env Datei.');
  } else {
    console.log('❌ Konnte keine Lebensmittel-Prospekt-URL finden.');
  }
  process.exit(url ? 0 : 1);
});

