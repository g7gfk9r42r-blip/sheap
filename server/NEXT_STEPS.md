# Nächste Schritte - Lidl Offer Extraktion

## ✅ Was bereits erledigt ist:

1. ✅ Playwright-basierte Extraktion implementiert (`fetch_lidl_leaflet.mjs`)
2. ✅ TypeScript-Fetcher erstellt (`fetcher_lidl_playwright.ts`)
3. ✅ Integration in `lidl.ts` Fetcher
4. ✅ Cron-Job Scripts erstellt
5. ✅ Dokumentation erstellt
6. ✅ Cron-Job eingerichtet (Sonntag 8:00 Uhr)

---

## 📋 Nächste Schritte

### **1. Teste den Cron-Job manuell**

Bevor du auf den nächsten Sonntag wartest, teste das Script manuell:

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
./scripts/fetch_lidl_cron.sh
```

**Erwartetes Ergebnis:**
- ✅ Build erfolgreich
- ✅ Offers extrahiert (falls neue Woche)
- ✅ SQLite aktualisiert
- ✅ Log-Datei erstellt: `logs/lidl_YYYY-MM-DD_HH-MM-SS.log`

---

### **2. Prüfe ob Cron-Job korrekt eingerichtet ist**

```bash
# Prüfe ob der Cron-Job gespeichert wurde
crontab -l

# Du solltest diese Zeile sehen:
# 0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **3. Optional: Teste mit früherer Zeit**

Falls du nicht bis Sonntag warten willst, teste mit einer Test-Zeit:

```bash
crontab -e
```

**Temporär ändern zu (läuft in 2-3 Minuten):**
```cron
# TEST: Läuft alle 5 Minuten (temporär!)
*/5 * * * * cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

**Nach dem Test:** Zurück ändern zu:
```cron
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **4. Überwache die Logs**

Nach dem ersten automatischen Lauf (Sonntag):

```bash
cd server
ls -lh logs/
cat logs/lidl_$(date +%Y-%m-%d).log
```

**Was du in den Logs sehen solltest:**
- ✅ Build erfolgreich
- ✅ Offer-Extraktion erfolgreich
- ✅ SQLite-Import erfolgreich
- ✅ Anzahl der extrahierten Offers

---

### **5. Prüfe ob Offers in SQLite gespeichert wurden**

```bash
cd server
npm run build
node -e "
  import('./dist/db.js').then(async (mod) => {
    const offers = mod.adapter.getOffers('LIDL');
    console.log(\`✅ \${offers.length} Lidl-Offers in SQLite\`);
    if (offers.length > 0) {
      console.log('Erste 3 Offers:');
      offers.slice(0, 3).forEach(o => {
        console.log(\`  - \${o.title}: \${o.price}€\`);
      });
    }
  });
"
```

---

### **6. Setze LIDL_LEAFLET_URL (optional)**

Falls du eine spezifische Prospekt-URL für die Extraktion verwenden willst:

```bash
# In .env Datei hinzufügen:
echo "LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/latest-leaflet-..." >> .env
```

**Standard:** Das Script nutzt automatisch die neueste Prospekt-URL.

---

### **7. Monitoring einrichten (optional)**

#### **E-Mail-Benachrichtigung bei Fehlern:**

Füge zur `crontab -e` hinzu:

```cron
# E-Mail bei Fehlern
MAILTO=deine-email@example.com

# Lidl-Extraktion
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

#### **Log-Rotation (optional):**

Um alte Logs automatisch zu löschen, füge hinzu:

```cron
# Löscht Logs älter als 30 Tage (läuft täglich)
0 2 * * * find /Users/romw24/dev/AppProjektRoman/roman_app/server/logs -name "lidl_*.log" -mtime +30 -delete
```

---

### **8. Manueller Fallback**

Falls der automatische Cron-Job nicht funktioniert, kannst du manuell ausführen:

```bash
# Option 1: Direktes Script
cd server
./scripts/fetch_lidl_cron.sh

# Option 2: TypeScript-Fetcher
npm run build
npm run test:lidl:playwright

# Option 3: Playwright-Script direkt
npm run fetch:lidl
```

---

## 🔍 Troubleshooting

### **Problem: Cron-Job läuft nicht**

1. **Prüfe ob Cron-Dienst läuft:**
   ```bash
   # macOS
   sudo launchctl list | grep cron
   
   # Linux
   sudo systemctl status cron
   ```

2. **Prüfe Cron-Logs:**
   ```bash
   # macOS
   grep CRON /var/log/system.log
   
   # Linux
   grep CRON /var/log/syslog
   ```

3. **Prüfe ob PATH korrekt ist:**
   - Im Cron-Script wird `cd` verwendet, sollte funktionieren
   - Falls nicht: Nutze absolute Pfade

### **Problem: Keine Offers extrahiert**

1. **Prüfe Log-Datei:**
   ```bash
   cat server/logs/lidl_$(date +%Y-%m-%d).log
   ```

2. **Prüfe ob Playwright funktioniert:**
   ```bash
   cd server
   npm run fetch:lidl
   ```

3. **Aktiviere Debug-Logging:**
   ```bash
   DEBUG=true npm run fetch:lidl
   ```

---

## 📊 Erfolgs-Indikatoren

Nach dem ersten automatischen Lauf solltest du sehen:

✅ **Log-Datei existiert:** `logs/lidl_YYYY-MM-DD_HH-MM-SS.log`
✅ **JSON-Datei erstellt:** `data/lidl/{year}/W{week}/offers.json`
✅ **SQLite aktualisiert:** Offers in `data/app.db`
✅ **Log zeigt:** "X Offers in SQLite gespeichert"

---

## 🎯 Zusammenfassung

**Aktueller Status:**
- ✅ Alles eingerichtet
- ✅ Cron-Job läuft jeden Sonntag um 8:00 Uhr
- ✅ Automatische Extraktion aktiviert

**Nächste Aktion:**
1. Teste das Script manuell: `./scripts/fetch_lidl_cron.sh`
2. Prüfe am nächsten Sonntag die Logs
3. Bei Problemen: Siehe Troubleshooting oder manueller Fallback

**Fertig! 🎉**

Der Cron-Job wird **automatisch jeden Sonntag um 8:00 Uhr** laufen und alle Lidl-Angebote für die aktuelle Woche extrahieren.

