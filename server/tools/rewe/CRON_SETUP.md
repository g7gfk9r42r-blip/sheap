# CRON-Setup für REWE-Angebots-Abruf

## 📋 Schritt-für-Schritt Anleitung

### 1. Script lokal testen

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe
python3 run_rewe_once.py
```

**Erwartete Ausgabe:**
```
✅ REWE Angebots-Abruf erfolgreich!
📊 XX Angebote gefunden
💾 Gespeichert in: output/angebote_rewe_YYYYMMDD.json
```

---

### 2. Python-Pfad finden

#### Option A: `which` (empfohlen)
```bash
which python3
```

**Beispiel-Ausgabe:**
```
/usr/local/bin/python3
```
oder
```
/opt/homebrew/bin/python3
```

#### Option B: `whereis` (Linux)
```bash
whereis python3
```

#### Option C: Direkter Test
```bash
python3 -c "import sys; print(sys.executable)"
```

**Beispiel-Ausgabe:**
```
/usr/local/bin/python3
```

---

### 3. Projekt-Pfad ermitteln

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe
pwd
```

**Beispiel-Ausgabe:**
```
/Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe
```

---

### 4. CRON-Eintrag erstellen

#### Schritt 1: Crontab öffnen
```bash
crontab -e
```

#### Schritt 2: Folgende Zeile einfügen

**⚠️ WICHTIG:** Ersetze die Platzhalter:
- `/ABSOLUTER/PFAD/zu/python3` → Dein Python-Pfad (aus Schritt 2)
- `/path/to/tools/rewe` → Dein Projekt-Pfad (aus Schritt 3)

```cron
0 8 * * 1 cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe && /usr/local/bin/python3 run_rewe_once.py >> /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/cron.log 2>&1
```

**Erklärung:**
- `0 8 * * 1` = Jeden Montag um 08:00 Uhr
- `cd ...` = Wechsel ins Projekt-Verzeichnis
- `&&` = Führe Python-Script nur aus, wenn cd erfolgreich war
- `>> cron.log 2>&1` = Leite Output und Fehler in Log-Datei um

#### Schritt 3: Crontab speichern
- **vim/nano**: `:wq` oder `Ctrl+X`, dann `Y`, dann `Enter`
- **VS Code**: Speichern und schließen

---

### 5. CRON testen

#### Option A: Manuell ausführen (simuliert Cron-Umgebung)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe
/usr/local/bin/python3 run_rewe_once.py
```

#### Option B: Cron-Log prüfen
```bash
tail -f /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/cron.log
```

#### Option C: Cron-Status prüfen
```bash
crontab -l
```

---

## 📝 Fertiger CRON-Eintrag (Template)

**Kopiere diese Zeile und passe die Pfade an:**

```cron
0 8 * * 1 cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe && /usr/local/bin/python3 run_rewe_once.py >> /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/cron.log 2>&1
```

**Ersetze:**
- `/Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe` → Dein Projekt-Pfad
- `/usr/local/bin/python3` → Dein Python-Pfad (aus `which python3`)

---

## 🔍 Troubleshooting

### Problem: Script läuft nicht in Cron

**Lösung 1: Prüfe Python-Pfad**
```bash
which python3
# Verwende diesen exakten Pfad im CRON-Eintrag
```

**Lösung 2: Prüfe Berechtigungen**
```bash
chmod +x run_rewe_once.py
```

**Lösung 3: Prüfe Log-Datei**
```bash
cat cron.log
```

**Lösung 4: Teste mit absoluten Pfaden**
```bash
# Im CRON-Eintrag:
0 8 * * 1 /usr/local/bin/python3 /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/run_rewe_once.py >> /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/cron.log 2>&1
```

### Problem: Import-Fehler

**Lösung:** Stelle sicher, dass `fetch_rewe_offers.py` im gleichen Verzeichnis liegt:
```bash
ls -la /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/
```

### Problem: Keine Ausgabe-Datei

**Lösung:** Prüfe, ob `output/`-Verzeichnis existiert:
```bash
ls -la /Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe/output/
```

---

## 📅 Alternative: Systemd Timer (Linux)

Falls du Linux nutzt, kannst du auch einen Systemd-Timer verwenden:

**Datei:** `/etc/systemd/system/rewe-offers.service`
```ini
[Unit]
Description=REWE Angebots-Abruf

[Service]
Type=oneshot
WorkingDirectory=/Users/romw24/dev/AppProjektRoman/roman_app/server/tools/rewe
ExecStart=/usr/local/bin/python3 run_rewe_once.py
User=dein-username
```

**Datei:** `/etc/systemd/system/rewe-offers.timer`
```ini
[Unit]
Description=REWE Angebots-Abruf Timer

[Timer]
OnCalendar=Mon *-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Aktivieren:**
```bash
sudo systemctl enable rewe-offers.timer
sudo systemctl start rewe-offers.timer
```

---

## ✅ Checkliste

- [ ] Script lokal getestet (`python3 run_rewe_once.py`)
- [ ] Python-Pfad ermittelt (`which python3`)
- [ ] Projekt-Pfad ermittelt (`pwd`)
- [ ] CRON-Eintrag erstellt (`crontab -e`)
- [ ] Pfade im CRON-Eintrag angepasst
- [ ] CRON-Eintrag gespeichert
- [ ] CRON-Status geprüft (`crontab -l`)
- [ ] Log-Datei prüfbar (`tail -f cron.log`)

---

## 📞 Beispiel-Ausgabe

Nach erfolgreicher Ausführung findest du:

**Datei:** `output/angebote_rewe_20251201.json`
```json
{
  "market": "REWE",
  "zip_code": "53113",
  "fetched_at": "2025-12-01T08:00:00.123456",
  "fetched_date": "20251201",
  "total_offers": 42,
  "offers": [...]
}
```

**Log-Datei:** `cron.log`
```
2025-12-01 08:00:00,123 - INFO - REWE Angebots-Abruf gestartet
2025-12-01 08:00:02,456 - INFO - Lade Angebote für PLZ 53113...
2025-12-01 08:00:05,789 - INFO - ✅ 42 Angebote geladen
2025-12-01 08:00:05,890 - INFO - ✅ Angebote gespeichert: output/angebote_rewe_20251201.json
```

