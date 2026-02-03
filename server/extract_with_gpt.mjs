#!/usr/bin/env node
/**
 * Extrahiert Lebensmittel aus Lidl-PDF mit GPT-4 Vision
 * Automatisch und strukturiert!
 */

import { OpenAI } from 'openai';
import fs from 'fs/promises';
import path from 'path';
import { createReadStream } from 'fs';

// OpenAI Client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || ''
});

if (!process.env.OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY fehlt!');
  console.error('');
  console.error('Setze den API Key:');
  console.error('  export OPENAI_API_KEY="sk-..."');
  console.error('');
  console.error('Oder erstelle .env Datei:');
  console.error('  echo "OPENAI_API_KEY=sk-..." > .env');
  process.exit(1);
}

const PROMPT = `Du bist ein Experte für deutsche Supermarkt-Prospekte.

Extrahiere ALLE Lebensmittel aus diesem Lidl-Prospekt.

WICHTIG - NUR ECHTE LEBENSMITTEL:
✅ Fleisch, Fisch, Wurst
✅ Käse, Milch, Joghurt, Butter
✅ Obst, Gemüse, Salat
✅ Brot, Backwaren
✅ Nudeln, Reis, Kartoffeln
✅ Pizza, Fertiggerichte
✅ Süßigkeiten, Snacks
✅ Getränke (Saft, Wasser, Alkohol)
✅ Gewürze, Öl, Aufstriche

❌ KEINE Geräte (Kaffeemaschinen, Mixer, etc.)
❌ KEINE Geschirr, Besteck
❌ KEINE Kleidung, Spielzeug

FORMAT (für jedes Produkt):
Produktname: [Name]
Preis: [X.XX €]
Menge: [XXX g/kg/ml/L/Stück]
Marke: [Marke oder "-"]
Rabatt: [XX% oder "-"]
---

Beispiel:
Produktname: Frische Grobe Bratwurst
Preis: 4.99 €
Menge: 1 kg
Marke: Metzgerfrisch
Rabatt: 30%
---

Extrahiere ALLE Lebensmittel systematisch Seite für Seite.`;

/**
 * Liest die PDF und konvertiert zu Text
 */
async function extractTextFromPDF(pdfPath) {
  console.log('📄 Lese PDF...');
  
  // Nutze die bereits geholtene Offers JSON
  const offersPath = 'data/lidl/2025/W50/offers_1.json';
  
  try {
    const data = JSON.parse(await fs.readFile(offersPath, 'utf-8'));
    console.log(`✅ ${data.offers.length} Angebote aus API geladen`);
    
    // Konvertiere zu Text für GPT
    let text = 'LIDL PROSPEKT - AKTUELLE ANGEBOTE\n\n';
    
    data.offers.forEach((offer, i) => {
      text += `\nAngebot ${i + 1}:\n`;
      text += `Titel: ${offer.title}\n`;
      text += `Preis: ${offer.price} €\n`;
      if (offer.unit) text += `Menge: ${offer.unit}\n`;
      if (offer.brand) text += `Marke: ${offer.brand}\n`;
      if (offer.originalPrice) {
        const discount = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
        text += `Rabatt: ${discount}%\n`;
      }
      if (offer.description) {
        text += `Info: ${offer.description.substring(0, 200)}...\n`;
      }
      if (offer.categories) {
        text += `Kategorie: ${offer.categories.join(', ')}\n`;
      }
      text += '---\n';
    });
    
    return text;
  } catch (err) {
    console.error('❌ Fehler beim Lesen der Offers:', err.message);
    throw err;
  }
}

/**
 * GPT-4 analysiert den Text
 */
async function analyzeWithGPT(text) {
  console.log('\n🤖 GPT-4 analysiert die Angebote...');
  console.log('   (Dies kann 30-60 Sekunden dauern)\n');
  
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein Experte für Lebensmittel-Angebote und extrahierst strukturierte Daten aus Supermarkt-Prospekten.'
        },
        {
          role: 'user',
          content: PROMPT + '\n\n' + text
        }
      ],
      temperature: 0.1,
      max_tokens: 4000
    });
    
    return completion.choices[0].message.content;
  } catch (err) {
    console.error('❌ GPT-4 Fehler:', err.message);
    throw err;
  }
}

/**
 * Hauptfunktion
 */
async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🤖 LIDL LEBENSMITTEL-EXTRAKTION MIT GPT-4');
  console.log('════════════════════════════════════════════════════════════════');
  console.log('');
  
  try {
    // 1. PDF-Daten laden
    const text = await extractTextFromPDF();
    
    console.log(`📝 Textlänge: ${text.length} Zeichen`);
    console.log('');
    
    // 2. GPT analysieren lassen
    const result = await analyzeWithGPT(text);
    
    console.log('✅ GPT-4 Analyse abgeschlossen!');
    console.log('');
    
    // 3. Speichern
    const outputPath = 'lidl_lebensmittel_gpt.txt';
    await fs.writeFile(outputPath, result);
    
    // 4. Auch in Wochen-Ordner kopieren
    const weekPath = 'media/prospekte/lidl/2025/W50/lidl_lebensmittel_gpt.txt';
    await fs.writeFile(weekPath, result);
    
    console.log('════════════════════════════════════════════════════════════════');
    console.log('✅ FERTIG!');
    console.log('════════════════════════════════════════════════════════════════');
    console.log('');
    console.log('📁 Gespeichert:');
    console.log(`   1. ${outputPath}`);
    console.log(`   2. ${weekPath}`);
    console.log('');
    console.log(`📊 Größe: ${(result.length / 1024).toFixed(1)} KB`);
    console.log('');
    console.log('🎯 NÄCHSTE SCHRITTE:');
    console.log('');
    console.log('1. Text anschauen:');
    console.log(`   cat ${outputPath}`);
    console.log('');
    console.log('2. Text kopieren:');
    console.log(`   cat ${outputPath} | pbcopy`);
    console.log('');
    console.log('3. In ChatGPT einfügen:');
    console.log('   "Erstelle mir 10 Rezepte basierend auf diesen Angeboten:"');
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    process.exit(1);
  }
}

main();

