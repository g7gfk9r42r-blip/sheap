#!/usr/bin/env node
/**
 * 🤖 KOMPLETTER AUTOMATISMUS: PDF → Text → Lebensmittel
 * 
 * MACHT ALLES AUTOMATISCH:
 * 1. Findet neueste Lidl-PDF
 * 2. Konvertiert zu Text
 * 3. Speichert als .txt
 * 4. GPT-4 extrahiert NUR ECHTE LEBENSMITTEL (keine Getränke)
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
// 1. PDF FINDEN & TEXT EXTRAHIEREN
// ════════════════════════════════════════════════════════════════

async function findLatestPdf() {
  const baseDir = 'media/prospekte/lidl';
  
  // Versuche verschiedene Wege
  const possiblePaths = [
    'media/prospekte/lidl/2025/W50/lidl_2025-W50.pdf',
    'media/prospekte/lidl/2025/W51/lidl_2025-W51.pdf',
  ];
  
  // Finde alle PDFs im Verzeichnis
  try {
    const years = await fs.readdir(baseDir);
    for (const year of years.reverse()) {
      const yearPath = path.join(baseDir, year);
      const stat = await fs.stat(yearPath);
      if (!stat.isDirectory()) continue;
      
      const weeks = await fs.readdir(yearPath);
      for (const week of weeks.reverse()) {
        const weekPath = path.join(yearPath, week);
        const files = await fs.readdir(weekPath);
        const pdf = files.find(f => f.endsWith('.pdf'));
        if (pdf) {
          return path.join(weekPath, pdf);
        }
      }
    }
  } catch (err) {
    console.log('   📁 Suche in bekannten Pfaden...');
  }
  
  // Fallback: Prüfe bekannte Pfade
  for (const p of possiblePaths) {
    try {
      await fs.access(p);
      return p;
    } catch {}
  }
  
  throw new Error('Keine PDF gefunden!');
}

async function extractTextFromPdf(pdfPath) {
  console.log(`   📄 Lese PDF: ${pdfPath}`);
  
  // Verwende pdftotext (viel besser für Text-Extraktion!)
  const outputPath = pdfPath.replace('.pdf', '_extracted.txt');
  
  try {
    // pdftotext -layout bewahrt Layout, -raw für reinen Text
    await execAsync(`pdftotext -layout "${pdfPath}" "${outputPath}"`);
    
    const text = await fs.readFile(outputPath, 'utf-8');
    
    console.log(`   ✅ ${text.length} Zeichen extrahiert`);
    
    // Temporäre Datei löschen
    await fs.unlink(outputPath).catch(() => {});
    
    return text;
    
  } catch (err) {
    console.error(`   ❌ Fehler bei pdftotext: ${err.message}`);
    throw err;
  }
}

// ════════════════════════════════════════════════════════════════
// 2. GPT-4 LEBENSMITTEL-EXTRAKTION (OHNE GETRÄNKE!)
// ════════════════════════════════════════════════════════════════

const FOOD_EXTRACTION_PROMPT = `Extrahiere ALLE LEBENSMITTEL aus diesem Lidl-Prospekt.

✅ WAS ICH WILL (essbare Produkte zum Kochen):
- Fleisch, Wurst, Schinken
- Fisch, Meeresfrüchte
- Käse, Milchprodukte (Butter, Joghurt, Quark)
- Brot, Backwaren
- Obst, Gemüse
- Nudeln, Reis, Kartoffeln
- Pizza, Tiefkühlware
- Süßigkeiten, Schokolade
- Gewürze, Saucen, Öl
- Eier, Mehl, Zucker

❌ WAS ICH NICHT WILL:
- Getränke (Wein, Bier, Whisky, Saft, Wasser, Cola, etc.)
- Kaffee, Tee
- Haushaltsgeräte, Möbel
- Kleidung, Textilien
- Werkzeug, Elektronik

Falls es KEINE echten Lebensmittel gibt, schreibe:
"Keine Koch-Lebensmittel gefunden. Diese Woche nur Getränke/Non-Food."

FORMAT (pro Produkt):
Produktname: [Name]
Preis: [X.XX €]
Menge: [XXX g/kg/Stück]
Marke: [Marke]
Rabatt: [XX%]
Info: [Kurze Beschreibung]
---

Beginne:`;

async function extractFoodWithGPT(text) {
  // Text in Chunks aufteilen (max. 15000 Zeichen)
  const chunkSize = 15000;
  const chunks = [];
  
  for (let i = 0; i < text.length; i += chunkSize) {
    chunks.push(text.slice(i, i + chunkSize));
  }
  
  console.log(`\n🤖 GPT-4 verarbeitet ${chunks.length} Chunks...\n`);
  
  const results = [];
  
  for (let i = 0; i < chunks.length; i++) {
    console.log(`   🔄 Chunk ${i + 1}/${chunks.length}...`);
    
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4-turbo-preview',
        messages: [
          {
            role: 'system',
            content: 'Du bist ein Experte für Lebensmittel-Extraktion. Du extrahierst NUR essbare Produkte zum Kochen - KEINE Getränke!'
          },
          {
            role: 'user',
            content: FOOD_EXTRACTION_PROMPT + '\n\n' + chunks[i]
          }
        ],
        temperature: 0,
        max_tokens: 3000
      });
      
      const result = completion.choices[0].message.content;
      const count = (result.match(/Produktname:/g) || []).length;
      
      console.log(`      ✅ ${count} Lebensmittel gefunden`);
      
      if (count > 0) {
        results.push(result);
      }
      
      // Rate limiting
      if (i < chunks.length - 1) {
        await new Promise(r => setTimeout(r, 1000));
      }
      
    } catch (err) {
      console.error(`      ❌ Fehler:`, err.message);
    }
  }
  
  return results.join('\n\n');
}

// ════════════════════════════════════════════════════════════════
// 3. HAUPT-FUNKTION
// ════════════════════════════════════════════════════════════════

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🤖 AUTOMATISCHE LIDL LEBENSMITTEL-EXTRAKTION');
  console.log('════════════════════════════════════════════════════════════════');
  console.log('');
  
  try {
    // SCHRITT 1: PDF finden
    console.log('📦 SCHRITT 1: PDF finden...\n');
    const pdfPath = await findLatestPdf();
    console.log(`   ✅ Gefunden: ${pdfPath}\n`);
    
    // SCHRITT 2: Text extrahieren
    console.log('📄 SCHRITT 2: Text aus PDF extrahieren...\n');
    const text = await extractTextFromPdf(pdfPath);
    
    // Text speichern
    const pdfDir = path.dirname(pdfPath);
    const textPath = path.join(pdfDir, 'prospekt_komplett.txt');
    await fs.writeFile(textPath, text, 'utf-8');
    console.log(`   💾 Text gespeichert: ${textPath}\n`);
    
    // SCHRITT 3: Lebensmittel extrahieren (mit GPT-4)
    console.log('🍖 SCHRITT 3: Lebensmittel extrahieren (GPT-4)...\n');
    const foodText = await extractFoodWithGPT(text);
    
    // Deduplizierung
    console.log('\n🔧 Deduplizierung...\n');
    const products = foodText.split('---').filter(p => p.includes('Produktname:'));
    const unique = [];
    const seen = new Set();
    
    products.forEach(p => {
      const nameMatch = p.match(/Produktname:\s*(.+)/);
      if (nameMatch) {
        const name = nameMatch[1].trim().toLowerCase();
        if (!seen.has(name)) {
          seen.add(name);
          unique.push(p + '---');
        }
      }
    });
    
    console.log(`   ✅ ${unique.length} einzigartige Lebensmittel\n`);
    
    // SCHRITT 4: Speichern
    console.log('💾 SCHRITT 4: Ergebnisse speichern...\n');
    
    const week = pdfPath.match(/W(\d+)/)?.[0] || 'unknown';
    const finalText = `# LIDL LEBENSMITTEL (NUR ESSBARE PRODUKTE) - ${week}

📊 ${unique.length} Koch-Lebensmittel extrahiert (OHNE Getränke!)
📅 Extrahiert am: ${new Date().toLocaleDateString('de-DE')}

${'═'.repeat(70)}

${unique.join('\n\n')}

${'═'.repeat(70)}

✅ FERTIG! ${unique.length} Koch-Lebensmittel für ChatGPT bereit!
`;
    
    // Speichern
    const foodPath = path.join(pdfDir, 'lebensmittel_ohne_getraenke.txt');
    await fs.writeFile(foodPath, finalText, 'utf-8');
    console.log(`   ✅ Lebensmittel: ${foodPath}`);
    
    // Auch in Server-Root
    await fs.writeFile('lidl_lebensmittel_fertig.txt', finalText, 'utf-8');
    console.log(`   ✅ Kopie: lidl_lebensmittel_fertig.txt`);
    
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ FERTIG!');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('');
    console.log(`📦 ${unique.length} Koch-Lebensmittel (ohne Getränke)`);
    console.log(`📁 PDF-Text: ${textPath}`);
    console.log(`📁 Lebensmittel: ${foodPath}`);
    console.log('');
    console.log('🎯 FÜR CHATGPT:');
    console.log('   cat lidl_lebensmittel_fertig.txt | pbcopy');
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
    if (unique.length === 0) {
      console.log('');
      console.log('⚠️  HINWEIS: Keine Koch-Lebensmittel gefunden!');
      console.log('   Diese Woche hat Lidl hauptsächlich Getränke/Non-Food.');
      console.log('');
    }
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

main();

