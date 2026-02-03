import fs from "fs/promises";
import path from "node:path";
import { mkdir } from "fs/promises";

const YEAR = process.env.YEAR || "2025";
const WEEK = process.env.WEEK || "W44";
const IN = `media/prospekte/rewe/${YEAR}/${WEEK}/offers.json`;
const OUT = `assets/offers/${YEAR}/${WEEK}/rewe.json`;

function pick(obj, keys) {
  for (const k of keys) if (obj && obj[k] != null) return obj[k];
  return null;
}
function toNumber(x) {
  if (x == null) return null;
  const s = String(x).replace(",", ".").replace(/[^\d.]/g, "");
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}
function norm(str) {
  return str ? String(str).replace(/\s+/g, " ").trim() : null;
}

function coerceArray(maybe) {
  if (Array.isArray(maybe)) return maybe;
  if (maybe && typeof maybe === "object" && Array.isArray(maybe.offers)) return maybe.offers;
  if (maybe && typeof maybe === "object" && Array.isArray(maybe.items)) return maybe.items;
  return [];
}

(async () => {
  await mkdir(path.dirname(OUT), { recursive: true });
  let json;
  try {
    json = JSON.parse(await fs.readFile(IN, "utf8"));
  } catch {
    console.log("⚠️  Keine/ungültige offers.json – schreibe leeres rewe.json");
    await fs.writeFile(
      OUT,
      JSON.stringify(
        {
          market: "rewe",
          week: `${YEAR}-${WEEK}`,
          generated_at: new Date().toISOString(),
          offers: [],
        },
        null,
        2
      )
    );
    process.exit(0);
  }

  const items = coerceArray(json)
    .map((it, i) => {
      const title = pick(it, ["title", "name", "productName", "headline"]) || `Item ${i + 1}`;
      const brand = pick(it, ["brand", "supplier", "brandName"]);
      const priceNow = pick(it, ["price", "price_now", "currentPrice", "priceValue", "price_value", "priceFrom"]);
      const priceStr = pick(it, ["priceLabel", "price_label", "priceText", "price_text", "priceDisplay"]);
      const perUnit = pick(it, ["unit", "unitText", "unit_text", "pricePerUnit", "basePrice"]);
      const image = pick(it, ["image", "imageUrl", "imageURL", "img", "picture"]);
      const validFrom = pick(it, ["validFrom", "start", "startDate"]);
      const validTo = pick(it, ["validTo", "end", "endDate"]);
      const category = pick(it, ["category", "cat", "segment"]);
      const desc = pick(it, ["description", "desc", "subtitle", "subline"]);

      let price = toNumber(priceNow);
      if (price == null && typeof priceStr === "string") price = toNumber(priceStr);

      let size = norm(pick(it, ["size", "content", "amount", "quantity", "packaging", "packSize"])) || norm(perUnit);

      return {
        market: "rewe",
        week: `${YEAR}-${WEEK}`,
        title: String(title).trim(),
        brand: brand ? String(brand).trim() : null,
        price,
        price_str: priceStr ? String(priceStr).trim() : price != null ? `${price.toFixed(2)} €` : null,
        size: size || null,
        image: image || null,
        valid_from: validFrom || null,
        valid_to: validTo || null,
        category: category || null,
        description: desc || null,
        source: "rewe_offers",
      };
    })
    .filter((x) => x.title);

  const out = {
    market: "rewe",
    week: `${YEAR}-${WEEK}`,
    generated_at: new Date().toISOString(),
    offers: items,
  };
  await fs.writeFile(OUT, JSON.stringify(out, null, 2));
  console.log(`✅ Transform fertig → ${OUT} (${items.length} Angebote)`);
})();

