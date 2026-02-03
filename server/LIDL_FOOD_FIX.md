# Problem: Nur Mode-Angebote, keine Lebensmittel

## 🔍 Problem-Analyse

Die aktuelle JSON-Datei (`data/lidl/2025/W47/offers.json`) enthält:
- ❌ **45 Mode-Artikel** (esmara®, lupilu®, etc.)
- ❌ **39 Wein & Spirituosen** 
- ✅ **0 echte Lebensmittel** (Milch, Brot, Käse, etc.)

**Grund:** Der verwendete Prospekt-URL zeigt den **Mode-Prospekt**, nicht den **Lebensmittel-Prospekt**.

---

## ✅ Lösung: Richtigen Lebensmittel-Prospekt finden

### **Option 1: Automatisch finden (empfohlen)**

```bash
cd server
npm run find:lidl:food
```

Dieses Script sucht automatisch nach dem Lebensmittel-Prospekt und zeigt dir die URL.

---

### **Option 2: Manuell finden**

1. **Öffne:** https://www.lidl.de/c/online-prospekte/s10005610
2. **Suche** nach "Aktionsprospekt" oder "Lebensmittel"
3. **Klicke** auf den Lebensmittel-Prospekt (nicht Mode!)
4. **Kopiere** die URL aus der Adressleiste

**Beispiel-URL für Lebensmittel-Prospekt:**
```
https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1
```

---

### **Option 3: .env Datei anpassen**

Füge die richtige Lebensmittel-Prospekt-URL in `.env` hinzu:

```bash
# In server/.env
LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1
```

**⚠️ Wichtig:** Dies muss der **Lebensmittel-Prospekt** sein, nicht Mode!

---

## 🔄 Neu-Extraktion mit Lebensmittel-Prospekt

### **Schritt 1: Finde Lebensmittel-Prospekt-URL**

```bash
cd server
npm run find:lidl:food
```

### **Schritt 2: Setze URL in .env**

```bash
# Öffne .env
nano .env

# Füge hinzu:
LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/aktionsprospekt-[DATUM]-[ID]/view/flyer/page/1
```

### **Schritt 3: Lösche alte JSON (optional)**

```bash
rm -rf data/lidl/2025/W47/offers.json
```

### **Schritt 4: Neu extrahieren**

```bash
npm run fetch:lidl

# Oder direkt:
node tools/leaflets/fetch_lidl_leaflet.mjs --capture-only
```

### **Schritt 5: Prüfe ob Lebensmittel gefunden wurden**

```bash
npm run view:lidl | grep -i "milch\|brot\|käse\|fleisch" | head -20
```

---

## 📋 Cron-Job einrichten

### **Schritt 1: Öffne Crontab**

```bash
crontab -e
```

**Falls zum ersten Mal:** Wähle einen Editor (z.B. `nano`).

---

### **Schritt 2: Füge diese Zeile hinzu**

```cron
# Lidl-Offer-Extraktion: Jeden Sonntag um 8:00 Uhr
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **Schritt 3: Speichere**

- **nano:** `Ctrl+X`, dann `Y`, dann `Enter`
- **vim:** `Esc`, dann `:wq`, dann `Enter`

---

### **Schritt 4: Prüfe**

```bash
crontab -l
```

**Du solltest jetzt diese Zeile sehen:**
```
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

## 🎯 Zusammenfassung der nächsten Schritte

1. ✅ **Finde Lebensmittel-Prospekt-URL:**
   ```bash
   npm run find:lidl:food
   ```

2. ✅ **Setze URL in .env:**
   ```bash
   LIDL_LEAFLET_URL=[URL aus Schritt 1]
   ```

3. ✅ **Lösche alte JSON (optional):**
   ```bash
   rm -rf data/lidl/2025/W47/offers.json
   ```

4. ✅ **Neu extrahieren:**
   ```bash
   npm run fetch:lidl
   ```

5. ✅ **Prüfe ob Lebensmittel gefunden wurden:**
   ```bash
   npm run view:lidl -- --count
   npm run validate:lidl
   ```

6. ✅ **Cron-Job einrichten:**
   ```bash
   crontab -e
   # Füge die Zeile hinzu (siehe oben)
   crontab -l  # Prüfe
   ```

---

## 🔍 Teste den Filter

Nach der Neu-Extraktion sollte der Filter nur noch Lebensmittel zeigen:

```bash
npm run test:lidl:playwright
```

**Erwartet:** Nur Lebensmittel-Angebote (Milch, Brot, Käse, etc.), keine Mode, keine Wein/Spirituosen.

---

## ✅ Checkliste

- [ ] Lebensmittel-Prospekt-URL gefunden (`npm run find:lidl:food`)
- [ ] URL in `.env` gesetzt (`LIDL_LEAFLET_URL=...`)
- [ ] Alte JSON gelöscht (optional)
- [ ] Neu extrahiert (`npm run fetch:lidl`)
- [ ] Lebensmittel-Angebote gefunden (`npm run view:lidl`)
- [ ] Cron-Job eingerichtet (`crontab -e`)
- [ ] Cron-Job geprüft (`crontab -l`)

---

## 🎉 Fertig!

Nach diesen Schritten:
- ✅ Nur noch Lebensmittel-Angebote
- ✅ Cron-Job läuft jeden Sonntag um 8:00 Uhr
- ✅ Automatische wöchentliche Extraktion aktiviert

