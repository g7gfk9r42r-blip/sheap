#!/usr/bin/env node
/**
 * Extrahiert Lebensmittel aus BEIDEN Lidl-Prospekten mit GPT-4
 */

import { OpenAI } from 'openai';
import fs from 'fs/promises';
import { config } from 'dotenv';

// Lade .env
config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

if (!process.env.OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY fehlt in .env!');
  process.exit(1);
}

const EXTRACTION_PROMPT = `Du bist ein Experte für deutsche Supermarkt-Prospekte.

Extrahiere ALLE LEBENSMITTEL aus den folgenden Lidl-Angeboten.

WICHTIG - NUR ECHTE LEBENSMITTEL ZUM KOCHEN/ESSEN/TRINKEN:
✅ Fleisch, Fisch, Wurst, Geflügel
✅ Käse, Milch, Joghurt, Butter, Sahne
✅ Obst, Gemüse, Salat
✅ Brot, Backwaren, Brötchen
✅ Nudeln, Reis, Kartoffeln
✅ Pizza, Fertiggerichte, TK-Ware
✅ Süßigkeiten, Schokolade, Kekse
✅ Getränke: Saft, Wasser, Bier, Wein, Whisky, etc.
✅ Gewürze, Öl, Essig, Saucen
✅ Aufstriche, Marmelade, Honig
✅ Müsli, Cornflakes
✅ Konserven, Dosen

❌ NICHT extrahieren:
❌ Küchengeräte (Kaffeemaschinen, Mixer, Kochplatten)
❌ Geschirr (Teller, Tassen, Gläser, Besteck)
❌ Behälter (Vorratsdosen, Flaschen)
❌ Küchen-Utensilien (Messer, Töpfe, Pfannen, Bräter)
❌ Elektro-Geräte jeglicher Art
❌ Kleidung, Spielzeug, Möbel

FORMAT für jedes Lebensmittel:
Produktname: [vollständiger Name]
Preis: [X.XX €]
Menge: [XXX g/kg/ml/L/Stück]
Marke: [Markenname oder "-"]
Rabatt: [XX% oder "-"]
Kategorie: [z.B. Fleisch, Käse, Getränke]
---

Sei SEHR strikt: Nur essbare/trinkbare Produkte!
Sortiere nach Kategorien: Fleisch → Fisch → Käse → Brot → Gemüse → Obst → TK → Getränke → Süßigkeiten → Sonstiges

Beginne jetzt:`;

async function loadOffers() {
  console.log('📦 Lade Angebote aus beiden Prospekten...\n');
  
  // Lade beide Offers JSON
  const offers1Path = 'data/lidl/2025/W50/offers_1.json';
  const offers2Path = 'data/lidl/2025/W50/offers_471943.json';
  
  const allOffers = [];
  
  try {
    const data1 = JSON.parse(await fs.readFile(offers1Path, 'utf-8'));
    console.log(`   Prospekt 1: ${data1.offers?.length || 0} Angebote`);
    allOffers.push(...(data1.offers || []));
  } catch (err) {
    console.log(`   ⚠️  Prospekt 1 nicht gefunden`);
  }
  
  try {
    const data2 = JSON.parse(await fs.readFile(offers2Path, 'utf-8'));
    console.log(`   Prospekt 2: ${data2.offers?.length || 0} Angebote`);
    allOffers.push(...(data2.offers || []));
  } catch (err) {
    console.log(`   ⚠️  Prospekt 2 nicht gefunden`);
  }
  
  // Dedupliziere nach ID
  const uniqueOffers = [];
  const seen = new Set();
  
  for (const offer of allOffers) {
    if (!seen.has(offer.id)) {
      seen.add(offer.id);
      uniqueOffers.push(offer);
    }
  }
  
  console.log(`\n   ✅ Gesamt: ${uniqueOffers.length} einzigartige Angebote\n`);
  
  return uniqueOffers;
}

function offersToText(offers) {
  let text = 'LIDL ANGEBOTE - WOCHE 50 (08.12. - 13.12.2025)\n\n';
  
  offers.forEach((offer, i) => {
    text += `\nAngebot ${i + 1}:\n`;
    text += `Titel: ${offer.title}\n`;
    text += `Preis: ${offer.price} €\n`;
    if (offer.unit) text += `Menge: ${offer.unit}\n`;
    if (offer.brand) text += `Marke: ${offer.brand}\n`;
    if (offer.originalPrice && offer.originalPrice > offer.price) {
      const discount = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
      text += `Original-Preis: ${offer.originalPrice} € (${discount}% Rabatt)\n`;
    }
    if (offer.categories && offer.categories.length > 0) {
      const cat = offer.categories[0].split('/').pop();
      text += `Kategorie: ${cat}\n`;
    }
    text += '\n';
  });
  
  return text;
}

async function extractWithGPT(text) {
  console.log('🤖 GPT-4 analysiert die Angebote...');
  console.log('   (Dies kann 30-60 Sekunden dauern)\n');
  
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein Experte für deutsche Supermarkt-Angebote. Du extrahierst präzise nur echte Lebensmittel (essbar/trinkbar) aus Prospekten.'
        },
        {
          role: 'user',
          content: EXTRACTION_PROMPT + '\n\n' + text
        }
      ],
      temperature: 0.1,
      max_tokens: 4000
    });
    
    return completion.choices[0].message.content;
  } catch (err) {
    console.error('❌ GPT-4 Fehler:', err.message);
    
    if (err.code === 'insufficient_quota') {
      console.error('\n💡 TIPP: Dein OpenAI Account hat kein Guthaben.');
      console.error('   Gehe zu https://platform.openai.com/account/billing');
      console.error('   und lade Guthaben auf (~$5 reichen für Monate).\n');
    }
    
    throw err;
  }
}

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🤖 LIDL LEBENSMITTEL MIT GPT-4 EXTRAHIEREN');
  console.log('════════════════════════════════════════════════════════════════');
  console.log('');
  
  try {
    // 1. Lade beide Prospekte
    const offers = await loadOffers();
    
    if (offers.length === 0) {
      console.error('❌ Keine Angebote gefunden!');
      process.exit(1);
    }
    
    // 2. Konvertiere zu Text
    console.log('📝 Bereite Daten für GPT vor...\n');
    const text = offersToText(offers);
    console.log(`   Text: ${text.length} Zeichen`);
    console.log(`   ~${Math.round(text.length / 4)} Tokens\n`);
    
    // 3. GPT analysieren
    const result = await extractWithGPT(text);
    
    console.log('✅ GPT-4 Analyse abgeschlossen!\n');
    
    // 4. Speichern
    const outputPath = 'lidl_lebensmittel_gpt.txt';
    await fs.writeFile(outputPath, result);
    
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
    
    // Vorschau
    console.log('📋 VORSCHAU (erste 500 Zeichen):');
    console.log('────────────────────────────────────────────────────────────────');
    console.log(result.substring(0, 500));
    console.log('...\n');
    
    console.log('🎯 NÄCHSTE SCHRITTE:');
    console.log('');
    console.log('1. Komplette Datei anschauen:');
    console.log(`   cat ${outputPath}`);
    console.log('');
    console.log('2. Für ChatGPT kopieren:');
    console.log(`   cat ${outputPath} | pbcopy`);
    console.log('');
    console.log('3. In ChatGPT einfügen:');
    console.log('   "Erstelle mir 10 Rezepte für 2 Personen basierend auf');
    console.log('    diesen Lidl-Angeboten (nutze möglichst viele):"');
    console.log('');
    console.log('════════════════════════════════════════════════════════════════');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    
    if (err.stack) {
      console.error('\nDetails:', err.stack);
    }
    
    process.exit(1);
  }
}

main();

