## Legal Starter‑Set – Hinweise zur Integration

Diese Dateien sind für die App (`roman_app`) gedacht:

- `assets/legal/impressum.md`
- `assets/legal/datenschutz.md`
- `assets/legal/agb.md`

### 1) Wo in der App verlinken?

Empfohlen:

- **Settings/Profil → Rechtliches**
  - **Impressum**
  - **Datenschutzerklärung**
  - **AGB**

Darstellung:

- **In‑App Screen** mit scrollbarem Markdown (oder WebView, falls du später eine URL nutzt).
- Wichtig für Stores: Nutzer sollen die Datenschutzerklärung **leicht auffindbar** öffnen können (idealerweise ≤2 Klicks ab Start/Settings).

### 2) Google Play „Datenschutzerklärung“-Link

Google Play verlangt eine URL. Optionen:

- **Eigene Website/Domain** (empfohlen):  
  z. B. `https://<deine-domain>/datenschutz` (dort den Inhalt aus `assets/legal/datenschutz.md` veröffentlichen)
- **Server‑Hosting** (wenn du ohnehin einen Server betreibst):  
  z. B. `https://<dein-server>/legal/datenschutz`

Hinweis: In der App ist die Datenschutzerklärung ohnehin verfügbar (In‑App‑Screen). Für Google Play braucht es zusätzlich eine **öffentliche URL**.

### 3) Platzhalter / Dinge, die du später ggf. anpassen musst

1) **Firebase (optional)**
   - In `assets/legal/datenschutz.md` ist Firebase klar als **optional** beschrieben.
   - Wenn du Firebase wirklich produktiv nutzt (Analytics/Crashlytics/Auth/Firestore), solltest du:
     - konkretisieren **welche Firebase‑Dienste aktiv** sind,
     - ggf. Speicherdauer/Einwilligung/Opt‑Out genauer beschreiben,
     - ggf. einen Link zu den jeweiligen Infos ergänzen (nur wenn du das willst).

2) **Monetarisierung**
   - `assets/legal/agb.md` ist so geschrieben, dass Premium später möglich ist, aber noch ohne Preisdetails.
   - Sobald du Abos/In‑App‑Käufe aktivierst, ergänze:
     - Preise/Laufzeiten/Kündigung/Widerruf/Abrechnung über Apple/Google.

3) **Hosting/Server**
   - Die Datenschutzerklärung erwähnt Server‑Abrufe für Rezepte/Bilder.  
   - Wenn du einen konkreten Hosting‑Dienstleister nutzt, kannst du den später als Empfänger/AV‑Dienstleister ergänzen.

4) **Kontaktkanäle**
   - Falls du später eine Telefon‑Nr. oder Website verwendest, kannst du das im Impressum ergänzen.

### 4) Build‑Hinweis für Testversion ohne Anmeldung (Stores)

Wenn du eine Store‑Testversion ohne Login willst:

- `--dart-define=DISABLE_AUTH=true`
- `--dart-define=DISABLE_FIREBASE=true`

Damit startet die App ohne Firebase und ohne Auth‑Gate.


