# Savings Refactoring - Zusammenfassung

## ✅ Durchgeführte Änderungen

### 1. NEU: Helper-Funktion erstellt
- **Datei:** `lib/utils/recipe_savings_helper.dart` (NEU)
- **Funktion:** `computeRecipeSavings()` - Berechnet Savings pro Recipe basierend auf offers_used
- **Klasse:** `RecipeSavings` - Enthält `savingsEur`, `savingsPercent`, `hasSavings`, `displayText`

### 2. Stats Service bereinigt
- **Datei:** `lib/data/services/stats_service.dart`
- ✅ `WeeklySavingsOverview` Klasse entfernt
- ✅ `calculateWeeklySavingsOverview()` Methode entfernt
- ✅ `defaultWeeklySavingsGoal` Konstante entfernt
- ✅ `savings` Feld aus `TodayOverview` entfernt
- ✅ Savings-Berechnung aus `calculateTodayOverview()` entfernt

### 3. Home Screen bereinigt
- **Datei:** `lib/features/home/home_screen.dart`
- ✅ Savings-Stat aus `_TodayAndPlanCard` entfernt (nur noch plannedMeals)
- ✅ `_RoundIconButton` für Savings entfernt (Navigation zu SavingsOverviewScreen)
- ✅ `totalSavings` aus `_SuccessScreen` entfernt
- ✅ `MotivationScreen` totalSavings Parameter entfernt

### 4. Plan Screen bereinigt
- **Datei:** `lib/features/plan/plan_screen_new.dart`
- ✅ `_getWeeklySavingsStats()` Methode entfernt
- ✅ `_getTodaySavings()` Methode entfernt
- ✅ `_StickyHeaderSection` weeklyStats Parameter entfernt
- ✅ `_WeeklyProgressCard` Verwendung entfernt (wenn vorhanden)

- **Datei:** `lib/features/plan/plan_screen.dart`
- ✅ `_weeklySavings` Variable entfernt
- ✅ `SavingBanner` Widget entfernt

### 5. Profile Screen bereinigt
- **Datei:** `lib/features/profile/profile_screen_new.dart`
- ✅ `totalSavings` Variable entfernt
- ✅ Savings-Anzeige entfernt

- **Datei:** `lib/features/profile/profile_screen.dart`
- ✅ `totalSavings` Variable entfernt
- ✅ Savings-Anzeige entfernt

### 6. Discover Screen bereinigt
- **Datei:** `lib/features/discover/discover_screen_redesigned.dart`
- ✅ `_calculateTotalSavings()` Methode entfernt
- ✅ Total Savings Anzeige entfernt (ersetzt durch "Rezepte verfügbar")

### 7. RecipeCard - Savings hinzugefügt
- **Datei:** `lib/features/discover/widgets/recipe_card.dart`
- ✅ Import `recipe_savings_helper.dart` hinzugefügt
- ✅ Savings-Anzeige nach Preis-Block hinzugefügt (mit `computeRecipeSavings()`)

### 8. RecipeDetailScreen - Savings angepasst
- **Datei:** `lib/features/discover/recipe_detail_screen_new.dart`
- ✅ Import `recipe_savings_helper.dart` hinzugefügt
- ✅ `_DescriptionSection` verwendet jetzt `computeRecipeSavings()`
- ✅ `savings` Parameter ist jetzt `double?` (optional)
- ✅ `savingsPercent` Parameter hinzugefügt
- ✅ Savings-Badge wird nur angezeigt wenn `savings != null && savings! > 0`
- ✅ Formatierung: "Du sparst X.XX € (YY%)" oder "Du sparst X.XX €"

---

## 📝 Verbleibende Arbeiten (Optional)

### 9. Discover Screen New - Savings-Banner entfernen (optional)
- **Datei:** `lib/features/discover/discover_screen_new.dart`
- Falls `_getTopSavingsRecipe()` und `_calculateAverageSavings()` noch existieren, diese entfernen
- Falls `_SavingsBanner` Widget verwendet wird, entfernen oder durch Recipe-spezifische Anzeige ersetzen

### 10. Alte Recipe Detail Screen (optional)
- **Datei:** `lib/features/discover/recipe_detail_screen.dart`
- Falls `_totalSaving` verwendet wird, durch `computeRecipeSavings()` ersetzen

### 11. SavingsOverviewScreen löschen (optional)
- **Datei:** `lib/features/stats/savings_overview_screen.dart`
- Kann gelöscht werden, da nicht mehr verwendet

### 12. SavingBanner Widget löschen (optional)
- **Datei:** `lib/core/widgets/molecules/saving_banner.dart`
- Kann gelöscht werden, da nicht mehr verwendet

---

## ✅ Implementierte Features

1. **Recipe-Savings Berechnung:**
   - Funktioniert mit `WeeklyRecipe` (hat `offersUsed`)
   - Funktioniert mit normalem `Recipe` (hat `.savings` Feld)
   - Coverage >= 0.7 Check implementiert
   - Null-sicher (keine Crashes bei fehlenden Preisen)

2. **UI-Anpassungen:**
   - RecipeCard zeigt Savings mit Icon und Prozent
   - RecipeDetailScreen zeigt Savings nur wenn vorhanden
   - Format: "Du sparst X.XX € (YY%)" oder "Du sparst X.XX €"

3. **Robustheit:**
   - Alle Null-Checks implementiert
   - Graceful Fallbacks wenn Daten fehlen

---

## 🔍 Noch zu prüfen

- Ob `discover_screen_new.dart` noch `_getTopSavingsRecipe()` oder `_calculateAverageSavings()` hat
- Ob `_SavingsBanner` Widget noch verwendet wird
- Ob es weitere Screens gibt die Weekly/Total Savings anzeigen
