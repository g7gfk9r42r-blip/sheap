# Cron-Job Setup für wöchentliche Lidl-Offer-Extraktion

## 🎯 Ziel

Automatische Extraktion aller Lidl-Angebote **jeden Sonntag vormittags um 8:00 Uhr**.

**Warum Sonntag?** Damit hast du den ganzen Sonntag als Fallback-Zeit, falls die Extraktion nicht klappt.

---

## 📋 Setup-Schritte

### **1. Teste das Script manuell**

```bash
cd server
./scripts/fetch_lidl_cron.sh
```

**Erwartetes Ergebnis:**
- ✅ Build erfolgreich
- ✅ Offers extrahiert
- ✅ SQLite aktualisiert
- ✅ Log-Datei erstellt: `logs/lidl_YYYY-MM-DD.log`

---

### **2. Finde den absoluten Pfad zum Script**

```bash
cd server
pwd
# Beispiel-Output: /Users/romw24/dev/AppProjektRoman/roman_app/server

# Vollständiger Pfad zum Script:
realpath scripts/fetch_lidl_cron.sh
# Beispiel-Output: /Users/romw24/dev/AppProjektRoman/roman_app/server/scripts/fetch_lidl_cron.sh
```

**Merke dir diesen Pfad** - du brauchst ihn für den Cron-Job.

---

### **3. Öffne die Crontab**

```bash
crontab -e
```

**Wenn zum ersten Mal:** Wähle einen Editor (z.B. `nano` oder `vim`).

---

### **4. Füge den Cron-Job hinzu**

Füge diese Zeile am Ende der Datei hinzu:

```cron
# Lidl-Offer-Extraktion: Jeden Sonntag um 8:00 Uhr
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

**Erklärung:**
- `0 8 * * 0` = Sonntag (0), 8:00 Uhr (0 Minuten, 8 Stunden)
- `cd ...` = Wechsel ins Server-Verzeichnis
- `./scripts/fetch_lidl_cron.sh` = Führt das Script aus

**⚠️ Wichtig:** Ersetze `/Users/romw24/dev/AppProjektRoman/roman_app/server` mit deinem tatsächlichen Pfad!

**💡 Hinweis:** Sonntag = `0` (oder `7`) im Cron-Format. Du hast den ganzen Sonntag als Fallback-Zeit!

---

### **5. Alternative: Mit vollständigem Pfad**

```cron
# Lidl-Offer-Extraktion: Jeden Sonntag um 8:00 Uhr
0 8 * * 0 /Users/romw24/dev/AppProjektRoman/roman_app/server/scripts/fetch_lidl_cron.sh
```

**⚠️ Wichtig:** Verwende den absoluten Pfad, den du in Schritt 2 ermittelt hast!

---

### **6. Speichere und verlasse den Editor**

- **nano:** `Ctrl+X`, dann `Y`, dann `Enter`
- **vim:** `Esc`, dann `:wq`, dann `Enter`

---

### **7. Prüfe ob der Cron-Job gespeichert wurde**

```bash
crontab -l
```

**Du solltest deinen neuen Cron-Job sehen:**
```
0 8 * * 1 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **8. Teste den Cron-Job (optional)**

Du kannst den Cron-Job testen, indem du die Zeit anpasst:

```cron
# Test: Läuft in 2 Minuten (ersetzt die 0 8 * * 0 Zeile temporär)
*/2 * * * * cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

**Nach dem Test:** Ändere zurück zu `0 8 * * 0` (Sonntag, 8:00 Uhr).

---

## ⏰ Cron-Zeit-Format

```cron
┌───────────── Minute (0 - 59)
│ ┌───────────── Stunde (0 - 23)
│ │ ┌───────────── Tag des Monats (1 - 31)
│ │ │ ┌───────────── Monat (1 - 12)
│ │ │ │ ┌───────────── Wochentag (0 - 6) (0 = Sonntag)
│ │ │ │ │
* * * * *
```

### **Beispiele:**

```cron
# Jeden Sonntag um 8:00 Uhr (empfohlen - gibt dir Fallback-Zeit)
0 8 * * 0

# Jeden Sonntag um 9:00 Uhr
0 9 * * 0

# Jeden Sonntag um 8:30 Uhr
30 8 * * 0

# Jeden Tag um 8:00 Uhr
0 8 * * *

# Alle 6 Stunden
0 */6 * * *

# Sonntag und Mittwoch um 9:00 Uhr
0 9 * * 0,3
```

---

## 🔍 Monitoring & Debugging

### **Log-Dateien prüfen**

```bash
cd server
ls -lh logs/
cat logs/lidl_$(date +%Y-%m-%d).log
```

### **Cron-Logs prüfen (macOS/Linux)**

```bash
# macOS
grep CRON /var/log/system.log

# Linux
grep CRON /var/log/syslog
# oder
journalctl -u cron
```

### **Manuelle Ausführung testen**

```bash
cd server
./scripts/fetch_lidl_cron.sh
```

---

## ⚠️ Häufige Probleme

### **Problem: "node: command not found"**

**Lösung:** Füge Node.js zum PATH hinzu:

```cron
# Setze PATH im Cron-Job
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/node/bin
0 8 * * 1 cd /path/to/server && ./scripts/fetch_lidl_cron.sh
```

Oder verwende den vollständigen Pfad zu Node.js:

```bash
which node
# Beispiel: /usr/local/bin/node

# Dann im Cron-Job:
0 8 * * 1 cd /path/to/server && /usr/local/bin/node scripts/fetch_lidl_cron.sh
```

### **Problem: "npm: command not found"**

**Lösung:** Gleiche Lösung wie oben, aber für npm:

```bash
which npm
# Beispiel: /usr/local/bin/npm
```

### **Problem: Script hat keine Berechtigung**

**Lösung:**

```bash
chmod +x scripts/fetch_lidl_cron.sh
```

### **Problem: .env Datei wird nicht geladen**

**Lösung:** Das Script lädt `.env` automatisch. Falls es nicht funktioniert, setze Umgebungsvariablen direkt im Cron-Job:

```cron
0 8 * * 1 cd /path/to/server && LIDL_LEAFLET_URL="..." ./scripts/fetch_lidl_cron.sh
```

---

## 📧 E-Mail-Benachrichtigungen (optional)

Cron sendet automatisch E-Mails bei Fehlern, wenn `MAILTO` gesetzt ist:

```cron
# E-Mail-Adresse für Cron-Benachrichtigungen
MAILTO=deine-email@example.com

# Lidl-Extraktion
0 8 * * 1 cd /path/to/server && ./scripts/fetch_lidl_cron.sh
```

**Um E-Mails zu deaktivieren:**

```cron
MAILTO=""

# Lidl-Extraktion
0 8 * * 1 cd /path/to/server && ./scripts/fetch_lidl_cron.sh >/dev/null 2>&1
```

---

## ✅ Checkliste

- [ ] Script ist ausführbar: `chmod +x scripts/fetch_lidl_cron.sh`
- [ ] Script funktioniert manuell: `./scripts/fetch_lidl_cron.sh`
- [ ] Absoluter Pfad ermittelt: `realpath scripts/fetch_lidl_cron.sh`
- [ ] Cron-Job hinzugefügt: `crontab -e`
- [ ] Cron-Job gespeichert: `crontab -l`
- [ ] Log-Verzeichnis existiert: `mkdir -p logs`
- [ ] Test-Ausführung erfolgreich (optional)

---

## 🎉 Fertig!

Der Cron-Job läuft jetzt **automatisch jeden Sonntag um 8:00 Uhr** und extrahiert alle Lidl-Angebote für die aktuelle Woche. Du hast den ganzen Sonntag als Fallback-Zeit, falls etwas nicht klappt!

**Ergebnis:**
- ✅ JSON-Datei: `data/lidl/{year}/W{week}/offers.json`
- ✅ SQLite: `data/app.db` (alle Offers importiert)
- ✅ Log-Datei: `logs/lidl_YYYY-MM-DD.log`

---

## 📝 Beispiel: Vollständiger Cron-Job-Eintrag

```cron
# ============================================
# Lidl-Offer-Extraktion
# ============================================
# Läuft jeden Sonntag um 8:00 Uhr
# Extrahiert alle Angebote für die aktuelle Woche
# Gibt dir den ganzen Sonntag als Fallback-Zeit
# ============================================

0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

## 🔗 Weitere Ressourcen

- **Cron-Editor online:** https://crontab.guru/
- **Cron-Dokumentation:** `man crontab`
- **Log-Verzeichnis:** `server/logs/`

0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
