#!/usr/bin/env node
// tools/leaflets/fetch_lidl_weekly.mjs
// Automatisiertes Skript zum wöchentlichen Export von Lidl-Prospekten als PDF

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import fs from 'fs/promises';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ISO-Woche berechnen (Format: 2025-W44)
function getISOWeek(date = new Date()) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7; // Make Sunday=7
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  const year = d.getUTCFullYear();
  const ww = String(weekNo).padStart(2, '0');
  return { weekKey: `${year}-W${ww}`, year, week: ww };
}

// Lidl Viewer-URL (latest-leaflet ist statisch)
const LIDL_VIEWER_URL = 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';

async function fetchLidlPdf(weekKey, year, week) {
  const outDir = resolve(__dirname, '../../media/prospekte/lidl', String(year), String(week));
  const outPdf = join(outDir, 'leaflet.pdf');

  // Prüfen ob PDF bereits existiert
  try {
    await fs.access(outPdf);
    console.log(`ℹ️  PDF bereits vorhanden: ${outPdf}`);
    return { success: true, skipped: true, path: outPdf };
  } catch {
    // PDF existiert nicht, weiter mit Export
  }

  // Verzeichnis erstellen
  await fs.mkdir(outDir, { recursive: true });

  console.log(`📥 Starte Lidl-PDF-Export für ${weekKey}...`);
  console.log(`   Viewer-URL: ${LIDL_VIEWER_URL}`);
  console.log(`   Ziel: ${outPdf}`);

  // viewer2pdf.mjs aufrufen
  const viewer2pdfPath = resolve(__dirname, 'viewer2pdf.mjs');
  const args = [
    LIDL_VIEWER_URL,
    outPdf,
    '--max=180',  // Lidl-Profil maxPages
    '--delay=1100',
    '--scale=2.5'
  ];

  return new Promise((resolve, reject) => {
    const proc = spawn('node', [viewer2pdfPath, ...args], {
      stdio: 'inherit',
      cwd: __dirname
    });

    proc.on('close', (code) => {
      if (code === 0) {
        console.log(`✅ Lidl-PDF erfolgreich exportiert: ${outPdf}`);
        resolve({ success: true, skipped: false, path: outPdf });
      } else {
        const err = new Error(`viewer2pdf.mjs beendet mit Code ${code}`);
        console.error(`❌ Fehler beim PDF-Export:`, err.message);
        reject(err);
      }
    });

    proc.on('error', (err) => {
      console.error(`❌ Fehler beim Starten von viewer2pdf.mjs:`, err);
      reject(err);
    });
  });
}

async function main() {
  const { weekKey, year, week } = getISOWeek();
  console.log(`📅 Aktuelle Woche: ${weekKey}`);

  try {
    const result = await fetchLidlPdf(weekKey, year, week);
    if (result.success && !result.skipped) {
      process.exit(0);
    } else if (result.success && result.skipped) {
      console.log(`ℹ️  PDF bereits vorhanden, übersprungen.`);
      process.exit(0);
    }
  } catch (error) {
    console.error(`❌ Fehler beim Lidl-PDF-Export:`, error);
    process.exit(1);
  }
}

main();

