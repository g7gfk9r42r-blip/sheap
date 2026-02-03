# Cron-Job Schnellstart für Rom W24

## ⚠️ Problem: Crontab ist leer

Du siehst "no crontab for romw24" → Der Cron-Job wurde noch nicht eingerichtet.

---

## ✅ Lösung: Cron-Job einrichten

### **Schritt 1: Öffne Crontab**

```bash
crontab -e
```

**Falls gefragt:** Wähle einen Editor (z.B. `nano` oder `vim`).

---

### **Schritt 2: Füge diese Zeile hinzu**

```cron
# Lidl-Offer-Extraktion: Jeden Sonntag um 8:00 Uhr
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **Schritt 3: Speichere und verlasse**

- **nano:** `Ctrl+X`, dann `Y`, dann `Enter`
- **vim:** `Esc`, dann `:wq`, dann `Enter`

---

### **Schritt 4: Prüfe ob es funktioniert hat**

```bash
crontab -l
```

**Du solltest jetzt diese Zeile sehen:**
```
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

### **Schritt 5: Teste manuell**

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
./scripts/fetch_lidl_cron.sh
```

**Erwartetes Ergebnis:**
- ✅ Build erfolgreich
- ✅ Offers extrahiert
- ✅ SQLite aktualisiert
- ✅ Log-Datei erstellt

---

## 📋 Cron-Zeit Format

```cron
┌───────────── Minute (0 - 59)
│ ┌───────────── Stunde (0 - 23)
│ │ ┌───────────── Tag des Monats (1 - 31)
│ │ │ ┌───────────── Monat (1 - 12)
│ │ │ │ ┌───────────── Wochentag (0 - 6) (0 = Sonntag)
│ │ │ │ │
0 8 * * 0
```

**Aktueller Eintrag:**
- `0 8 * * 0` = **Sonntag, 8:00 Uhr**

---

## ⚙️ Alternative Zeiten

```cron
# Sonntag um 9:00 Uhr
0 9 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh

# Sonntag um 10:00 Uhr
0 10 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh

# Test: Läuft alle 5 Minuten (nur zum Testen!)
*/5 * * * * cd /Users/romw24/dev/AppProjektRoman/roman_app/server && ./scripts/fetch_lidl_cron.sh
```

---

## 🔍 Troubleshooting

### **Problem: "node: command not found"**

**Lösung:** Nutze vollständigen Pfad zu Node.js:

```bash
which node
# Beispiel: /usr/local/bin/node

# Dann im Cron-Job:
0 8 * * 0 cd /Users/romw24/dev/AppProjektRoman/roman_app/server && /usr/local/bin/node scripts/fetch_lidl_cron.sh
```

### **Problem: Script hat keine Berechtigung**

```bash
chmod +x /Users/romw24/dev/AppProjektRoman/roman_app/server/scripts/fetch_lidl_cron.sh
```

### **Problem: Cron-Job wird nicht ausgeführt**

1. **Prüfe ob Cron-Dienst läuft:**
   ```bash
   # macOS
   sudo launchctl list | grep cron
   ```

2. **Prüfe Cron-Logs:**
   ```bash
   # macOS
   grep CRON /var/log/system.log | tail -20
   ```

---

## ✅ Checkliste

- [ ] `crontab -e` ausgeführt
- [ ] Cron-Job-Zeile hinzugefügt
- [ ] Gespeichert (`Ctrl+X` dann `Y` dann `Enter`)
- [ ] `crontab -l` zeigt die Zeile
- [ ] Script manuell getestet: `./scripts/fetch_lidl_cron.sh`
- [ ] Script funktioniert

---

## 🎉 Fertig!

Der Cron-Job läuft jetzt **jeden Sonntag um 8:00 Uhr** automatisch.

**Logs findest du hier:**
```
server/logs/lidl_YYYY-MM-DD_HH-MM-SS.log
```

