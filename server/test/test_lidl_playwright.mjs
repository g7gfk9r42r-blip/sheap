#!/usr/bin/env node
/**
 * Test-Skript für Playwright-basierte Lidl-Offer-Extraktion
 */

import { fetchLidlOffersPlaywright } from "../dist/fetchers/fetcher_lidl_playwright.js";
import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
dotenv.config({ path: resolve(__dirname, "../.env") });
dotenv.config({ path: resolve(__dirname, "../.env.local"), override: false });

console.log("🧪 TEST – Lidl Playwright Fetcher");
console.log("===================================");

(async () => {
  try {
    const offers = await fetchLidlOffersPlaywright();
    
    console.log(`\n📦 Extrahierte Offers: ${offers.length}`);
    
    if (offers.length > 0) {
      console.log("\n📝 Erste 10 Offers:");
      offers.slice(0, 10).forEach((o, i) => {
        console.log(`--- Offer ${i + 1} ---`);
        console.log(`  Titel: ${o.title}`);
        console.log(`  Preis: ${o.price}€ / ${o.unit}`);
        console.log(`  Marke: ${o.brand || "N/A"}`);
        console.log(`  Seite: ${o.page || "N/A"}`);
        if (o.originalPrice) {
          console.log(`  Ursprungspreis: ${o.originalPrice}€`);
        }
        if (o.discountPercent) {
          console.log(`  Rabatt: ${o.discountPercent}%`);
        }
        console.log();
      });
      
      console.log("✅ TEST ERFOLGREICH");
    } else {
      console.log("⚠️  Keine Offers extrahiert");
      process.exit(1);
    }
  } catch (error) {
    console.error("\n❌ TEST FEHLGESCHLAGEN");
    console.error(error);
    process.exit(1);
  }
})();

