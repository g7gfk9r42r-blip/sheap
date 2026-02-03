#!/usr/bin/env node
/**
 * Verarbeitet große Inputs in Chunks mit GPT-4
 */

import { OpenAI } from 'openai';
import fs from 'fs/promises';
import { config } from 'dotenv';

config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const CHUNK_SIZE = 15000; // Zeichen pro Chunk (~3750 Tokens)

const EXTRACTION_PROMPT = `Extrahiere ALLE LEBENSMITTEL (essbar/trinkbar) aus diesem Text.

NUR:
✅ Fleisch, Fisch, Wurst
✅ Käse, Milch, Joghurt, Butter
✅ Brot, Backwaren
✅ Obst, Gemüse
✅ Nudeln, Reis
✅ Pizza, TK-Ware
✅ Süßigkeiten
✅ Getränke: Wein, Bier, Whisky, Saft, Wasser

NICHT:
❌ Geräte, Maschinen
❌ Geschirr, Besteck
❌ Möbel, Textilien
❌ Werkzeug

FORMAT:
Produktname: [Name]
Preis: [X.XX €]
Menge: [XXX g/kg/ml/L]
Marke: [Marke]
Rabatt: [XX%]
Kategorie: [Fleisch/Fisch/Käse/Getränke/etc]
---

Beginne:`;

function splitIntoChunks(text, maxSize = CHUNK_SIZE) {
  const chunks = [];
  const offers = text.split('---\n\n');
  
  let currentChunk = '';
  
  for (const offer of offers) {
    if ((currentChunk + offer).length > maxSize && currentChunk.length > 0) {
      chunks.push(currentChunk);
      currentChunk = offer;
    } else {
      currentChunk += offer + '---\n\n';
    }
  }
  
  if (currentChunk.length > 0) {
    chunks.push(currentChunk);
  }
  
  return chunks;
}

async function extractChunk(chunk, chunkNum, totalChunks) {
  console.log(`   🔄 Chunk ${chunkNum}/${totalChunks} (${chunk.length} Zeichen)...`);
  
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein Experte für Lebensmittel-Extraktion. Extrahiere präzise nur essbare/trinkbare Produkte.'
        },
        {
          role: 'user',
          content: EXTRACTION_PROMPT + '\n\n' + chunk
        }
      ],
      temperature: 0,
      max_tokens: 3000
    });
    
    const result = completion.choices[0].message.content;
    const count = (result.match(/Produktname:/g) || []).length;
    
    console.log(`      ✅ ${count} Lebensmittel gefunden`);
    
    return result;
    
  } catch (err) {
    console.error(`      ❌ Fehler:`, err.message);
    return '';
  }
}

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🤖 GROSSE LIDL-EXTRAKTION MIT GPT-4');
  console.log('════════════════════════════════════════════════════════════════');
  console.log('');
  
  try {
    // 1. Input laden
    const text = await fs.readFile('input.txt', 'utf-8');
    console.log(`📄 Input: ${text.length} Zeichen\n`);
    
    // 2. In Chunks aufteilen
    const chunks = splitIntoChunks(text);
    console.log(`📦 Aufgeteilt in ${chunks.length} Chunks\n`);
    
    // 3. Jeden Chunk verarbeiten
    console.log('🤖 GPT-4 verarbeitet alle Chunks...\n');
    
    const results = [];
    for (let i = 0; i < chunks.length; i++) {
      const result = await extractChunk(chunks[i], i + 1, chunks.length);
      if (result) results.push(result);
      
      // Rate limiting
      if (i < chunks.length - 1) {
        await new Promise(r => setTimeout(r, 1000));
      }
    }
    
    // 4. Kombiniere Ergebnisse
    console.log('\n🔧 Kombiniere Ergebnisse...\n');
    
    const combined = results.join('\n\n');
    const totalProducts = (combined.match(/Produktname:/g) || []).length;
    
    console.log(`   ✅ Gesamt: ${totalProducts} Lebensmittel\n`);
    
    // 5. Deduplizierung
    const products = combined.split('---').filter(p => p.includes('Produktname:'));
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
    
    console.log(`   🧹 Nach Deduplizierung: ${unique.length} einzigartige Produkte\n`);
    
    // 6. Final formatieren
    let final = `# LIDL LEBENSMITTEL - WOCHE 50 (08.-13.12.2025)\n\n`;
    final += `📊 ${unique.length} Produkte extrahiert\n`;
    final += `📅 Extrahiert am: ${new Date().toLocaleDateString('de-DE')}\n\n`;
    final += `${'═'.repeat(70)}\n\n`;
    final += unique.join('\n\n');
    final += `\n\n${'═'.repeat(70)}\n`;
    final += `\n✅ FERTIG! ${unique.length} Lebensmittel für ChatGPT bereit!\n`;
    
    // 7. Speichern
    await fs.writeFile('lidl_lebensmittel_final.txt', final);
    await fs.writeFile('media/prospekte/lidl/2025/W50/lidl_lebensmittel.txt', final);
    
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ FERTIG!');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('');
    console.log('📁 Gespeichert:');
    console.log('   • lidl_lebensmittel_final.txt');
    console.log('   • media/prospekte/lidl/2025/W50/lidl_lebensmittel.txt');
    console.log('');
    console.log(`📦 Lebensmittel: ${unique.length}`);
    console.log(`💾 Größe: ${(final.length / 1024).toFixed(1)} KB`);
    console.log('');
    console.log('🎯 FÜR CHATGPT KOPIEREN:');
    console.log('   cat lidl_lebensmittel_final.txt | pbcopy');
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    process.exit(1);
  }
}

main();

