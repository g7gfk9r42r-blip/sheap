#!/usr/bin/env node
/**
 * Minimal Crawl4AI smoketest using fetch() directly.
 * No internal helpers, no extra dependencies.
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
// Test-URL (kann über Umgebungsvariable überschrieben werden)
const TARGET_URL = process.env.TEST_URL || 'https://example.com';

if (!BASE_URL) {
  console.error('❌ Keine Base URL gesetzt (CRAWL4AI_BASE_URL).');
  process.exit(1);
}

const crawlEndpoint = `${BASE_URL.replace(/\/+$/, '')}/crawl`;

async function main() {
  console.log('🧪 Crawl4AI Test');
  console.log(`   URL: ${TARGET_URL}`);
  console.log(`   Base URL: ${BASE_URL}\n`);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 60_000);

  try {
    const response = await fetch(crawlEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
      },
      body: JSON.stringify({
        urls: [TARGET_URL],
        options: { maxDepth: 0, maxPages: 1 },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      console.error('❌ Crawl4AI nicht erreichbar');
      console.error(`   ${response.status} ${response.statusText}`);
      if (body) console.error(`   Antwort: ${body}`);
      process.exit(1);
    }

    const data = await response.json().catch(() => null);
    if (!data) {
      console.error('❌ Ungültige JSON-Antwort von Crawl4AI');
      process.exit(1);
    }

    // Debug: Zeige vollständige Antwort (nur wenn DEBUG gesetzt)
    if (process.env.DEBUG === '1' || process.env.DEBUG === 'true') {
      console.log('\n🔍 Vollständige Antwort:', JSON.stringify(data, null, 2));
    }

    // Crawl4AI gibt ein Objekt mit results-Array zurück
    const results = data.results || (Array.isArray(data) ? data : [data]);
    const firstResult = results[0] || {};

    const statusCode = firstResult.status_code ?? data.status_code ?? response.status;
    
    // Markdown kann in verschiedenen Formaten sein
    const markdown = 
      firstResult.markdown?.raw_markdown ??
      firstResult.markdown?.markdown_with_citations ??
      (typeof firstResult.markdown === 'string' ? firstResult.markdown : null) ??
      firstResult.cleaned_html ??
      '(kein Markdown erhalten)';
    
    const metadataTitle =
      firstResult.metadata?.title ??
      firstResult.title ??
      data.metadata?.title ??
      data.title ??
      '(kein Titel)';

    console.log('✅ Crawl4AI Antwort erhalten!\n');
    console.log('📊 Status Code:', statusCode);
    console.log('📄 Markdown Preview (erste 300 Zeichen):');
    console.log('-'.repeat(60));
    if (typeof markdown === 'string' && markdown.length > 0) {
      const preview = markdown.length > 300 
        ? markdown.substring(0, 300) + '...' 
        : markdown;
      console.log(preview);
    } else {
      console.log('(kein Markdown vorhanden)');
    }
    console.log('-'.repeat(60));
    
    if (typeof markdown === 'string' && markdown.length > 0) {
      console.log(`\n📏 Markdown Länge: ${markdown.length} Zeichen`);
    }
    
    console.log('\n📋 Metadata:');
    console.log('   Title:', metadataTitle);
    if (data.metadata?.url) {
      console.log('   URL:', data.metadata.url);
    }
  } catch (error) {
    if (error.name === 'AbortError') {
      console.error('❌ Crawl4AI nicht erreichbar (Timeout).');
    } else {
      console.error('❌ Crawl4AI nicht erreichbar:', error.message);
    }
    process.exit(1);
  } finally {
    clearTimeout(timer);
  }

  console.log('\n🎉 Test abgeschlossen');
}

main().catch((err) => {
  console.error('❌ Unerwarteter Fehler:', err);
  process.exit(1);
});

