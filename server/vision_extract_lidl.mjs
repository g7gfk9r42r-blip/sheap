#!/usr/bin/env node
/**
 * 🔍 LIDL VISION-EXTRAKTION MIT GPT-4 VISION
 * 
 * 1. Findet beide PDFs im Lidl-Ordner
 * 2. Konvertiert PDF → Bilder
 * 3. GPT-4 Vision analysiert jede Seite
 * 4. Extrahiert NUR Lebensmittel
 * 5. Speichert als JSON
 * 6. Vergleicht beide Prospekte
 * 7. Bei Unterschieden: Nochmal prüfen
 * 8. Erstellt Rezepte
 */

import fs from 'fs/promises';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';
import { OpenAI } from 'openai';
import { config } from 'dotenv';

config();

const execAsync = promisify(exec);

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// ════════════════════════════════════════════════════════════════
// 1. PDF FINDEN
// ════════════════════════════════════════════════════════════════

async function findLidlPdfs() {
  const baseDir = 'media/prospekte/lidl';
  const pdfs = [];
  
  async function searchDir(dir) {
    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        
        if (entry.isDirectory()) {
          await searchDir(fullPath);
        } else if (entry.name.endsWith('.pdf')) {
          const stat = await fs.stat(fullPath);
          pdfs.push({
            path: fullPath,
            name: entry.name,
            size: stat.size,
            modified: stat.mtime
          });
        }
      }
    } catch (err) {
      // Ignore
    }
  }
  
  await searchDir(baseDir);
  
  // Sortiere nach Änderungsdatum (neueste zuerst)
  pdfs.sort((a, b) => b.modified - a.modified);
  
  return pdfs.slice(0, 2); // Nehme die 2 neuesten
}

// ════════════════════════════════════════════════════════════════
// 2. PDF → BILDER KONVERTIEREN
// ════════════════════════════════════════════════════════════════

async function pdfToImages(pdfPath, outputDir) {
  console.log(`   🖼️  Konvertiere PDF zu Bildern...`);
  
  // Erstelle Output-Verzeichnis
  await fs.mkdir(outputDir, { recursive: true });
  
  // Verwende pdftoppm (von poppler-utils)
  // Konvertiert jede Seite zu PNG
  const outputPrefix = path.join(outputDir, 'page');
  
  try {
    await execAsync(`pdftoppm -png -r 150 "${pdfPath}" "${outputPrefix}"`);
    
    // Finde alle erstellten Bilder
    const files = await fs.readdir(outputDir);
    const images = files
      .filter(f => f.endsWith('.png'))
      .sort()
      .map(f => path.join(outputDir, f));
    
    console.log(`   ✅ ${images.length} Seiten konvertiert`);
    
    return images;
    
  } catch (err) {
    console.error(`   ❌ Fehler bei Konvertierung: ${err.message}`);
    throw err;
  }
}

// ════════════════════════════════════════════════════════════════
// 3. GPT-4 VISION: LEBENSMITTEL EXTRAHIEREN
// ════════════════════════════════════════════════════════════════

const VISION_PROMPT = `Analysiere diese Prospektseite von Lidl.

Extrahiere ALLE LEBENSMITTEL (essbare Produkte):

✅ EXTRAHIEREN:
- Fleisch, Wurst, Schinken
- Fisch, Meeresfrüchte
- Käse, Milchprodukte
- Gemüse, Obst
- Brot, Backwaren
- Nudeln, Reis
- Tiefkühlware, Pizza
- Süßigkeiten, Schokolade
- Gewürze, Saucen, Öl

❌ IGNORIEREN:
- Getränke (Wein, Bier, Saft, etc.)
- Haushaltsgeräte, Möbel
- Kleidung, Spielzeug

Falls KEINE Lebensmittel auf dieser Seite: Gib leeres Array zurück.

ANTWORT FORMAT (JSON):
{
  "products": [
    {
      "name": "Produktname",
      "price": "X.XX",
      "unit": "XXX g/kg/Stück",
      "brand": "Marke",
      "discount": "XX%",
      "category": "Fleisch/Fisch/Käse/etc"
    }
  ]
}`;

async function analyzePageWithVision(imagePath, pageNum) {
  console.log(`   🔍 Seite ${pageNum}: Analysiere mit GPT-4 Vision...`);
  
  try {
    // Lese Bild als Base64
    const imageBuffer = await fs.readFile(imagePath);
    const base64Image = imageBuffer.toString('base64');
    
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',  // GPT-4 mit Vision
      messages: [
        {
          role: 'system',
          content: 'Du bist ein Experte für Lebensmittel-Extraktion aus Prospekten. Analysiere Bilder präzise und extrahiere nur essbare Produkte.'
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: VISION_PROMPT
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/png;base64,${base64Image}`,
                detail: 'high'  // Hohe Detailstufe
              }
            }
          ]
        }
      ],
      max_tokens: 2000,
      temperature: 0
    });
    
    const content = response.choices[0].message.content;
    
    // Parse JSON
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const data = JSON.parse(jsonMatch[0]);
      console.log(`      ✅ ${data.products.length} Lebensmittel gefunden`);
      return data.products;
    }
    
    console.log(`      ℹ️  Keine Lebensmittel auf dieser Seite`);
    return [];
    
  } catch (err) {
    console.error(`      ❌ Fehler: ${err.message}`);
    return [];
  }
}

// ════════════════════════════════════════════════════════════════
// 4. KOMPLETTE PDF VERARBEITEN
// ════════════════════════════════════════════════════════════════

async function processPdf(pdfPath, prospektNum) {
  console.log(`\n${'═'.repeat(70)}`);
  console.log(`📄 PROSPEKT ${prospektNum}: ${path.basename(pdfPath)}`);
  console.log(`${'═'.repeat(70)}\n`);
  
  // Erstelle Temp-Ordner für Bilder
  const tempDir = path.join(path.dirname(pdfPath), `temp_images_${prospektNum}`);
  
  try {
    // 1. PDF → Bilder
    const images = await pdfToImages(pdfPath, tempDir);
    
    // 2. Analysiere jede Seite (max. 10 Seiten für Demo)
    const maxPages = Math.min(images.length, 10);
    console.log(`\n   🔄 Analysiere ${maxPages} Seiten...\n`);
    
    const allProducts = [];
    
    for (let i = 0; i < maxPages; i++) {
      const products = await analyzePageWithVision(images[i], i + 1);
      allProducts.push(...products);
      
      // Rate limiting
      if (i < maxPages - 1) {
        await new Promise(r => setTimeout(r, 2000));
      }
    }
    
    console.log(`\n   ✅ Gesamt: ${allProducts.length} Lebensmittel extrahiert\n`);
    
    // 3. Aufräumen
    console.log(`   🧹 Räume temporäre Bilder auf...`);
    await execAsync(`rm -rf "${tempDir}"`);
    
    return allProducts;
    
  } catch (err) {
    console.error(`\n   ❌ Fehler bei Verarbeitung: ${err.message}\n`);
    
    // Aufräumen auch bei Fehler
    try {
      await execAsync(`rm -rf "${tempDir}"`);
    } catch {}
    
    return [];
  }
}

// ════════════════════════════════════════════════════════════════
// 5. PROSPEKTE VERGLEICHEN
// ════════════════════════════════════════════════════════════════

function compareProspekte(prospekt1, prospekt2) {
  console.log(`\n${'═'.repeat(70)}`);
  console.log(`🔍 VERGLEICHE PROSPEKTE`);
  console.log(`${'═'.repeat(70)}\n`);
  
  const products1 = new Map(prospekt1.products.map(p => [p.name.toLowerCase(), p]));
  const products2 = new Map(prospekt2.products.map(p => [p.name.toLowerCase(), p]));
  
  const onlyIn1 = [];
  const onlyIn2 = [];
  const inBoth = [];
  const differences = [];
  
  // Produkte nur in Prospekt 1
  for (const [name, product] of products1) {
    if (!products2.has(name)) {
      onlyIn1.push(product);
    } else {
      const p2 = products2.get(name);
      inBoth.push({ prospekt1: product, prospekt2: p2 });
      
      // Preisunterschiede?
      if (product.price !== p2.price) {
        differences.push({
          name: product.name,
          type: 'price',
          prospekt1: product.price,
          prospekt2: p2.price
        });
      }
    }
  }
  
  // Produkte nur in Prospekt 2
  for (const [name, product] of products2) {
    if (!products1.has(name)) {
      onlyIn2.push(product);
    }
  }
  
  console.log(`   📊 Statistik:`);
  console.log(`      • Nur in Prospekt 1: ${onlyIn1.length}`);
  console.log(`      • Nur in Prospekt 2: ${onlyIn2.length}`);
  console.log(`      • In beiden: ${inBoth.length}`);
  console.log(`      • Preisunterschiede: ${differences.length}`);
  console.log(``);
  
  if (differences.length > 0) {
    console.log(`   ⚠️  PREISUNTERSCHIEDE GEFUNDEN:\n`);
    differences.slice(0, 5).forEach(d => {
      console.log(`      • ${d.name}`);
      console.log(`        Prospekt 1: ${d.prospekt1} € | Prospekt 2: ${d.prospekt2} €`);
    });
    console.log(``);
  }
  
  return {
    onlyIn1,
    onlyIn2,
    inBoth,
    differences
  };
}

// ════════════════════════════════════════════════════════════════
// 6. REZEPTE ERSTELLEN
// ════════════════════════════════════════════════════════════════

async function generateRecipes(allProducts) {
  console.log(`\n${'═'.repeat(70)}`);
  console.log(`👨‍🍳 ERSTELLE REZEPTE`);
  console.log(`${'═'.repeat(70)}\n`);
  
  // Alle einzigartigen Produkte sammeln
  const uniqueProducts = new Map();
  allProducts.forEach(p => {
    uniqueProducts.set(p.name.toLowerCase(), p);
  });
  
  const productList = Array.from(uniqueProducts.values());
  
  console.log(`   📦 ${productList.length} einzigartige Lebensmittel\n`);
  
  // Erstelle Produktliste für GPT
  const productText = productList
    .map(p => `- ${p.name} (${p.price} €, ${p.unit || ''})`)
    .join('\n');
  
  console.log(`   🤖 GPT-4 erstellt Rezepte...\n`);
  
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein kreativer Koch. Erstelle abwechslungsreiche, leckere Rezepte basierend auf verfügbaren Zutaten.'
        },
        {
          role: 'user',
          content: `Erstelle 5 kreative Rezepte basierend auf diesen Lidl-Angeboten:

${productText}

FORMAT pro Rezept:
# [Rezeptname]
**Zutaten:** [Liste mit Mengenangaben]
**Zubereitung:** [Schritt-für-Schritt]
**Kosten:** ca. X €
---`
        }
      ],
      temperature: 0.8,
      max_tokens: 3000
    });
    
    const recipes = response.choices[0].message.content;
    
    console.log(`   ✅ Rezepte erstellt!\n`);
    
    return recipes;
    
  } catch (err) {
    console.error(`   ❌ Fehler: ${err.message}\n`);
    return '';
  }
}

// ════════════════════════════════════════════════════════════════
// 7. HAUPT-FUNKTION
// ════════════════════════════════════════════════════════════════

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🔍 LIDL VISION-EXTRAKTION & REZEPT-GENERATOR');
  console.log('════════════════════════════════════════════════════════════════');
  console.log('');
  
  try {
    // 1. Finde PDFs
    console.log('📦 Suche Lidl-Prospekte...\n');
    const pdfs = await findLidlPdfs();
    
    if (pdfs.length === 0) {
      console.log('❌ Keine PDFs gefunden!');
      console.log('   Führe erst aus: npm run fetch:lidl');
      return;
    }
    
    console.log(`   ✅ ${pdfs.length} PDF(s) gefunden:`);
    pdfs.forEach((pdf, i) => {
      console.log(`      ${i + 1}. ${pdf.name} (${(pdf.size / 1024 / 1024).toFixed(1)} MB)`);
    });
    
    // 2. Verarbeite beide PDFs
    const results = [];
    
    for (let i = 0; i < Math.min(pdfs.length, 2); i++) {
      const products = await processPdf(pdfs[i].path, i + 1);
      
      const result = {
        prospekt: i + 1,
        filename: pdfs[i].name,
        path: pdfs[i].path,
        products: products
      };
      
      results.push(result);
      
      // Speichere JSON
      const jsonPath = pdfs[i].path.replace('.pdf', '_lebensmittel.json');
      await fs.writeFile(jsonPath, JSON.stringify(result, null, 2));
      console.log(`   💾 Gespeichert: ${path.basename(jsonPath)}\n`);
    }
    
    // 3. Vergleiche (falls 2 Prospekte)
    let comparison = null;
    if (results.length === 2) {
      comparison = compareProspekte(results[0], results[1]);
    }
    
    // 4. Sammle alle Produkte
    const allProducts = results.flatMap(r => r.products);
    
    if (allProducts.length === 0) {
      console.log('\n⚠️  Keine Lebensmittel gefunden!');
      console.log('   Diese Woche hauptsächlich Getränke/Non-Food.');
      return;
    }
    
    // 5. Erstelle Rezepte
    const recipes = await generateRecipes(allProducts);
    
    // 6. Speichere alles
    const outputDir = path.dirname(results[0].path);
    
    // Rezepte
    const recipesPath = path.join(outputDir, 'lidl_rezepte.txt');
    await fs.writeFile(recipesPath, recipes);
    console.log(`   💾 Rezepte: ${path.basename(recipesPath)}`);
    
    // Vergleich (falls vorhanden)
    if (comparison) {
      const comparisonPath = path.join(outputDir, 'prospekte_vergleich.json');
      await fs.writeFile(comparisonPath, JSON.stringify(comparison, null, 2));
      console.log(`   💾 Vergleich: ${path.basename(comparisonPath)}`);
    }
    
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ FERTIG!');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('');
    console.log(`📊 Ergebnisse:`);
    console.log(`   • ${allProducts.length} Lebensmittel extrahiert`);
    console.log(`   • ${results.length} JSON-Dateien erstellt`);
    console.log(`   • Rezepte erstellt`);
    if (comparison) {
      console.log(`   • Prospekte verglichen`);
    }
    console.log('');
    console.log('📁 Dateien:');
    console.log(`   • ${recipesPath}`);
    results.forEach(r => {
      const jsonPath = r.path.replace('.pdf', '_lebensmittel.json');
      console.log(`   • ${jsonPath}`);
    });
    console.log('');
    console.log('🎯 Rezepte anzeigen:');
    console.log(`   cat "${recipesPath}"`);
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

main();

