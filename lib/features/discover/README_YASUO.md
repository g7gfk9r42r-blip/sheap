# Yasuo-Style Discover Screen

## 🎨 Neue UI im Yasuo-Stil

Die neue `DiscoverScreenYasuo` implementiert eine moderne, inspirationsorientierte Rezept-Entdeckungsseite.

## 📁 Neue Dateien

- **`models/recipe_week.dart`** - Model für Rezepte-Wochen
- **`widgets/recipe_week_carousel.dart`** - Horizontal swipeable Wochen-Carousel
- **`widgets/yasuo_recipe_card.dart`** - Recipe Card im Yasuo-Stil (großes Bild, Herz-Icon, kcal, Zeit)
- **`widgets/supermarket_recipe_row.dart`** - Horizontale Supermarkt-Rezept-Liste
- **`data/recipe_week_mock_data.dart`** - Mock-Daten Generator für Wochen
- **`presentation/discover_screen_yasuo.dart`** - Haupt-Screen

## 🚀 Aktivierung

Um die neue Yasuo-Version zu aktivieren, ändere in `main.dart`:

```dart
// Alte Version:
import 'features/discover/presentation/discover_screen.dart';
DiscoverScreen(), // Index 1

// Neue Yasuo-Version:
import 'features/discover/presentation/discover_screen_yasuo.dart';
DiscoverScreenYasuo(), // Index 1
```

## 📱 Struktur

1. **Header**
   - Titel: "Entdecken"
   - Subtitel: "Diese Woche für dich"
   - Optional: Filter-Icon

2. **Rezepte-Wochen Carousel**
   - Horizontal swipeable PageView
   - Hero-Bilder mit Text-Overlay
   - Dots-Indicator
   - Zeigt: Wochendatum, Rezeptanzahl, optionaler Subtitle

3. **Supermarkt-Sektionen** (vertikal gestapelt)
   - Für jeden Supermarkt:
     - Titel: "{Supermarkt} Rezepte"
     - "Mehr"-Button (rechts)
     - Horizontal scrollbare Recipe Cards (max. 10 pro Sektion)

## 🎯 Design-Prinzipien

- **Keine harten Linien** - Alles abgerundet (16-20px)
- **Viel Weißraum** - Großzügige Abstände
- **Weiche Schatten** - Subtile Tiefe
- **Leichtes Scroll-Gefühl** - BouncingScrollPhysics
- **Mobile-First** - Optimiert für Touch-Interaktionen
- **Fokus: Inspiration** - Nicht Listen, sondern visuelle Inspiration

## 🧩 Features

- ✅ Haptic Feedback bei Card-Taps
- ✅ Favoriten-System (Herz-Icon)
- ✅ Smooth Animations
- ✅ Gradient Backgrounds mit Emoji-Fallback
- ✅ Responsive Card-Größen
- ✅ Dots-Indicator für Wochen-Carousel

## 🔄 Mock-Daten

Die `RecipeWeekMockData.generateWeeksFromRecipes()` Funktion:
- Gruppiert Rezepte nach `weekKey`
- Erstellt RecipeWeek-Objekte
- Wählt passende Emojis basierend auf Rezepten
- Fallback für leere Daten

## 📝 Nächste Schritte

- [ ] Echte Image-URLs für Rezepte integrieren
- [ ] Week-Detail-Screen (bei Tap auf Week-Card)
- [ ] Supermarkt-Detail-Screen (bei "Mehr"-Button)
- [ ] Filter-Funktionalität
- [ ] Skeleton Loading States
- [ ] Pull-to-Refresh
