import dotenv from "dotenv";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import { fetchProspektangeboteLidlOffers } from "../dist/fetchers/fetcher_prospektangebote_lidl.js";

// Load environment variables from .env file
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: resolve(__dirname, "../.env") });
dotenv.config({ path: resolve(__dirname, "../.env.local"), override: false });

console.log("🧪 TEST – Prospektangebote Lidl Fetcher");
const offers = await fetchProspektangeboteLidlOffers();
console.log("Extracted offers:", offers.slice(0, 10));
