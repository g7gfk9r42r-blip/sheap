# 🎨 Grocify 2.0 - UI/UX Blueprint

## 📐 Design-Philosophie

**Kernprinzipien:**
- **Minimalistisch & Clean** (dominiert)
- **iOS-ähnliche Ästhetik** (smooth, rounded, glassy) - aber cross-platform
- **Leichte Gamification** (subtile Fortschrittsanzeigen, kleine Belohnungen)
- **Rezepte im Fokus** (Angebote nur bei Rezept-Details)
- **DACH-optimiert** (später international erweiterbar)
- **Android & iOS** (adaptive Design)

**User-Journey:**
1. App öffnen → Rezepte entdecken
2. Rezept auswählen → Angebote sehen
3. Rezept planen → In Wochenplaner
4. Sparen tracken → Subtile Belohnungen

---

## 🧭 Navigation (3 Tabs)

### Tab 1: **Entdecken** 🔍
- Hauptfunktion: Rezepte durchsuchen & entdecken
- Angebote nur bei Rezept-Details sichtbar
- Kategorien: Schnell, Günstig, Gesund, Beliebt

### Tab 2: **Planen** 📅
- Wochenplaner für Mahlzeiten
- Drag & Drop Rezepte
- Spar-Übersicht (wie viel gespart diese Woche)

### Tab 3: **Profil** 👤
- Spar-Statistiken (leicht gamifiziert)
- Einstellungen
- Journal (optional, reduziert)

---

## 🎨 Design System

### Farbpalette
```
Primary:     #6366F1 (Indigo - modern, vertrauenswürdig)
Secondary:   #10B981 (Emerald - sparen, gesund)
Accent:      #F59E0B (Amber - Highlights, CTA)
Background:  #FAFAFA (Warmes Weiß)
Surface:     #FFFFFF (Reines Weiß)
Text:        #1F2937 (Dunkelgrau)
Text Light:  #6B7280 (Mittelgrau)
Success:     #10B981
Warning:     #F59E0B
Error:       #EF4444
```

### Typografie
```
Display:     Inter Bold, 32px (Hero-Text)
Headline:    Inter SemiBold, 24px (Screens)
Title:       Inter SemiBold, 18px (Karten)
Body:        Inter Regular, 16px (Text)
Caption:     Inter Regular, 14px (Hinweise)
Label:       Inter Medium, 12px (Buttons)
```

### Spacing System
```
xs:   4px
sm:   8px
md:   12px
lg:   16px
xl:   20px
2xl:  24px
3xl:  32px
4xl:  48px
```

### Border Radius
```
sm:   8px
md:   12px
lg:   16px
xl:   20px
2xl:  24px (Cards)
```

### Shadows
```
sm:   0 1px 2px rgba(0,0,0,0.05)
md:   0 4px 6px rgba(0,0,0,0.07)
lg:   0 10px 15px rgba(0,0,0,0.1)
xl:   0 20px 25px rgba(0,0,0,0.1)
```

---

## 📱 Screen-Struktur

### 1. ENTDECKEN (Home)
```
┌─────────────────────────────────┐
│  Grocify                    🔔  │ ← AppBar (minimal)
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────┐   │
│  │  "Was kochst du heute?" │   │ ← Hero-Text (groß, freundlich)
│  └─────────────────────────┘   │
│                                 │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │
│  │ 🍝│ │🥗 │ │🍕│ │🍲│       │ ← Quick Categories (4 große Buttons)
│  └───┘ └───┘ └───┘ └───┘       │
│                                 │
│  ┌─────────────────────────┐   │
│  │  💰 Diese Woche gespart  │   │ ← Spar-Banner (subtile Gamification)
│  │     12,50 €              │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  Beliebte Rezepte        │   │ ← Section Header
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [Rezept-Bild]           │   │
│  │  Pasta Carbonara         │   │ ← Rezept-Card (groß, mit Bild)
│  │  💰 3,50 € gespart       │   │
│  │  ⭐ 4.8  🕐 20 Min       │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [Rezept-Bild]           │   │
│  │  ...                     │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### 2. REZEPT-DETAILS
```
┌─────────────────────────────────┐
│  ←                          ⋮   │
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────┐   │
│  │  [Großes Rezept-Bild]    │   │ ← Hero Image
│  └─────────────────────────┘   │
│                                 │
│  Pasta Carbonara                │ ← Titel
│  ⭐ 4.8  🕐 20 Min  👥 4 Pers  │ ← Meta
│                                 │
│  ┌─────────────────────────┐   │
│  │  💰 3,50 € gespart       │   │ ← Spar-Highlight
│  └─────────────────────────┘   │
│                                 │
│  Zutaten (mit Angeboten)         │ ← Section
│  ┌─────────────────────────┐   │
│  │  Spaghetti               │   │
│  │  💰 0,99 € (LIDL)        │   │ ← Angebot sichtbar
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │  Speck                    │   │
│  │  💰 2,49 € (REWE)         │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [+ Zu Planer hinzufügen]│   │ ← CTA Button (groß)
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### 3. PLANEN (Wochenplaner)
```
┌─────────────────────────────────┐
│  Planen                    📊  │
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────┐   │
│  │  💰 Diese Woche: 12,50 €│   │ ← Spar-Übersicht
│  │  📈 +15% vs. letzte Woche│   │
│  └─────────────────────────┘   │
│                                 │
│  Mo  | Di  | Mi  | Do  | Fr     │ ← Wochentage (Tabs)
│                                 │
│  ┌─────────────────────────┐   │
│  │  🍳 Frühstück            │   │
│  │  [Rezept-Card]           │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  🍽 Mittagessen          │   │
│  │  [Rezept-Card]           │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  🍲 Abendessen           │   │
│  │  [+ Rezept hinzufügen]  │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

### 4. PROFIL
```
┌─────────────────────────────────┐
│  Profil                         │
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────┐   │
│  │  👤 Roman Wolf          │   │ ← User Info
│  │  Seit 3 Monaten dabei   │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  💰 Gesamt gespart       │   │ ← Statistik (gamifiziert)
│  │     127,50 €            │   │
│  │  🏆 12 Rezepte gekocht   │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  Einstellungen           │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  Journal                 │   │ ← Optional, reduziert
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

---

## 🧩 Component Architecture

### Atoms
- `AppText` - Text-Komponente mit Varianten
- `AppButton` - Button-Komponente
- `AppCard` - Card-Komponente
- `AppIcon` - Icon-Komponente
- `AppBadge` - Badge für Labels

### Molecules
- `RecipeCard` - Rezept-Karte mit Bild, Titel, Meta
- `OfferBadge` - Angebots-Badge (💰 Preis)
- `SavingBanner` - Spar-Banner mit Animation
- `MealSlot` - Mahlzeit-Slot im Planer
- `CategoryChip` - Kategorie-Chip

### Organisms
- `RecipeList` - Liste von Rezepten
- `IngredientList` - Zutaten-Liste mit Angeboten
- `WeekPlan` - Wochenplaner-Grid
- `StatsCard` - Statistik-Karte

### Screens
- `DiscoverScreen` - Entdecken
- `RecipeDetailScreen` - Rezept-Details
- `PlanScreen` - Planen
- `ProfileScreen` - Profil

---

## 🎯 UX Rules

1. **Maximal 3 Sections pro Screen**
2. **Große Touch-Targets** (min. 44x44px)
3. **Große Paddings** (20-28px)
4. **Klare CTAs** (max. 1-2 pro Screen)
5. **Smooth Animations** (200-300ms)
6. **Subtile Feedback** (Haptik, Animationen)
7. **Keine langen Listen** (max. 5-7 Items sichtbar)
8. **Bilder überall** (jedes Rezept hat Bild)

---

## 🎮 Gamification (Leicht)

- **Spar-Banner** auf Home (diese Woche gespart)
- **Spar-Highlight** bei jedem Rezept
- **Statistiken** im Profil (Gesamt gespart, Rezepte gekocht)
- **Subtile Animationen** bei Erfolgen
- **Keine Punkte/Level** (nur Fortschrittsanzeigen)

---

## 📂 Folder Structure

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── widgets/
│   │   ├── atoms/
│   │   ├── molecules/
│   │   └── organisms/
│   └── utils/
├── features/
│   ├── discover/
│   │   ├── discover_screen.dart
│   │   ├── recipe_detail_screen.dart
│   │   └── widgets/
│   ├── plan/
│   │   ├── plan_screen.dart
│   │   └── widgets/
│   └── profile/
│       ├── profile_screen.dart
│       └── widgets/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
└── main.dart
```

---

## ✅ Next Steps

1. ✅ Design System implementieren
2. ✅ Atomic Components erstellen
3. ✅ Screens neu bauen
4. ✅ Navigation umbauen
5. ✅ Animationen hinzufügen

**Ready to code?** 🚀

