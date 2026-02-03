import { fetchLidlOffers } from "../dist/fetchers/fetch_lidl_offers.js";
import path from "path";
import fs from "fs";

console.log("🧪 FULL TEST – Lidl Offer Extraction");
console.log("====================================");

const year = 2025;
const week = 47;

(async () => {
  try {
    console.log(`🔍 Running extraction for ${year}-W${week}...`);

    const offers = await fetchLidlOffers(year, week);

    console.log("\n📦 Offers extracted:", offers.length);

    console.log("\n📝 First 5 Offers:");
    offers.slice(0, 5).forEach((o, i) => {
      console.log(`--- Offer ${i + 1} ---`);
      console.log(JSON.stringify(o, null, 2));
    });

    const filePath = path.join(
      process.cwd(),
      "data",
      "offers",
      "lidl",
      `${year}`,
      `${week}`,
      "offers.json"
    );

    if (fs.existsSync(filePath)) {
      console.log(`\n💾 Offers stored in: ${filePath}`);
    } else {
      console.warn("\n⚠️  offers.json could NOT be found!");
    }

    console.log("\n🎉 FULL TEST PASSED\n");

  } catch (err) {
    console.error("\n❌ FULL TEST FAILED");
    console.error(err);
    process.exit(1);
  }
})();
