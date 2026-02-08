# Phase 2: Information Architecture & User Flows

## App Map

```
Grocify App
│
├── Home (HomeScreen) ⭐ Current Focus
│   ├── Today's Meal Card
│   ├── Weekly Recipe Highlights
│   ├── Reflection & Motivation
│   └── Hydration Tracker
│
├── Plan (PlanScreenNew)
│   ├── Weekly Calendar View
│   ├── Meal Planning Interface
│   └── Recipe Selection
│
├── Shopping (ShoppingListScreen)
│   ├── Shopping List
│   ├── Ingredient Management
│   └── Store Integration
│
├── Discover (DiscoverScreen)
│   ├── Recipe Browser
│   ├── Filter by Retailer
│   ├── Recipe Detail View
│   └── Offer Integration
│
└── Profile (ProfileScreenNew)
    ├── User Settings
    ├── Preferences
    └── Data Management
```

### Navigation Structure
- **Bottom Navigation**: Primary navigation between main sections
- **Deep Links**: Recipe detail screens accessible from multiple entry points
- **Back Navigation**: Standard Flutter navigation stack

---

## HomeScreen Information Architecture

### Content Hierarchy (Top to Bottom)

1. **Header Section** (Fixed)
   - Greeting (time-based)
   - User name
   - Subtitle/motto
   - Avatar/Profile access

2. **Today's Meal Section** (Primary Content)
   - Current meal plan OR empty state
   - Quick action: View recipe / Get inspiration

3. **Weekly Highlights Section** (Secondary Content)
   - Top 3-5 recipes for the week
   - Horizontal scrollable list
   - Quick action: View all recipes

4. **Reflection Section** (Tertiary Content)
   - Motivational quote
   - Mood selection
   - Reflection text input
   - Save action

5. **Hydration Tracker** (Tertiary Content)
   - Progress indicator
   - Quick add button
   - Current progress display

### Information Priority
- **P0 (Must See)**: Today's meal, Header
- **P1 (Should See)**: Weekly highlights
- **P2 (Nice to See)**: Reflection, Hydration

---

## User Flows

### Flow 1: "View Today's Planned Meal"

**Task**: User wants to see what meal is planned for today and access recipe details.

```
1. User opens app → HomeScreen loads
   ├─ If meal exists:
   │  └─ Display meal card with recipe title, retailer, savings
   │
   └─ If no meal:
      └─ Display empty state with "Get Inspiration" CTA

2. User taps "Rezept öffnen" button
   └─ Navigate to RecipeDetailScreenNew
      ├─ Show full recipe details
      ├─ Ingredients list
      ├─ Instructions
      └─ Back button returns to HomeScreen

3. User can also:
   └─ Tap recipe image/card → Same navigation to detail
```

**Success Criteria:**
- User can see today's meal in < 2 seconds
- Recipe detail accessible in 1 tap
- Clear visual hierarchy (meal is prominent)

**Potential Issues:**
- ❌ If meal card is too small, hard to tap
- ❌ If navigation is slow, feels unresponsive
- ✅ **Solution**: Large touch targets, smooth animations

---

### Flow 2: "Get Inspiration for Today"

**Task**: User has no meal planned and wants to find a recipe for today.

```
1. User sees empty state on HomeScreen
   └─ "Noch kein Rezept für heute geplant?" card displayed

2. User taps "Inspiration holen" button
   └─ Navigate to DiscoverScreen (or modal)
      ├─ Show recipe list filtered by current offers
      ├─ User can browse recipes
      └─ User selects a recipe

3. User views recipe detail
   └─ RecipeDetailScreenNew
      └─ Option to "Plan for Today" (future feature)

4. User returns to HomeScreen
   └─ (Future: Selected recipe now appears in today's meal)
```

**Success Criteria:**
- Empty state is encouraging, not discouraging
- Path to inspiration is clear (1 tap)
- User doesn't feel lost or stuck

**Potential Issues:**
- ❌ Empty state feels like failure
- ❌ Too many steps to find recipe
- ✅ **Solution**: Positive empty state, direct path to discovery

---

### Flow 3: "Track Daily Habits"

**Task**: User wants to log hydration and set daily mood/reflection.

```
1. User scrolls to Hydration Tracker
   └─ Sees current progress (e.g., 3/8 glasses)

2. User taps "+" button
   └─ Haptic feedback
   └─ Progress updates (4/8)
   └─ Visual feedback (progress bar animates)

3. User continues until goal reached (8/8)
   └─ Success message appears
   └─ Button changes to checkmark

4. User scrolls to Reflection section
   └─ Sees motivational quote

5. User selects mood chip
   └─ Haptic feedback
   └─ Chip highlights
   └─ Can deselect by tapping again

6. User types reflection
   └─ "Speichern" button appears

7. User taps "Speichern"
   └─ Haptic feedback
   └─ Success snackbar
   └─ Button disappears (saved state)
```

**Success Criteria:**
- All actions feel responsive (< 100ms feedback)
- Clear visual feedback for all interactions
- User understands what was saved

**Potential Issues:**
- ❌ Unclear if reflection is saved
- ❌ No feedback on hydration add
- ✅ **Solution**: Haptic + visual feedback, clear save confirmation

---

### Flow 4: "Browse Weekly Highlights"

**Task**: User wants to see top recipes for the week and explore options.

```
1. User scrolls to "Top-Rezepte dieser Woche" section
   └─ Sees horizontal list of 3-5 recipe cards

2. User swipes horizontally
   └─ Cards scroll smoothly
   └─ Can see recipe title, badge (savings/favorite)

3. User taps a recipe card
   └─ Navigate to RecipeDetailScreenNew
      └─ Full recipe information

4. User can tap "Alle anzeigen"
   └─ Navigate to DiscoverScreen
      └─ Full recipe list with filters
```

**Success Criteria:**
- Smooth horizontal scrolling
- Cards are tappable and visually clear
- Easy to see what makes each recipe special (badges)

**Potential Issues:**
- ❌ Cards too small to see details
- ❌ Scrolling feels janky
- ✅ **Solution**: Adequate card size (180px width), smooth ListView

---

## Navigation Patterns

### Entry Points to HomeScreen
1. **App Launch**: Default screen
2. **Bottom Navigation**: "Home" tab
3. **Back Navigation**: From any detail screen

### Exit Points from HomeScreen
1. **Recipe Detail**: Tap recipe card/button → RecipeDetailScreenNew
2. **Discover**: Tap "Inspiration holen" or "Alle anzeigen" → DiscoverScreen
3. **Profile**: Tap avatar (future feature) → ProfileScreenNew

### Deep Linking Considerations
- HomeScreen should handle deep links to specific recipes
- Should restore scroll position when returning from detail screens
- Should maintain state (hydration, reflection) across navigation

---

## Content Strategy

### Dynamic Content
- **Today's Meal**: Changes based on meal plan service
- **Weekly Highlights**: Updates weekly based on current offers
- **Motivational Quote**: Rotates daily (based on day of month)
- **Greeting**: Changes based on time of day

### Static Content
- **Header**: User name, avatar
- **Section Headers**: "Top-Rezepte dieser Woche", etc.
- **Empty States**: Consistent messaging

### Loading States
- **Initial Load**: Show skeleton screens or placeholders
- **Data Refresh**: Pull-to-refresh (future feature)
- **Error States**: Clear error messages with retry options

---

## Information Density Guidelines

### Mobile (Primary)
- **Above the fold**: Header + Today's Meal (most important)
- **Scrollable**: Highlights, Reflection, Hydration
- **Maximum 3-4 sections visible** before scrolling needed

### Tablet (Secondary)
- **More horizontal space**: Could show 2 columns for highlights
- **Larger cards**: More information visible per card
- **Side-by-side**: Reflection and Hydration could be side-by-side

### Web (Future)
- **Grid layout**: Multiple recipe cards visible
- **Sticky header**: Navigation always accessible
- **Wider content**: More information density

