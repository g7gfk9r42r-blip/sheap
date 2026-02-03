#!/usr/bin/env node
import fs from 'fs-extra';
import path from 'path';
import dayjs from 'dayjs';

const YEAR = process.env.YEAR || dayjs().format('YYYY');
const WEEK = process.env.WEEK || ('W' + dayjs().format('WW'));
const IN = `data/_aggregate/${YEAR}/${WEEK}/all_offers.json`;
const OUT = `public/offers/${YEAR}/${WEEK}/index.html`;

const esc = s=>String(s||'').replace(/[&<>"]/g,c=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
(async()=>{
  const data = await fs.readJson(IN).catch(()=>({offers:[]}));
  const rows = data.offers.map(o=>`
<tr>
  <td>${esc(o.brand)}</td>
  <td>${esc(o.title)}</td>
  <td>${o.price!=null? esc(o.price.toFixed(2)+' €'): esc(o.priceRaw||'')}</td>
  <td>${esc(o.unit||'')}</td>
  <td>${esc(o.unitPrice||'')}</td>
  <td>${o.period? esc([o.period.from,o.period.to].filter(Boolean).join(' – ')) : ''}</td>
</tr>
  `).join('');
  const html = `<!doctype html><meta charset="utf-8">
<title>Angebote ${YEAR} ${WEEK}</title>
<style>
body{font-family:system-ui,Arial,sans-serif;margin:24px}
table{border-collapse:collapse;width:100%}th,td{padding:8px;border-bottom:1px solid #eee}
th{background:#fafafa;position:sticky;top:0}
</style>
<h1>Angebote – ${YEAR}/${WEEK}</h1>
<table>
<thead><tr><th>Händler</th><th>Produkt</th><th>Preis</th><th>Einheit</th><th>Grundpreis</th><th>Zeitraum</th></tr></thead>
<tbody>${rows}</tbody>
</table>`;
  await fs.outputFile(OUT, html);
  console.log(`✅ Seite: ${OUT}`);
})();