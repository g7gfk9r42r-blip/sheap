#!/usr/bin/env node
/**
 * 🤖 KOMPLETT-AUTOMATISMUS MIT GPT-4 VISION
 * 
 * 1. Findet beide Lidl-PDFs
 * 2. Konvertiert zu Bildern (Sample-Seiten)
 * 3. GPT-4 Vision extrahiert Lebensmittel
 * 4. Speichert als JSON (2 Dateien)
 * 5. Vergleicht die beiden
 * 6. Erstellt Rezepte!
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
  console.log('📦 Suche Lidl-PDFs...\n');
  
  const { stdout } = await execAsync(
    'find media/prospekte/lidl -name "*.pdf" -type f | sort -r'
  );
  
  const pdfs = stdout.trim().split('\n').filter(Boolean);
  
  // Dedupliziere (gleiche Datei, anderer Pfad)
  const unique = [];
  const seen = new Set();
  
  for (const pdf of pdfs) {
    const stats = await fs.stat(pdf);
    const key = `${stats.size}-${path.basename(pdf)}`;
    
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(pdf);
    }
  }
  
  // Nehme die ersten 2
  const result = unique.slice(0, 2);
  
  result.forEach((pdf, i) => {
    console.log(`   ${i + 1}. ${pdf}`);
  });
  
  console.log('');
  return result;
}

// ════════════════════════════════════════════════════════════════
// 2. PDF → BILDER (SAMPLE-SEITEN)
// ════════════════════════════════════════════════════════════════

async function pdfToImages(pdfPath, maxPages = 10) {
  console.log(`   📄 Konvertiere: ${path.basename(pdfPath)}`);
  
  const tempDir = await fs.mkdtemp('/tmp/lidl_vision_');
  const basename = path.basename(pdfPath, '.pdf');
  
  // Konvertiere erste N Seiten zu Bildern (150 DPI für Balance zwischen Qualität und Größe)
  try {
    await execAsync(
      `pdftoppm -png -r 150 -l ${maxPages} "${pdfPath}" "${tempDir}/${basename}"`
    );
    
    // Sammle alle PNG-Dateien
    const files = await fs.readdir(tempDir);
    const images = files
      .filter(f => f.endsWith('.png'))
      .map(f => path.join(tempDir, f))
      .sort();
    
    console.log(`      ✅ ${images.length} Seiten konvertiert\n`);
    
    return { tempDir, images };
    
  } catch (err) {
    console.error(`      ❌ Fehler: ${err.message}\n`);
    throw err;
  }
}

// ════════════════════════════════════════════════════════════════
// 3. GPT-4 VISION ANALYSE
// ════════════════════════════════════════════════════════════════

const VISION_PROMPT = `Analysiere dieses Lidl-Prospekt-Bild und extrahiere ALLE LEBENSMITTEL.

✅ WAS ICH WILL (essbare Produkte):
- Fleisch, Fisch, Wurst
- Käse, Milchprodukte (Butter, Joghurt)
- Brot, Backwaren
- Obst, Gemüse
- Nudeln, Reis, Kartoffeln
- Pizza, Tiefkühlware
- Süßigkeiten, Schokolade
- Gewürze, Saucen, Öl
- Eier, Mehl, Zucker

❌ WAS ICH NICHT WILL:
- Getränke (Wein, Bier, Saft, Cola)
- Kaffee, Tee
- Haushaltsgeräte, Möbel
- Kleidung, Werkzeug

WICHTIG:
- Extrahiere JEDEN sichtbaren Preis
- Achte auf Mengenangaben (g, kg, Stück)
- Notiere Rabatte (%)
- Marken/Produktnamen genau

Gib JSON zurück:
{
  "products": [
    {
      "name": "Produktname",
      "price": "X.XX",
      "unit": "XXX g/kg/Stück",
      "brand": "Marke",
      "discount": "XX%",
      "category": "Fleisch/Käse/etc"
    }
  ]
}

Falls keine Lebensmittel: {"products": []}`;

async function analyzeImageWithVision(imagePath, pageNum) {
  console.log(`      🔄 Seite ${pageNum}...`);
  
  try {
    // Lese Bild als Base64
    const imageBuffer = await fs.readFile(imagePath);
    const base64Image = imageBuffer.toString('base64');
    
    const response = await openai.chat.completions.create({
      model: 'gpt-4o', // GPT-4 Vision model
      messages: [
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
                detail: 'high'
              }
            }
          ]
        }
      ],
      max_tokens: 2000,
      temperature: 0
    });
    
    const content = response.choices[0].message.content;
    
    // Extrahiere JSON
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.log(`         ❌ Kein JSON in Antwort`);
      return { products: [] };
    }
    
    const data = JSON.parse(jsonMatch[0]);
    const count = data.products?.length || 0;
    
    console.log(`         ✅ ${count} Lebensmittel`);
    
    return data;
    
  } catch (err) {
    console.error(`         ❌ Fehler: ${err.message}`);
    return { products: [] };
  }
}

async function analyzePdfWithVision(pdfPath, pdfNum) {
  console.log(`\n📄 PROSPEKT ${pdfNum}: ${path.basename(pdfPath)}\n`);
  
  // Konvertiere zu Bildern
  const { tempDir, images } = await pdfToImages(pdfPath, 10);
  
  console.log(`   🤖 GPT-4 Vision analysiert ${images.length} Seiten...\n`);
  
  const allProducts = [];
  
  for (let i = 0; i < images.length; i++) {
    const data = await analyzeImageWithVision(images[i], i + 1);
    
    if (data.products) {
      allProducts.push(...data.products);
    }
    
    // Rate limiting
    if (i < images.length - 1) {
      await new Promise(r => setTimeout(r, 1000));
    }
  }
  
  // Cleanup
  await execAsync(`rm -rf "${tempDir}"`);
  
  return allProducts;
}

// ════════════════════════════════════════════════════════════════
// 4. SPEICHERN
// ════════════════════════════════════════════════════════════════

async function saveProducts(products, filename) {
  const data = {
    extractedAt: new Date().toISOString(),
    totalProducts: products.length,
    products: products
  };
  
  await fs.writeFile(filename, JSON.stringify(data, null, 2));
  console.log(`\n💾 Gespeichert: ${filename} (${products.length} Produkte)`);
}

// ════════════════════════════════════════════════════════════════
// 5. VERGLEICHEN
// ════════════════════════════════════════════════════════════════

function compareProducts(products1, products2) {
  console.log('\n════════════════════════════════════════════════════════════════');
  console.log('🔍 VERGLEICHE BEIDE PROSPEKTE');
  console.log('════════════════════════════════════════════════════════════════\n');
  
  console.log(`📦 Prospekt 1: ${products1.length} Produkte`);
  console.log(`📦 Prospekt 2: ${products2.length} Produkte\n`);
  
  // Finde Duplikate (gleicher Name)
  const names1 = new Set(products1.map(p => p.name?.toLowerCase()));
  const names2 = new Set(products2.map(p => p.name?.toLowerCase()));
  
  const onlyIn1 = products1.filter(p => !names2.has(p.name?.toLowerCase()));
  const onlyIn2 = products2.filter(p => !names1.has(p.name?.toLowerCase()));
  const inBoth = products1.filter(p => names2.has(p.name?.toLowerCase()));
  
  console.log(`✅ Gemeinsam: ${inBoth.length}`);
  console.log(`1️⃣ Nur in Prospekt 1: ${onlyIn1.length}`);
  console.log(`2️⃣ Nur in Prospekt 2: ${onlyIn2.length}\n`);
  
  // Preis-Unterschiede
  const priceDiffs = [];
  
  for (const p1 of products1) {
    const p2 = products2.find(p => 
      p.name?.toLowerCase() === p1.name?.toLowerCase()
    );
    
    if (p2 && p1.price !== p2.price) {
      priceDiffs.push({
        name: p1.name,
        price1: p1.price,
        price2: p2.price
      });
    }
  }
  
  if (priceDiffs.length > 0) {
    console.log(`⚠️  Preis-Unterschiede: ${priceDiffs.length}\n`);
    priceDiffs.slice(0, 5).forEach(d => {
      console.log(`   ${d.name}: ${d.price1} vs ${d.price2}`);
    });
    console.log('');
  }
  
  return {
    common: inBoth,
    onlyIn1,
    onlyIn2,
    priceDiffs
  };
}

// ════════════════════════════════════════════════════════════════
// 6. REZEPTE ERSTELLEN
// ════════════════════════════════════════════════════════════════

async function generateRecipes(allProducts) {
  console.log('\n════════════════════════════════════════════════════════════════');
  console.log('👨‍🍳 ERSTELLE REZEPTE MIT GPT-4');
  console.log('════════════════════════════════════════════════════════════════\n');
  
  // Erstelle Produkt-Liste
  const productList = allProducts
    .map(p => `- ${p.name} (${p.price} €${p.unit ? ', ' + p.unit : ''})`)
    .join('\n');
  
  const prompt = `Basierend auf diesen Lidl-Angeboten, erstelle mir 10 kreative Rezepte.

VERFÜGBARE ZUTATEN:
${productList}

ANFORDERUNGEN:
- Nutze hauptsächlich Zutaten aus der Liste
- Gesunde & ausgewogene Gerichte
- Mix: Fleisch, Fisch, Vegetarisch
- Preiswert (max. 15€ pro Gericht)
- Einfach nachzukochen

FORMAT:
Für jedes Rezept:
1. Name des Gerichts
2. Zutaten (mit Preisen aus der Liste!)
3. Kurze Anleitung (5-6 Schritte)
4. Gesamtpreis
5. Zubereitungszeit

Los geht's!`;
  
  console.log('🤖 GPT-4 erstellt Rezepte...\n');
  
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein kreativer Koch, der preiswerte Rezepte aus Supermarkt-Angeboten erstellt.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.8,
      max_tokens: 4000
    });
    
    const recipes = response.choices[0].message.content;
    
    // Speichern
    await fs.writeFile('lidl_rezepte.md', recipes);
    await fs.writeFile('media/prospekte/lidl/2025/W50/rezepte.md', recipes);
    
    console.log('✅ Rezepte erstellt!\n');
    console.log('📁 Gespeichert:');
    console.log('   • lidl_rezepte.md');
    console.log('   • media/prospekte/lidl/2025/W50/rezepte.md\n');
    
    return recipes;
    
  } catch (err) {
    console.error(`❌ Fehler: ${err.message}\n`);
    return null;
  }
}

// ════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🤖 LIDL VISION KOMPLETT-AUTOMATISMUS');
  console.log('════════════════════════════════════════════════════════════════\n');
  
  try {
    // 1. Finde PDFs
    const pdfs = await findLidlPdfs();
    
    if (pdfs.length === 0) {
      console.log('❌ Keine PDFs gefunden!');
      console.log('   Führe erst aus: npm run fetch:lidl\n');
      return;
    }
    
    if (pdfs.length === 1) {
      console.log('⚠️  Nur 1 PDF gefunden. Analysiere trotzdem...\n');
    }
    
    // 2. Analysiere beide PDFs
    const products1 = await analyzePdfWithVision(pdfs[0], 1);
    
    let products2 = [];
    if (pdfs[1]) {
      products2 = await analyzePdfWithVision(pdfs[1], 2);
    }
    
    // 3. Speichern
    console.log('\n════════════════════════════════════════════════════════════════');
    console.log('💾 SPEICHERE ERGEBNISSE');
    console.log('════════════════════════════════════════════════════════════════');
    
    await saveProducts(products1, 'lidl_prospekt_1.json');
    await saveProducts(products1, 'media/prospekte/lidl/2025/W50/prospekt_1_lebensmittel.json');
    
    if (products2.length > 0) {
      await saveProducts(products2, 'lidl_prospekt_2.json');
      await saveProducts(products2, 'media/prospekte/lidl/2025/W50/prospekt_2_lebensmittel.json');
    }
    
    // 4. Vergleichen
    if (products2.length > 0) {
      const comparison = compareProducts(products1, products2);
      
      // Speichere Vergleich
      await fs.writeFile(
        'lidl_vergleich.json',
        JSON.stringify(comparison, null, 2)
      );
      console.log('💾 Vergleich gespeichert: lidl_vergleich.json\n');
    }
    
    // 5. Kombiniere alle Produkte
    const allProducts = [...products1, ...products2];
    
    // Dedupliziere
    const unique = [];
    const seen = new Set();
    
    allProducts.forEach(p => {
      const key = p.name?.toLowerCase();
      if (key && !seen.has(key)) {
        seen.add(key);
        unique.push(p);
      }
    });
    
    console.log(`📦 Gesamt: ${unique.length} einzigartige Lebensmittel\n`);
    
    // 6. Erstelle Rezepte
    if (unique.length > 0) {
      await generateRecipes(unique);
    } else {
      console.log('⚠️  Keine Lebensmittel gefunden - keine Rezepte möglich\n');
    }
    
    // Fertig!
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ KOMPLETT FERTIG!');
    console.log('════════════════════════════════════════════════════════════════\n');
    
    console.log('📁 Erstellt:');
    console.log('   • lidl_prospekt_1.json - Lebensmittel aus PDF 1');
    if (products2.length > 0) {
      console.log('   • lidl_prospekt_2.json - Lebensmittel aus PDF 2');
      console.log('   • lidl_vergleich.json - Vergleich beider');
    }
    console.log('   • lidl_rezepte.md - 10 Rezepte!\n');
    
    console.log('🎯 NÄCHSTER SCHRITT:');
    console.log('   cat lidl_rezepte.md\n');
    
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

main();

