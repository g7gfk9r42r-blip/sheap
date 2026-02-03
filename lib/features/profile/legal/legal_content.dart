/// Legal Content - Centralized legal texts
/// WICHTIG: Anpassen der Platzhalter-Werte (COMPANY_NAME, etc.)
class LegalContent {
  LegalContent._();

  // === COMPANY INFORMATION (ANPASSEN!) ===
  static const String companyName = 'COMPANY_NAME'; // TODO: Eintragen
  static const String companyAddress = 'COMPANY_ADDRESS'; // TODO: Eintragen
  static const String companyEmail = 'info@example.com'; // TODO: Eintragen
  static const String representative = 'COMPANY_REPRESENTATIVE'; // TODO: Eintragen
  static const String contactEmail = 'kontakt@example.com'; // TODO: Eintragen
  static const String privacyEmail = 'datenschutz@example.com'; // TODO: Eintragen

  // === DATENSCHUTZERKLÄRUNG ===
  static const String privacyPolicy = '''
# Datenschutzerklärung

## 1. Verantwortlicher
$companyName
$companyAddress
E-Mail: $privacyEmail

## 2. Welche Daten wir speichern
Grocify speichert die folgenden Daten **ausschließlich lokal auf Ihrem Gerät**:

### App-Funktionsdaten
- Meal Plans (Mahlzeiten-Planungen)
- Einkaufslisten
- Favorisierte Rezepte
- Nutzungsstatistiken (lokal)

### Nutzerprofil-Daten (optional, beim Onboarding erfasst)
- Startgewicht (optional)
- Zielgewicht (optional)
- Zieltyp (abnehmen/halten/zunehmen, optional)
- Wasserziel (Liter pro Tag)
- Ernährungspräferenzen (vegetarisch, vegan, low carb, high protein, laktosefrei, glutenfrei)
- Allergien (optional, freie Texteingabe)
- Bevorzugte Kochzeit (optional)
- Bevorzugter Supermarkt (optional)

### Einwilligungen (rechtliche Nachweisbarkeit)
- Zeitpunkt der AGB-Akzeptanz
- Zeitpunkt der Datenschutzerklärung-Lektüre
- Analytics/Crash-Reports Einwilligung (optional, standardmäßig deaktiviert)

### Technische Daten (automatisch)
- Gerätetyp und Betriebssystem (iOS/Android)
- App-Version
- Gerätesprache (optional)
- Fehlerprotokolle (bei Abstürzen)

### Kontaktformulare
Falls Sie uns kontaktieren, speichern wir Ihre E-Mail-Adresse und Nachricht ausschließlich zur Beantwortung Ihrer Anfrage.

**Speicherort:** Alle Daten werden ausschließlich lokal auf Ihrem Gerät gespeichert. Es erfolgt keine Übertragung an externe Server (außer bei der Aktualisierung von Rezeptdaten, die anonymisiert erfolgt).

## 3. Kein Tracking zu Werbezwecken
Grocify verwendet keine Tracking-Technologien zu Werbezwecken. Es werden keine Cookies, Pixel oder ähnliche Technologien verwendet, um Ihr Verhalten zu analysieren oder personalisierte Werbung anzuzeigen.

## 4. Datenübertragung
Ihre Daten werden nicht an Dritte verkauft oder weitergegeben. Rezeptdaten werden von öffentlich zugänglichen Prospekten aggregiert und anonymisiert bereitgestellt.

## 5. Rechtsgrundlage
- **Einwilligung (optional)**: Für optionale Daten (Gewicht, Präferenzen, etc.) erfolgt die Speicherung auf Basis Ihrer freiwilligen Eingabe.
- **Vertragserfüllung**: Für die App-Funktion notwendige Daten (Meal Plans, Einkaufslisten) werden zur Bereitstellung der App-Funktionalität gespeichert.

## 6. Ihre Rechte
Sie haben das Recht:
- Auskunft über Ihre gespeicherten Daten zu erhalten
- Berichtigung unrichtiger Daten zu verlangen (in den App-Einstellungen)
- Löschung Ihrer Daten zu verlangen (Button "Alle Daten löschen" in den Einstellungen)
- Widerspruch gegen die Verarbeitung einzulegen
- Einwilligungen jederzeit zu widerrufen (in den Einstellungen)

**Widerruf & Löschung:** Sie können Ihre Einwilligungen jederzeit in den App-Einstellungen (Profil → Einstellungen → Datenschutz) ändern oder alle Daten löschen.

Kontaktieren Sie uns für Fragen unter: $privacyEmail

## 7. Datensicherheit
Wir setzen technische und organisatorische Maßnahmen ein, um Ihre Daten zu schützen. Alle Daten werden lokal auf Ihrem Gerät gespeichert.

## 8. Änderungen dieser Datenschutzerklärung
Wir behalten uns vor, diese Datenschutzerklärung anzupassen. Die aktuelle Version finden Sie in der App.

Stand: 2025
''';

  // === NUTZUNGSBEDINGUNGEN ===
  static const String termsOfService = '''
# Nutzungsbedingungen

## 1. Geltungsbereich
Diese Nutzungsbedingungen gelten für die Nutzung der Grocify-App (nachfolgend "App").

## 2. Unverbindlichkeit von Preisen und Angeboten
Alle in der App angezeigten Preise und Angebote sind unverbindlich und können regional abweichen. Die Preise basieren auf öffentlich zugänglichen Prospekten und können sich täglich ändern. Wir übernehmen keine Gewähr für die Aktualität, Richtigkeit oder Verfügbarkeit der angezeigten Preise und Angebote.

**Bitte überprüfen Sie die Preise direkt im jeweiligen Supermarkt.**

## 3. Regionale Abweichungen
Preise und Verfügbarkeiten können je nach Region, Filiale und Zeitpunkt erheblich abweichen. Die App stellt eine Übersicht dar, ersetzt aber nicht die Überprüfung vor Ort.

## 4. Nutzerdaten
Sie stellen Daten freiwillig zur Verfügung (z.B. Gewichtsziele, Präferenzen). Diese Daten werden ausschließlich lokal auf Ihrem Gerät gespeichert und dienen der Personalisierung der App. Wir übernehmen keine Garantie für die Zielerreichung (z.B. Gewichtsverlust, Wasserziel).

## 5. Rezepte
Die in der App bereitgestellten Rezepte dienen ausschließlich als Inspiration. Wir übernehmen keine Haftung für:
- Allergene oder Unverträglichkeiten
- Ernährungsempfehlungen
- Nährwertangaben (können abweichen)
- Zubereitungsergebnisse

Bitte überprüfen Sie selbst, ob Rezepte für Ihre Ernährungsweise geeignet sind.

## 6. Haftungsausschluss
Die Nutzung der App erfolgt auf eigenes Risiko. Wir haften nicht für:
- Fehlerhafte oder veraltete Preisangaben
- Nicht verfügbare Produkte oder Angebote
- Schäden durch Nutzung der App
- Datenverlust

## 7. Verfügbarkeit
Wir bemühen uns um eine hohe Verfügbarkeit der App, können jedoch keine garantierte Verfügbarkeit zusichern. Wartungsarbeiten können zu zeitweisen Ausfällen führen.

## 8. Änderungen der App
Wir behalten uns vor, die App jederzeit zu ändern, zu erweitern oder einzustellen.

## 9. Geistiges Eigentum
Alle Inhalte der App (Rezepte, Texte, Designs) unterliegen dem Urheberrecht. Die Nutzung ist ausschließlich für private Zwecke gestattet.

## 10. Schlussbestimmungen
Sollten einzelne Bestimmungen unwirksam sein, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt.

Stand: 2025
''';

  // === IMPRESSUM / ANBIETER ===
  static const String imprint = '''
# Impressum / Anbieter

## Angaben gemäß § 5 TMG

$companyName
$companyAddress

## Vertreten durch
$representative

## Kontakt
E-Mail: $contactEmail

## Verantwortlich für den Inhalt
$representative
$companyAddress

Stand: 2025
''';

  // === HINWEISE / DISCLAIMER ===
  static const String disclaimers = '''
# Wichtige Hinweise

## Markenrechte
Alle in der App genannten Markennamen, Produktnamen und Logos sind Eigentum ihrer jeweiligen Inhaber. Grocify steht in keiner Verbindung zu den genannten Supermärkten, Marken oder Produkten.

Die App verwendet ausschließlich öffentlich zugängliche Informationen (Prospekte) und stellt diese in strukturierter Form dar.

## Preise und Angebote
- Alle Preise sind unverbindlich und können regional abweichen
- Preise können sich täglich ändern
- Verfügbarkeit kann regional und filialabhängig variieren
- Bitte überprüfen Sie Preise und Verfügbarkeit direkt im Supermarkt

## Keine Gewährleistung
Wir übernehmen keine Gewährleistung für:
- Richtigkeit der Preisangaben
- Verfügbarkeit der Produkte
- Aktualität der Angebote
- Vollständigkeit der Informationen

## Nutzung
Die App dient als Hilfsmittel zur Planung und Orientierung. Bitte nutzen Sie die App verantwortungsvoll und überprüfen Sie wichtige Informationen (Preise, Allergene, etc.) selbst.

Stand: 2025
''';

  // Helper to get content by type
  static String getContent(LegalContentType type) {
    switch (type) {
      case LegalContentType.privacy:
        return privacyPolicy;
      case LegalContentType.terms:
        return termsOfService;
      case LegalContentType.imprint:
        return imprint;
      case LegalContentType.disclaimers:
        return disclaimers;
    }
  }
}

enum LegalContentType {
  privacy,
  terms,
  imprint,
  disclaimers,
}

