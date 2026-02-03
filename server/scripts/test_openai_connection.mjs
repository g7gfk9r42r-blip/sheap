#!/usr/bin/env node
// Test OpenAI API Verbindung

import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Lade .env
const envPath = resolve(__dirname, '../.env');
try {
  const envContent = await fs.readFile(envPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=').trim();
      if (key && value) {
        process.env[key.trim()] = value.replace(/^["']|["']$/g, '');
      }
    }
  }
} catch (error) {
  console.warn('⚠️  .env nicht gefunden, verwende nur process.env');
}

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY nicht gesetzt!');
  process.exit(1);
}

console.log('🔍 Teste OpenAI API Verbindung...\n');
console.log(`🔑 API Key: ${OPENAI_API_KEY.substring(0, 10)}...${OPENAI_API_KEY.substring(OPENAI_API_KEY.length - 4)}\n`);

try {
  console.log('📡 Sende Test-Request...');
  
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'user',
          content: 'Sag nur "OK"'
        }
      ],
      max_tokens: 10,
    }),
  });

  console.log(`📊 Status: ${response.status} ${response.statusText}`);

  if (!response.ok) {
    const errorText = await response.text();
    console.error(`\n❌ Fehler: ${errorText}`);
    process.exit(1);
  }

  const data = await response.json();
  const content = data.choices[0]?.message?.content || '';
  
  console.log(`✅ Antwort: ${content}`);
  console.log(`\n✅ API-Verbindung funktioniert!`);
  
} catch (error) {
  console.error(`\n❌ Fehler: ${error.message}`);
  if (error.message.includes('fetch')) {
    console.error('💡 Network-Problem erkannt. Prüfe:');
    console.error('   - Internet-Verbindung');
    console.error('   - Firewall/Proxy-Einstellungen');
    console.error('   - DNS-Auflösung');
  }
  process.exit(1);
}

