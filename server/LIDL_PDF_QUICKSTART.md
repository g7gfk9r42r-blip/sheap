# 📄 Lidl PDF - Schnellstart

## ✅ PDF erfolgreich erstellt!

**Pfad:**
```
media/prospekte/lidl/2025/W48/95b989/leaflet.pdf
```

**Details:**
- 📄 **31 Seiten**
- 💾 **42 MB**
- ✅ **Bereit zum Öffnen**

---

## 🚀 So erstellst du künftig PDFs

### **Option 1: Mit npm Script (einfachste Methode)**

```bash
cd server

# Setze URL in .env (einmalig)
echo "LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-95b989/view/flyer/page/1?lf=HHZ" >> .env

# Dann einfach:
npm run pdf:lidl
```

---

### **Option 2: Mit Shell Script**

```bash
cd server

# Direkt mit URL:
./scripts/fetch_lidl_pdf.sh "https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-95b989/view/flyer/page/1?lf=HHZ"

# Oder mit LIDL_LEAFLET_URL aus .env:
LIDL_LEAFLET_URL="..." ./scripts/fetch_lidl_pdf.sh
```

---

### **Option 3: Direkt mit Node**

```bash
cd server

LIDL_LEAFLET_URL="https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-95b989/view/flyer/page/1?lf=HHZ" \
  node tools/leaflets/fetch_lidl_leaflet.mjs
```

---

## 📂 Wo wird die PDF gespeichert?

**Struktur:**
```
media/prospekte/lidl/
  └── YYYY/
      └── WW/
          └── [PROSPEKT-ID]/
              └── leaflet.pdf
```

**Beispiel:**
```
media/prospekte/lidl/2025/W48/95b989/leaflet.pdf
```

---

## 🔄 Automatisch jede Woche (Cron-Job)

Füge in `crontab -e` hinzu:

```cron
# Jeden Sonntag um 8:00 Uhr
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && LIDL_LEAFLET_URL="https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-95b989/view/flyer/page/1?lf=HHZ" npm run pdf:lidl
```

**⚠️ Wichtig:** Die URL muss jede Woche aktualisiert werden, da sich der Prospekt ändert!

**Besser:** Automatisch die neueste URL finden:

```cron
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && npm run find:lidl:food | grep LIDL_LEAFLET_URL | cut -d'=' -f2 | xargs -I {} sh -c 'LIDL_LEAFLET_URL={} npm run pdf:lidl'
```

---

## 📋 Zusammenfassung

**Einfachste Methode:**
1. URL in `.env` setzen: `LIDL_LEAFLET_URL=...`
2. `npm run pdf:lidl` ausführen
3. PDF öffnen: `open media/prospekte/lidl/YYYY/WW/[ID]/leaflet.pdf`

**Fertig!** 🎉

