#!/usr/bin/env node
/**
 * Findet ALLE aktuellen Lidl-Prospekte (inkl. Food-Prospekt)
 */

import { chromium } from 'playwright';

async function findAllProspekte() {
  console.log('🔍 Suche alle Lidl-Prospekte...\n');
  
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Gehe zur Lidl-Prospekt-Übersicht
  console.log('📥 Öffne Lidl-Prospekt-Seite...');
  await page.goto('https://www.lidl.de/l/prospekte', { waitUntil: 'networkidle' });
  
  await page.waitForTimeout(3000);
  
  // Finde alle Prospekt-Links
  console.log('🔎 Suche Prospekt-Links...\n');
  
  const prospekte = await page.evaluate(() => {
    const links = [];
    
    // Suche nach Prospekt-Cards/Links
    const prospektElements = document.querySelectorAll('a[href*="/prospekte/"]');
    
    prospektElements.forEach(el => {
      const href = el.href;
      const title = el.innerText || el.getAttribute('aria-label') || el.getAttribute('title') || '';
      
      if (href && href.includes('/view/flyer')) {
        links.push({ url: href, title: title.trim() });
      }
    });
    
    return links;
  });
  
  console.log(`📋 ${prospekte.length} Prospekte gefunden:\n`);
  
  prospekte.forEach((p, i) => {
    console.log(`${i + 1}. ${p.title}`);
    console.log(`   URL: ${p.url}\n`);
  });
  
  await browser.close();
  
  // Finde das Food-Prospekt
  const foodProspekt = prospekte.find(p => 
    p.title.toLowerCase().includes('food') ||
    p.title.toLowerCase().includes('lebensmittel') ||
    p.title.toLowerCase().includes('kühl') ||
    p.title.toLowerCase().includes('kw ') ||
    (!p.title.toLowerCase().includes('aktion'))
  );
  
  if (foodProspekt) {
    console.log('✅ FOOD-PROSPEKT GEFUNDEN:\n');
    console.log(`   Titel: ${foodProspekt.title}`);
    console.log(`   URL: ${foodProspekt.url}\n`);
    console.log('🎯 JETZT AUSFÜHREN:\n');
    console.log(`   node tools/leaflets/fetch_lidl_leaflet.mjs "${foodProspekt.url}"\n`);
  } else {
    console.log('⚠️  Kein Food-Prospekt gefunden');
    console.log('💡 Probiere die URLs manuell aus\n');
  }
  
  return prospekte;
}

findAllProspekte().catch(console.error);

