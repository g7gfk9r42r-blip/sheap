#!/usr/bin/env node
/**
 * AUTOMATISCHER PROZESSOR FÜR KOPIERTEN LIDL-TEXT
 * 
 * Workflow:
 * 1. Du kopierst Text aus PDF
 * 2. Speicherst in input.txt
 * 3. Script verarbeitet automatisch mit GPT-4
 * 4. Fertige, strukturierte Datei kommt raus
 */

import { OpenAI } from 'openai';
import fs from 'fs/promises';
import { existsSync } from 'fs';
import { config } from 'dotenv';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const EXTRACTION_PROMPT = `Du bist ein Experte für Lebensmittel-Angebote aus deutschen Supermarkt-Prospekten.

AUFGABE: Extrahiere ALLE LEBENSMITTEL aus dem folgenden Text.

REGELN:
✅ NUR ESSBARE/TRINKBARE PRODUKTE:
  - Fleisch, Wurst, Fisch, Geflügel
  - Käse, Milch, Joghurt, Butter, Quark, Sahne
  - Obst, Gemüse, Salat, Kartoffeln
  - Brot, Brötchen, Backwaren, Kuchen
  - Nudeln, Reis, Pasta
  - Pizza, Fertiggerichte, TK-Ware
  - Süßigkeiten, Schokolade, Kekse, Eis
  - Getränke: Saft, Wasser, Cola, Bier, Wein, Spirituosen
  - Gewürze, Öl, Essig, Saucen, Pesto
  - Aufstriche, Marmelade, Honig
  - Konserven, Dosen mit Lebensmitteln

❌ NICHT extrahieren:
  - Küchengeräte, Elektrogeräte
  - Geschirr, Besteck, Gläser
  - Behälter, Dosen (leer)
  - Werkzeug, Textilien
  - Alles was man NICHT essen/trinken kann

OUTPUT-FORMAT (sehr wichtig!):
Produktname: [Vollständiger Name]
Preis: [X.XX €]
Menge: [XXX g/kg/ml/L/Stück]
Marke: [Markenname oder "-"]
Rabatt: [XX% oder "-"]
Kategorie: [Fleisch/Fisch/Käse/Brot/Gemüse/Obst/TK/Getränke/Süßigkeiten/Sonstiges]
---

WICHTIG:
- Extrahiere JEDES Lebensmittel
- Sei sehr genau bei Preisen und Mengen
- Gruppiere nach Kategorien
- Keine Duplikate

Beginne jetzt mit der Extraktion:`;

async function getInputText() {
  console.log('📄 Suche Input-Text...\n');
  
  // Prüfe verschiedene Input-Quellen
  const sources = [
    { path: 'input.txt', name: 'input.txt' },
    { path: 'lidl_raw_text.txt', name: 'lidl_raw_text.txt' },
    { path: 'text_aus_pdf.txt', name: 'text_aus_pdf.txt' },
  ];
  
  for (const source of sources) {
    if (existsSync(source.path)) {
      const text = await fs.readFile(source.path, 'utf-8');
      console.log(`✅ Input gefunden: ${source.name} (${text.length} Zeichen)\n`);
      return text;
    }
  }
  
  // Fallback: Aus Zwischenablage lesen (macOS)
  try {
    console.log('💡 Versuche aus Zwischenablage zu lesen...\n');
    const { stdout } = await execAsync('pbpaste');
    if (stdout && stdout.length > 100) {
      console.log(`✅ Text aus Zwischenablage gelesen (${stdout.length} Zeichen)\n`);
      
      // Speichere auch als input.txt für nächstes Mal
      await fs.writeFile('input.txt', stdout);
      console.log(`💾 Auch gespeichert als: input.txt\n`);
      
      return stdout;
    }
  } catch (err) {
    // Ignore
  }
  
  console.error('❌ Kein Input gefunden!\n');
  console.error('OPTIONEN:\n');
  console.error('1. Erstelle input.txt mit dem kopierten Text:');
  console.error('   [Text aus PDF kopieren]');
  console.error('   Dann: pbpaste > input.txt\n');
  console.error('2. Oder kopiere Text und führe sofort aus:');
  console.error('   [Text kopieren]');
  console.error('   Dann: node process_copied_text.mjs\n');
  process.exit(1);
}

async function extractWithGPT(text) {
  console.log('🤖 GPT-4 extrahiert Lebensmittel...');
  console.log('   (30-60 Sekunden)\n');
  
  const startTime = Date.now();
  
  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'Du bist ein präziser Extraktions-Experte für Lebensmittel-Angebote. Du arbeitest strukturiert und vollständig.'
        },
        {
          role: 'user',
          content: EXTRACTION_PROMPT + '\n\nTEXT AUS PROSPEKT:\n\n' + text
        }
      ],
      temperature: 0,
      max_tokens: 4000
    });
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`✅ GPT-4 fertig! (${duration}s)\n`);
    
    return completion.choices[0].message.content;
    
  } catch (err) {
    console.error('❌ GPT-4 Fehler:', err.message);
    
    if (err.code === 'insufficient_quota') {
      console.error('\n💳 Kein Guthaben! Lade auf: https://platform.openai.com/account/billing\n');
    } else if (err.status === 401) {
      console.error('\n🔑 API Key ungültig! Prüfe .env Datei\n');
    }
    
    throw err;
  }
}

async function postProcess(text) {
  console.log('🔧 Nachbearbeitung...\n');
  
  // Bereinige
  let cleaned = text.trim();
  
  // Zähle Produkte
  const productCount = (cleaned.match(/Produktname:/g) || []).length;
  console.log(`   ✅ ${productCount} Lebensmittel gefunden\n`);
  
  // Füge Header hinzu
  const header = `# LIDL LEBENSMITTEL - WOCHE 50 (08.-13.12.2025)\n\n`;
  const stats = `📊 ${productCount} Produkte extrahiert\n`;
  const date = `📅 Extrahiert am: ${new Date().toLocaleDateString('de-DE')}\n\n`;
  const separator = `${'═'.repeat(70)}\n\n`;
  
  cleaned = header + stats + date + separator + cleaned;
  
  // Füge Footer hinzu
  cleaned += `\n\n${'═'.repeat(70)}\n`;
  cleaned += `\n✅ FERTIG! ${productCount} Lebensmittel für ChatGPT bereit!\n`;
  
  return cleaned;
}

async function main() {
  console.log('═'.repeat(70));
  console.log('🤖 AUTOMATISCHER LIDL-PROZESSOR');
  console.log('═'.repeat(70));
  console.log('\n');
  
  try {
    // 1. Input lesen
    const inputText = await getInputText();
    
    console.log(`📊 Input: ${inputText.length} Zeichen`);
    console.log(`   ~${Math.round(inputText.length / 4)} GPT-Tokens\n`);
    
    // 2. GPT-4 Extraktion
    const extracted = await extractWithGPT(inputText);
    
    // 3. Nachbearbeitung
    const final = await postProcess(extracted);
    
    // 4. Speichern (mehrere Orte)
    const outputs = [
      'lidl_lebensmittel_final.txt',
      'media/prospekte/lidl/2025/W50/lidl_lebensmittel.txt',
    ];
    
    for (const outPath of outputs) {
      await fs.writeFile(outPath, final);
    }
    
    console.log('═'.repeat(70));
    console.log('✅ FERTIG!');
    console.log('═'.repeat(70));
    console.log('');
    console.log('📁 Gespeichert in:');
    outputs.forEach(p => console.log(`   • ${p}`));
    console.log('');
    console.log(`📊 Größe: ${(final.length / 1024).toFixed(1)} KB`);
    console.log(`📦 Produkte: ${(final.match(/Produktname:/g) || []).length}`);
    console.log('');
    console.log('🎯 JETZT FÜR CHATGPT KOPIEREN:');
    console.log('');
    console.log('   cat lidl_lebensmittel_final.txt | pbcopy');
    console.log('');
    console.log('═'.repeat(70));
    
    // Vorschau
    console.log('\n📋 VORSCHAU:\n');
    const preview = final.substring(0, 800);
    console.log(preview);
    if (final.length > 800) console.log('\n... [mehr Text]\n');
    
  } catch (err) {
    console.error('\n❌ FEHLER:', err.message);
    process.exit(1);
  }
}

main();

