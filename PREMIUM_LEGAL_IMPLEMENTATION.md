# Premium & Legal Implementation - Zusammenfassung

## Implementierte Dateien

### 1. Premium System
- **lib/features/premium/premium_service.dart**
  - ChangeNotifier-basierter Service für In-App Purchases
  - Verwaltet Premium-Status, Produkte, Käufe
  - Initialisiert in `main.dart`

- **lib/features/premium/paywall_screen.dart**
  - Paywall-Screen mit Benefits, Preisoptionen
  - Restore-Purchases Funktion
  - Links zu Datenschutz & Nutzungsbedingungen

- **lib/features/premium/widgets/upgrade_bar.dart**
  - Upgrade-Bar Widget für Free-User
  - Kann in verschiedenen Screens eingebunden werden

### 2. Legal Content & Screens
- **lib/features/profile/legal/legal_content.dart**
  - Zentrale Rechts-Texte (Datenschutz, AGB, Impressum, Hinweise)
  - **WICHTIG**: Platzhalter-Werte anpassen:
    - `companyName`
    - `companyAddress`
    - `companyEmail`
    - `representative`
    - `contactEmail`
    - `privacyEmail`

- **lib/features/profile/legal/legal_detail_screen.dart**
  - Detail-Screen für Rechts-Texte
  - Scrollbar, sauber typografiert

- **lib/features/profile/legal/legal_hub_screen.dart**
  - Hub-Screen für alle Rechts-Dokumente (optional)

### 3. Profile Screen
- **lib/features/profile/profile_screen_new.dart**
  - Erweitert um:
    - Premium-Status Anzeige
    - "Informationen" Section (App-Version, Kontakt, Feedback)
    - "Rechtliches" Section (Datenschutz, AGB, Impressum, Hinweise)
    - "Abo verwalten" (für Premium-User)

### 4. Utilities
- **lib/core/utils/links.dart**
  - Mailto-Links
  - Manage Subscriptions (iOS/Android)

### 5. Main App
- **lib/main.dart**
  - Premium Service wird beim App-Start initialisiert

### 6. Dependencies
- **pubspec.yaml**
  - `in_app_purchase: ^3.2.0`
  - `package_info_plus: ^8.0.0`
  - `url_launcher: ^6.3.1`

## Produkt-IDs (IAP)

Die folgenden Produkt-IDs werden verwendet (in App Store Connect / Play Console einrichten):

- `premium_monthly` - Monatliches Abo (Auto-Renew)
- `premium_yearly` - Jährliches Abo (Auto-Renew)

**WICHTIG**: Diese IDs müssen in App Store Connect (iOS) und Google Play Console (Android) als In-App-Produkte konfiguriert werden.

## Premium Features (Gates)

Folgende Features sind als Premium definiert (können in UI verwendet werden):

1. **Unbegrenzte Rezepte pro Woche** (Free: limitiert)
2. **Erweiterte Filter und Ziele** (Free: Basis-Filter)
3. **Meal Plan Export & Sync** (Free: nur lokal)
4. **Alle Supermärkte verfügbar** (Free: limitiert)
5. **Exklusive Premium-Rezepte** (Free: Standard-Rezepte)

**Implementierung**: Prüfe `PremiumService.instance.premiumActive` um Features zu gaten.

## App Store Guidelines Compliance

✅ **Restore Purchases**: Implementiert im Paywall Screen
✅ **Terms/Privacy Links**: Von Paywall erreichbar
✅ **Keine irreführenden Preise**: Alle Preise werden von Store abgerufen
✅ **Keine externe Payment**: Nur In-App Purchases

## Nächste Schritte

1. **Platzhalter-Werte anpassen** in `lib/features/profile/legal/legal_content.dart`:
   - COMPANY_NAME, COMPANY_ADDRESS, etc.

2. **Produkt-IDs in Stores konfigurieren**:
   - App Store Connect (iOS)
   - Google Play Console (Android)

3. **Premium Gates implementieren**:
   - In relevanten Screens `PremiumService.instance.premiumActive` prüfen
   - Upgrade Bar einbinden wo nötig

4. **Testing**:
   - In-App Purchases im Sandbox-Modus testen
   - Restore Purchases testen
   - Offline-Verhalten testen

## Verwendung

### Premium Status prüfen:
```dart
final premiumService = PremiumService.instance;
if (premiumService.premiumActive) {
  // Premium Feature freigeben
} else {
  // Upgrade Bar zeigen
}
```

### Upgrade Bar einbinden:
```dart
const UpgradeBar(
  customMessage: 'Erweiterte Features freischalten',
)
```

### Paywall öffnen:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const PaywallScreen()),
);
```

### Legal Screen öffnen:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const LegalDetailScreen(
      type: LegalContentType.privacy,
    ),
  ),
);
```

