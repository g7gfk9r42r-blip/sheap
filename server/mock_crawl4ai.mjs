#!/usr/bin/env node
/**
 * Mock Crawl4AI Server für Tests
 * Simuliert die /crawl API
 */

import http from 'http';

const PORT = 11235;

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  if (req.url === '/crawl' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const url = data.url || 'unknown';

        // Mock Response - simuliert realistische Crawl4AI-Antwort
        const isLidl = url.includes('lidl.de');
        const markdown = isLidl
          ? `# Lidl Angebote\n\n## Aktuelle Angebote\n\n- **Bananen** - 1,29€ / kg\n- **Milch** - 0,99€ / Liter\n- **Brot** - 1,49€ / Stück\n\nGültig bis: 29.11.2025`
          : `# Mock Crawl4AI Response\n\nCrawled URL: ${url}\n\nThis is a mock response for testing purposes.\n\n## Content\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.`;

        const response = {
          status_code: 200,
          markdown: markdown,
          metadata: {
            title: isLidl ? 'Lidl Angebote - Aktionsprospekt' : `Mock Page: ${url}`,
            url: url,
            status_code: 200,
            crawled_at: new Date().toISOString()
          },
          success: true
        };

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
      }
    });
    return;
  }

  // 404 für andere Endpoints
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`🚀 Mock Crawl4AI Server läuft auf http://localhost:${PORT}`);
  console.log(`   Drücke Ctrl+C zum Beenden\n`);
});

process.on('SIGINT', () => {
  console.log('\n👋 Server wird beendet...');
  server.close();
  process.exit(0);
});

