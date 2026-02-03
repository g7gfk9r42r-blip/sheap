#!/usr/bin/env node
/**
 * 🍖 LEBENSMITTEL-EXTRAKTOR (OHNE GETRÄNKE!)
 * 
 * Nimmt den kopierten Text aus input.txt und extrahiert NUR:
 * - Fleisch, Fisch, Käse, Gemüse, etc.
 * - KEINE Getränke (Wein, Bier, Whisky, Saft, etc.)
 * - KEINE Haushaltsgeräte, Möbel, etc.
 */

import { OpenAI } from 'openai';
import fs from 'fs/promises';
import { config } from 'dotenv';

config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const CHUNK_SIZE = 15000;

const FOOD_ONLY_PROMPT = `Extrahiere ALLE KOCH-LEBENSMITTEL aus diesem Text.

✅ WAS ICH WILL (essbare Produkte zum Kochen):
- 🥩 Fleisch: Rind, Schwein, Hähnchen, Ente, Gans, Lamm, Kaninchen
- 🐟 Fisch & Meeresfrüchte: Lachs, Forelle, Garnelen, Austern, Hummer
- 🧀 Käse & Milchprodukte: Gouda, Camembert, Mozzarella, Butter, Joghurt, Quark, Mascarpone
- 🥖 Brot & Backwaren: Brötchen, Baguette, Croissant
- 🥕 Gemüse & Obst: Karotten, Tomaten, Pilze, Zwiebeln, Knoblauch, Zitronen, Orangen
- 🍝 Nudeln, Reis, Kartoffeln
- 🍕 Tiefkühlware: Pizza, Nuggets, TK-Gemüse
- 🍫 Süßigkeiten, Schokolade, Pralinen
- 🧂 Gewürze, Saucen, Öl, Essig, Senf
- 🥚 Eier, Mehl, Zucker, Backzutaten
- 🫒 Oliven, Antipasti, Dips
- 🥜 Nüsse, Trockenfrüchte
- 🍯 Honig, Marmelade, Aufstriche

❌ WAS ICH NICHT WILL:
- 🍷 Getränke: Wein, Bier, Whisky, Rum, Vodka, Champagner, Prosecco
- ☕ Kaffee, Tee, Saft, Wasser, Cola, Limonade
- 🏠 Haushaltsgeräte, Küchengeräte, Geschirr
- 👔 Kleidung, Textilien, Möbel
- 🔧 Werkzeug, Elektronik, Deko

Falls es KEINE echten Koch-Lebensmittel gibt, schreibe:
"Keine Koch-Lebensmittel gefunden. Diese Woche nur Getränke."

FORMAT (pro Produkt):
Produktname: [Name]
Preis: [X.XX €]
Menge: [XXX g/kg/ml/Stück]
Marke: [Marke wenn vorhanden]
Rabatt: [XX% wenn vorhanden]
Info: [Kurze Beschreibung]
---

Beginne:`;

function splitIntoChunks(text, maxSize = CHUNK_SIZE) {
  const chunks = [];
  const offers = text.split('---');
  
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
          content: 'Du bist ein Experte für Lebensmittel-Klassifizierung. Du extrahierst NUR essbare Koch-Produkte (Fleisch, Fisch, Käse, Gemüse, etc.) - NIEMALS Getränke!'
        },
        {
          role: 'user',
          content: FOOD_ONLY_PROMPT + '\n\n' + chunk
        }
      ],
      temperature: 0,
      max_tokens: 3000
    });
    
    const result = completion.choices[0].message.content;
    
    // Prüfe ob "keine Lebensmittel"
    if (result.includes('Keine Koch-Lebensmittel gefunden')) {
      console.log(`      ❌ Keine Koch-Lebensmittel in diesem Chunk`);
      return '';
    }
    
    const count = (result.match(/Produktname:/g) || []).length;
    console.log(`      ✅ ${count} Koch-Lebensmittel gefunden`);
    
    return result;
    
  } catch (err) {
    console.error(`      ❌ Fehler:`, err.message);
    return '';
  }
}

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🍖 LIDL KOCH-LEBENSMITTEL EXTRAKTOR (OHNE GETRÄNKE!)');
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
    console.log('🤖 GPT-4 extrahiert Koch-Lebensmittel...\n');
    
    const results = [];
    for (let i = 0; i < chunks.length; i++) {
      const result = await extractChunk(chunks[i], i + 1, chunks.length);
      if (result) results.push(result);
      
      // Rate limiting
      if (i < chunks.length - 1) {
        await new Promise(r => setTimeout(r, 1000));
      }
    }
    
    if (results.length === 0) {
      console.log('\n⚠️  Keine Koch-Lebensmittel gefunden!');
      console.log('   Diese Woche hat Lidl hauptsächlich Getränke.');
      console.log('');
      return;
    }
    
    // 4. Kombiniere Ergebnisse
    console.log('\n🔧 Kombiniere Ergebnisse...\n');
    
    const combined = results.join('\n\n');
    const totalProducts = (combined.match(/Produktname:/g) || []).length;
    
    console.log(`   ✅ Gesamt: ${totalProducts} Produkte\n`);
    
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
    let final = `# LIDL KOCH-LEBENSMITTEL - WOCHE 50 (08.-13.12.2025)\n\n`;
    final += `📊 ${unique.length} Koch-Lebensmittel extrahiert (OHNE Getränke!)\n`;
    final += `📅 Extrahiert am: ${new Date().toLocaleDateString('de-DE')}\n\n`;
    final += `${'═'.repeat(70)}\n\n`;
    final += unique.join('\n\n');
    final += `\n\n${'═'.repeat(70)}\n`;
    final += `\n✅ FERTIG! ${unique.length} Koch-Lebensmittel für ChatGPT bereit!\n`;
    
    // 7. Speichern
    await fs.writeFile('lidl_koch_lebensmittel.txt', final);
    await fs.writeFile('media/prospekte/lidl/2025/W50/koch_lebensmittel.txt', final);
    
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ FERTIG!');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('');
    console.log('📁 Gespeichert:');
    console.log('   • lidl_koch_lebensmittel.txt');
    console.log('   • media/prospekte/lidl/2025/W50/koch_lebensmittel.txt');
    console.log('');
    console.log(`📦 Koch-Lebensmittel: ${unique.length}`);
    console.log(`💾 Größe: ${(final.length / 1024).toFixed(1)} KB`);
    console.log('');
    console.log('🎯 FÜR CHATGPT KOPIEREN:');
    console.log('   cat lidl_koch_lebensmittel.txt | pbcopy');
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    process.exit(1);
  }
}

main();

