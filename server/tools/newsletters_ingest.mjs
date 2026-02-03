#!/usr/bin/env node
import 'dotenv/config';
import { ImapFlow } from 'imapflow';
import { simpleParser } from 'mailparser';
import { load } from 'cheerio';
import fs from 'fs-extra';
import dayjs from 'dayjs';

const YEAR = process.env.YEAR || dayjs().format('YYYY');
const WEEK = process.env.WEEK || ('W' + dayjs().format('WW'));

const BRANDS = [
  { key:'lidl',  env:'LIDL',  fromHints:['@lidl.de','newsletter@lidl.de','info@lidl-shop.de'] },
  // weitere Händler einfach ergänzen …
];

const REGION = process.env.REGION_HINTS ? new RegExp(process.env.REGION_HINTS,'i') : null;

const normPrice = (s) => {
  if (!s) return null;
  const m = s.replace(/\s/g,'').match(/(\d+[.,]\d{1,2})/);
  return m ? parseFloat(m[1].replace(',','.')) : null;
};
const extractUnit = s => (s && s.match(/(\d+\s?(g|kg|ml|l|Stk\.?))/i)?.[1]) || null;
const extractUnitPrice = s => (s && s.match(/(\d+[.,]\d{1,2}\s?€\/(kg|l))/i)?.[1]) || null;
const extractPeriod = t => {
  if (!t) return null;
  const range = t.match(/(\d{1,2}\.\d{1,2}\.)\s?[–-]\s?(\d{1,2}\.\d{1,2}\.)/);
  const single = t.match(/gültig\s*(ab)?\s*(\d{1,2}\.\d{1,2}\.)/i);
  return range ? {from:range[1],to:range[2]} : (single ? {from:single[2]} : null);
};
const pick = s => (s||'').replace(/\s+/g,' ').trim();

async function latestMail({host,port,secure,user,pass}, fromHints) {
  const client = new ImapFlow({
    host, port: Number(port), secure: String(secure)==='true',
    auth: { user, pass }
  });
  await client.connect();
  await client.mailboxOpen('INBOX');

  const since = dayjs().subtract(9,'days').toDate();
  let newest = null, newestSource = null;

  // Verwende Range '1:*' - ImapFlow streamt das intern durch
  // Alternativ könnte man auch search() mit limit verwenden, aber fetch mit Range ist effizienter
  for await (const msg of client.fetch('1:*', { envelope: true, source: true })) {
    const env = msg.envelope || {};
    const date = env.date ? new Date(env.date) : null;
    if (date && date < since) continue;

    const fromAddrs = (env.from || []).map(x => `${x.mailbox}@${x.host}`.toLowerCase());
    const hit = fromHints.some(h => fromAddrs.some(a => a.includes(h)));
    if (!hit) continue;

    if (!newest || date > newest.envelope.date) {
      newest = msg;
      newestSource = msg.source;
    }
  }

  const parsed = newestSource ? await simpleParser(newestSource) : null;
  await client.logout();
  return parsed;
}

function parseOffers(html) {
  const $ = load(html || '');
  const offers = [];

  // typische Kacheln/Teaser
  const blocks = $('.product,.product-tile,.tile,.article,[data-product],.grid__item,.c-product,.c-offer,.teaser');
  blocks.each((_,el)=>{
    const $el = $(el);
    const title = pick(
      $el.find('.title,.headline,h2,h3,.product__title,.tile__title,.c-product__title').first().text() ||
      $el.attr('data-title')
    );
    const priceRaw = pick(
      $el.find('.price,.product__price,.tile__price,.amount,.price__amount,.c-price').first().text()
    );
    const price = normPrice(priceRaw);
    const unit = extractUnit($el.text());
    const unitPrice = extractUnitPrice($el.text());
    const period = extractPeriod($el.text());

    if (title && (price || priceRaw)) {
      const item = { title, price, priceRaw: priceRaw || null, unit, unitPrice, period };
      if (!REGION || REGION.test([$el.text(), title, priceRaw].join(' '))) {
        offers.push(item);
      }
    }
  });

  // Fallback: Linktexte mit Preisen
  if (offers.length < 10) {
    $('a').each((_,a)=>{
      const t = pick($(a).text());
      const p = normPrice(t);
      if (p && t.length>4) {
        offers.push({
          title: t, price: p, priceRaw: t,
          unit: extractUnit(t), unitPrice: extractUnitPrice(t),
          period: extractPeriod(t)
        });
      }
    });
  }

  // Dedupe
  const seen = new Set(); const out=[];
  for (const o of offers) {
    const k = `${o.title}|${o.price||o.priceRaw}`;
    if (!seen.has(k)) { seen.add(k); out.push(o); }
  }
  return out;
}

async function runBrand({key,env,fromHints}) {
  const cfg = n => process.env[`${env}_${n}`];
  const mail = await latestMail({
    host: cfg('IMAP_HOST'),
    port: cfg('IMAP_PORT'),
    secure: cfg('IMAP_SECURE'),
    user: cfg('IMAP_USER'),
    pass: cfg('IMAP_PASS')
  }, fromHints);

  if (!mail) {
    console.warn(`⚠️  ${key}: Keine Newsletter-Mail der letzten Tage gefunden.`);
    return null;
  }

  const html = mail.html || mail.textAsHtml || mail.text || '';
  const offers = parseOffers(html);
  const outPath = `data/${key}/${YEAR}/${WEEK}/offers.json`;
  await fs.outputJson(outPath, {
    brand: key,
    capturedAt: dayjs().toISOString(),
    year: Number(YEAR), week: WEEK,
    mailbox: cfg('IMAP_USER') || null,
    count: offers.length,
    offers
  }, { spaces: 2 });

  console.log(`✅ ${key}: ${offers.length} Angebote → ${outPath}`);
  return outPath;
}

(async ()=>{
  const paths = [];
  for (const b of BRANDS) {
    try { const p = await runBrand(b); if (p) paths.push(p); }
    catch(e){ console.error(`❌ ${b.key}:`, e.message); }
  }

  // Aggregat
  const aggregate = [];
  for (const p of paths) {
    const j = await fs.readJson(p).catch(()=>null);
    if (!j) continue;
    for (const o of j.offers) aggregate.push({ ...o, brand: j.brand });
  }
  const aggPath = `data/_aggregate/${YEAR}/${WEEK}/all_offers.json`;
  await fs.outputJson(aggPath, {
    year: Number(YEAR), week: WEEK,
    count: aggregate.length,
    offers: aggregate
  }, { spaces: 2 });
  console.log(`📦 Aggregat: ${aggregate.length} → ${aggPath}`);
})();