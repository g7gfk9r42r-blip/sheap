#!/usr/bin/env node
/**
 * Test-Script für Lidl-Prospekt LLM-Extraktion via Crawl4AI
 * Nutzt LLMExtractionStrategy für strukturierte Datenextraktion
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();
dotenv.config({ path: resolve(__dirname, '.env.local'), override: false });

const BASE_URL = process.env.CRAWL4AI_BASE_URL?.trim();
const TOKEN = process.env.CRAWL4AI_TOKEN?.trim();
const OPENAI_API_KEY = process.env.OPENAI_API_KEY?.trim();

if (!BASE_URL) {
  console.error('❌ Keine Base URL gesetzt (CRAWL4AI_BASE_URL).');
  process.exit(1);
}

if (!OPENAI_API_KEY) {
  console.warn('⚠️  OPENAI_API_KEY nicht gesetzt. LLM-Extraktion benötigt einen OpenAI API Key.');
  console.warn('   Setze OPENAI_API_KEY in .env oder .env.local');
}

const LIDL_URL = 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
const crawlEndpoint = `${BASE_URL.replace(/\/+$/, '')}/crawl`;

async function main() {
  console.log('🧪 Lidl Prospekt LLM-Extraktion Test');
  console.log(`   URL: ${LIDL_URL}`);
  console.log(`   Base URL: ${BASE_URL}`);
  console.log(`   LLM Provider: openai/gpt-4o-mini\n`);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 300_000); // 5 Minuten Timeout

  try {
    const requestBody = {
      urls: [LIDL_URL],
      crawler_config: {
        type: 'CrawlerRunConfig',
        params: {
          extraction_strategy: {
            type: 'LLMExtractionStrategy',
            params: {
              llm_config: {
                type: 'LLMConfig',
                params: {
                  provider: 'openai/gpt-4o-mini',
                  api_token: 'env:OPENAI_API_KEY',
                },
              },
              instruction: 'Extrahiere alle Produkte im Prospekt als JSON. Felder: name, price, unit, discount, imageUrl.',
              schema: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    name: { type: 'string' },
                    price: { type: 'string' },
                    unit: { type: 'string' },
                    discount: { type: 'string' },
                    imageUrl: { type: 'string' },
                  },
                },
              },
              extraction_type: 'schema',
            },
          },
        },
      },
    };

    console.log('📤 Sende Request an Crawl4AI...\n');

    const response = await fetch(crawlEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      console.error('❌ Crawl4AI Request fehlgeschlagen');
      console.error(`   Status: ${response.status} ${response.statusText}`);
      if (body) {
        const errorPreview = body.length > 1000 ? body.substring(0, 1000) + '...' : body;
        console.error(`   Antwort: ${errorPreview}`);
      }
      process.exit(1);
    }

    const data = await response.json().catch(() => null);
    if (!data) {
      console.error('❌ Ungültige JSON-Antwort von Crawl4AI');
      process.exit(1);
    }

    // Crawl4AI gibt { success: true, results: [...] } zurück
    const results = data.results || (Array.isArray(data) ? data : [data]);
    const firstResult = results[0] || {};

    const statusCode = firstResult.status_code ?? data.status_code ?? response.status;

    console.log('✅ Crawl4AI Antwort erhalten!\n');
    console.log('📊 Status Code:', statusCode);

    // Extrahiere LLM-Extraktionsergebnis
    const extractedContent = 
      firstResult.extracted_content ??
      firstResult.llm_extraction ??
      firstResult.extraction_result;

    if (extractedContent) {
      console.log('\n📦 Extrahiertes JSON:');
      console.log('-'.repeat(60));
      
      // Versuche JSON zu parsen falls es ein String ist
      let jsonData = extractedContent;
      if (typeof extractedContent === 'string') {
        try {
          jsonData = JSON.parse(extractedContent);
        } catch (e) {
          // Falls kein JSON, zeige als String
          console.log(extractedContent);
          console.log('-'.repeat(60));
          console.log('\n⚠️  Extrahiertes Content ist kein JSON-String');
          return;
        }
      }

      // Formatiertes JSON ausgeben
      console.log(JSON.stringify(jsonData, null, 2));
      console.log('-'.repeat(60));

      // Statistiken
      if (Array.isArray(jsonData)) {
        console.log(`\n📊 Anzahl extrahierter Produkte: ${jsonData.length}`);
        if (jsonData.length > 0) {
          console.log('\n📋 Erstes Produkt:');
          console.log(JSON.stringify(jsonData[0], null, 2));
        }
      } else if (typeof jsonData === 'object') {
        const keys = Object.keys(jsonData);
        console.log(`\n📊 Extrahiertes Objekt mit ${keys.length} Feldern`);
        if (keys.length > 0) {
          console.log('   Felder:', keys.join(', '));
        }
      }
    } else {
      console.log('\n⚠️  Kein extracted_content in der Antwort gefunden');
      console.log('\n🔍 Verfügbare Felder im Result:');
      console.log(JSON.stringify(Object.keys(firstResult), null, 2));
      
      // Fallback: Zeige Markdown falls vorhanden
      const markdown = 
        firstResult.markdown?.raw_markdown ??
        firstResult.markdown?.markdown_with_citations;
      
      if (markdown) {
        console.log('\n📄 Markdown verfügbar (erste 500 Zeichen):');
        console.log('-'.repeat(60));
        console.log(markdown.substring(0, 500));
        console.log('-'.repeat(60));
      }
    }

    if (firstResult.metadata?.title) {
      console.log('\n📋 Metadata:');
      console.log('   Title:', firstResult.metadata.title);
    }

    console.log('\n🎉 Test erfolgreich abgeschlossen!');
  } catch (error) {
    if (error.name === 'AbortError') {
      console.error('❌ Crawl4AI nicht erreichbar (Timeout nach 5 Minuten).');
    } else {
      console.error('❌ Fehler:', error.message);
      if (process.env.DEBUG) {
        console.error('Stack:', error.stack);
      }
    }
    process.exit(1);
  } finally {
    clearTimeout(timer);
  }
}

main().catch((err) => {
  console.error('❌ Unerwarteter Fehler:', err);
  process.exit(1);
});

