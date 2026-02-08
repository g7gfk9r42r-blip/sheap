# Phase 4: Visual Design & Design System

## Typography Scale

### Display (Large Headings)
- **Display Large**: 34px, Weight 700, Letter Spacing -1.5
  - Use: Main greeting with name
  - Example: "Guten Morgen, Roman"
  
- **Display Small**: 28px, Weight 600, Letter Spacing -0.5
  - Use: Section headers, important titles
  - Example: "Top-Rezepte dieser Woche"

### Headlines
- **Headline Small**: 24px, Weight 600, Letter Spacing -0.5
  - Use: Card titles, section headers
  - Example: "Dein Start in den Tag"

### Titles
- **Title Large**: 18px, Weight 600, Letter Spacing 0
  - Use: Recipe titles, important content
  - Example: "Hähnchen-Gyros Bowl"
  
- **Title Medium**: 16px, Weight 600, Letter Spacing 0.15
  - Use: Meal type labels, card subtitles
  - Example: "Mittagessen"
  
- **Title Small**: 14px, Weight 600, Letter Spacing 0.1
  - Use: Section labels, card metadata
  - Example: "Was steht heute an?"

### Body Text
- **Body Large**: 16px, Weight 400, Letter Spacing 0.15
  - Use: Primary body text, descriptions
  - Line Height: 1.5
  
- **Body Medium**: 15px, Weight 400, Letter Spacing 0.25
  - Use: Secondary text, subtitles
  - Line Height: 1.5
  - Example: "Lass uns heute smart essen & klar denken."
  
- **Body Small**: 14px, Weight 400, Letter Spacing 0.4
  - Use: Helper text, metadata
  - Line Height: 1.5
  - Example: Recipe retailer names

### Labels & Captions
- **Label Large**: 14px, Weight 600, Letter Spacing 0.1
  - Use: Button labels, chip text
  - Example: "Rezept öffnen"
  
- **Label Medium**: 12px, Weight 600, Letter Spacing 0.5
  - Use: Badges, small labels
  - Example: "-32%", "Favorit"
  
- **Caption**: 13px, Weight 400, Letter Spacing 0.4
  - Use: Small metadata, hints
  - Example: "3/8" in hydration tracker

### Accessibility Notes
- **Minimum readable size**: 14px (Body Small)
- **WCAG AA compliance**: All text meets 4.5:1 contrast ratio
- **Line height**: Minimum 1.4 for readability

---

## Color Palette

### Primary Colors
- **Primary**: `#6366F1` (Indigo)
  - Use: Main actions, links, accents
  - Contrast: White text (21:1)
  
- **Primary Light**: `#818CF8`
  - Use: Gradients, hover states
  
- **Primary Dark**: `#4F46E5`
  - Use: Pressed states, emphasis

### Secondary Colors
- **Secondary**: `#80CBC4` (Soft Mint)
  - Use: Secondary actions, hydration tracker
  - Contrast: Dark text (4.8:1)
  
- **Secondary Light**: `#B2DFDB`
  - Use: Backgrounds, subtle highlights
  
- **Secondary Dark**: `#4DB6AC`
  - Use: Text on light backgrounds

### Semantic Colors
- **Success**: `#10B981` (Emerald Green)
  - Use: Savings badges, completion states
  - Contrast: White text (4.6:1)
  
- **Success Light**: `#34D399`
  - Use: Gradients, backgrounds
  
- **Error**: `#EF4444` (Red)
  - Use: Error messages, warnings
  - Contrast: White text (4.5:1)
  
- **Warning**: `#FF9800` (Orange)
  - Use: Warnings, attention needed
  - Contrast: White text (3.1:1)
  
- **Accent**: `#FFB800` (Warm Amber)
  - Use: Highlights, special badges
  - Contrast: Dark text (4.2:1)

### Background Colors
- **Background**: `#FFFBF7` (Warm Cream)
  - Use: Main app background
  - Provides warm, calm feeling
  
- **Surface**: `#FFFFFF` (White)
  - Use: Cards, elevated surfaces
  - Contrast: Primary text (21:1)
  
- **Surface Subtle**: `#FFF8F3` (Light Cream)
  - Use: Input backgrounds, subtle containers
  - Contrast: Primary text (19:1)
  
- **Surface Elevated**: `#FFFEFB` (Off-White)
  - Use: Elevated cards, modals

### Text Colors
- **Text Primary**: `#2C2C2C` (Dark Gray)
  - Use: Main content, headings
  - Contrast on Surface: 21:1
  
- **Text Secondary**: `#6B6B6B` (Medium Gray)
  - Use: Secondary text, metadata
  - Contrast on Surface: 7.2:1
  
- **Text Tertiary**: `#9E9E9E` (Light Gray)
  - Use: Placeholders, hints
  - Contrast on Surface: 4.8:1

### Border Colors
- **Border**: `#E8E8E8` (Light Gray)
  - Use: Card borders, dividers
  - Subtle, not distracting
  
- **Divider**: `#F5F5F5` (Very Light Gray)
  - Use: Section dividers

### Color Usage Guidelines
- **Primary actions**: Use Primary color
- **Secondary actions**: Use Secondary color
- **Success indicators**: Use Success color
- **Backgrounds**: Use warm, light tones
- **Text**: Ensure WCAG AA contrast (4.5:1 minimum)

---

## Design System Components

### Buttons

#### Primary Button
```dart
PrimaryButton(
  label: String,
  icon: IconData?,
  onPressed: VoidCallback?,
  backgroundColor: Color?,
  gradient: LinearGradient?,
)
```

**Specifications:**
- **Height**: 56dp (accessibility standard)
- **Padding**: 16px horizontal, 12px vertical
- **Border Radius**: 16px (radiusLG)
- **Typography**: Label Large (14px, Weight 600)
- **States**:
  - Enabled: Full opacity, gradient background
  - Disabled: 50% opacity
  - Pressed: Scale 0.95, haptic feedback
  - Loading: Spinner replaces content

**Visual Style:**
- Gradient background (Primary or Secondary)
- White text
- Subtle shadow (elevation)
- Smooth scale animation on press

#### Text Button
```dart
TextButton(
  onPressed: VoidCallback?,
  child: Text,
)
```

**Specifications:**
- **Minimum Size**: 48x48dp (touch target)
- **Padding**: 12px horizontal, 8px vertical
- **Typography**: Label Large (14px, Weight 600)
- **Color**: Primary color
- **No background**, underline on press (optional)

---

### Cards

#### GrocifyCard (Base Card)
```dart
GrocifyCard(
  child: Widget,
  backgroundColor: Color?,
  borderRadius: BorderRadius?,
  padding: EdgeInsets?,
  onTap: VoidCallback?,
)
```

**Specifications:**
- **Background**: Surface color (white)
- **Border Radius**: 20px (radiusXL)
- **Padding**: 16px default (spaceLG)
- **Shadow**: Subtle (0.06 opacity, 16px blur, 4px offset)
- **Border**: Optional, 1px, Border color
- **States**:
  - Default: White background, subtle shadow
  - Tappable: Slight elevation on press
  - Loading: Skeleton screen

**Variants:**
- **Standard Card**: White background, padding
- **Gradient Card**: Gradient background (motivation card)
- **Bordered Card**: Border instead of shadow (minimalist variant)

---

### Input Fields

#### Text Field
```dart
TextField(
  controller: TextEditingController,
  decoration: InputDecoration,
)
```

**Specifications:**
- **Height**: Auto (min 48dp for touch target)
- **Padding**: 16px internal (spaceLG)
- **Border Radius**: 16px (radiusLG)
- **Background**: Surface Subtle color
- **Border**: None (filled style)
- **Typography**: Body Medium (15px)
- **States**:
  - Default: Light gray background
  - Focused: Primary border (2px), elevated
  - Error: Red border (future)
  - Disabled: 50% opacity

---

### Chips & Badges

#### Mood Chip
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  minHeight: 48,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(999),
    border: Border.all(),
  ),
)
```

**Specifications:**
- **Minimum Size**: 48x48dp (accessibility)
- **Padding**: 16px horizontal, 12px vertical
- **Border Radius**: 999px (pill shape)
- **Typography**: Body Medium (14px, Weight 500/600)
- **States**:
  - Default: Light background, gray border
  - Selected: Primary background tint, primary border (1.5px)
  - Pressed: Haptic feedback, scale animation

#### Savings Badge
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    gradient: SuccessGradient,
    borderRadius: BorderRadius.circular(999),
  ),
)
```

**Specifications:**
- **Padding**: 12px horizontal, 6px vertical
- **Border Radius**: 999px (pill shape)
- **Typography**: Label Medium (12px, Weight 600)
- **Background**: Success gradient
- **Text Color**: White

---

### Progress Indicators

#### Linear Progress Bar
```dart
LinearProgressIndicator(
  value: double,
  backgroundColor: Color,
  valueColor: AlwaysStoppedAnimation<Color>,
  minHeight: 10,
)
```

**Specifications:**
- **Height**: 10dp (minHeight)
- **Border Radius**: 8px
- **Background**: Surface Subtle
- **Progress Color**: Secondary (or Success when complete)
- **Animation**: Smooth value transition (400ms)

---

### Icons & Emojis

#### Icon Sizes
- **Small**: 16px - Metadata, inline icons
- **Medium**: 20px - Buttons, chips
- **Large**: 24px - Card icons, primary actions
- **XLarge**: 28px - Emojis in containers
- **XXLarge**: 40-48px - Empty states, large emojis

#### Emoji Usage
- **In Cards**: 24px (motivation, reflection)
- **Empty States**: 48px (no meal planned)
- **Mood Chips**: 20px (inline with text)
- **Hydration**: 28px (in container)

---

## Spacing System

### Spacing Scale
- **XS**: 4px - Tight spacing, icon gaps
- **SM**: 8px - Small gaps, icon-text spacing
- **MD**: 12px - Standard gaps, chip spacing
- **LG**: 16px - Card padding, section spacing
- **XL**: 20px - Screen padding, large gaps
- **XXL**: 24px - Section separation
- **XXXL**: 32px - Major section breaks
- **XXXXL**: 48px - Large section breaks

### Usage Guidelines
- **Card Internal**: 16px (spaceLG)
- **Between Cards**: 24px (spaceXXL)
- **Screen Padding**: 20px (screenPadding)
- **Section Headers**: 24px bottom margin
- **Touch Targets**: Minimum 48x48dp

---

## Shadows & Elevation

### Shadow Levels
- **SM**: `0 2px 8px rgba(0,0,0,0.04)` - Subtle elevation
- **MD**: `0 4px 16px rgba(0,0,0,0.06)` - Cards, buttons
- **LG**: `0 8px 24px rgba(0,0,0,0.08)` - Elevated cards, modals

### Usage
- **Cards**: MD shadow
- **Buttons**: MD shadow (when enabled)
- **Elevated Elements**: LG shadow
- **Borders**: Alternative to shadows (minimalist approach)

---

## Border Radius

### Radius Scale
- **SM**: 8px - Small elements, progress bars
- **MD**: 12px - Icon containers, badges
- **LG**: 16px - Buttons, inputs
- **XL**: 20px - Cards (primary)
- **XXL**: 24px - Large cards, modals
- **Round**: 999px - Pills, chips, badges

### Usage
- **Cards**: 20px (radiusXL)
- **Buttons**: 16px (radiusLG)
- **Inputs**: 16px (radiusLG)
- **Chips**: 999px (radiusRound)
- **Icon Containers**: 12px (radiusMD)

---

## Gradients

### Primary Gradient
```dart
LinearGradient(
  colors: [Primary, PrimaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
- Use: Primary buttons, avatar

### Secondary Gradient
```dart
LinearGradient(
  colors: [Secondary, SecondaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
- Use: Secondary buttons, hydration icon

### Success Gradient
```dart
LinearGradient(
  colors: [Success, SuccessLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
- Use: Savings badges, completion states

### Warm Gradient
```dart
LinearGradient(
  colors: [Color(0xFFFFE0B2), Color(0xFFFFCCBC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
- Use: Recipe image placeholders

### Cool Gradient
```dart
LinearGradient(
  colors: [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
- Use: Hydration tracker icon

---

## Implementation Recommendations

### Flutter Theme Structure
```dart
// Recommended structure:
lib/core/theme/
  ├── grocify_theme.dart (main theme)
  ├── home_colors.dart (home-specific colors)
  ├── typography.dart (text styles)
  └── components.dart (component themes)
```

### Component Widgets
```dart
lib/core/widgets/
  ├── grocify_card.dart ✅ (exists)
  ├── primary_button.dart ✅ (exists)
  ├── text_button.dart (recommended)
  ├── chip_widget.dart (recommended)
  ├── badge_widget.dart (recommended)
  └── progress_indicator.dart (recommended)
```

### Best Practices
1. **Use Theme.of(context)**: Access theme values consistently
2. **Extract Constants**: Define spacing, sizes in theme file
3. **Reusable Components**: Create widget library for common patterns
4. **Semantic Colors**: Use theme colors, not hardcoded values
5. **Responsive**: Use MediaQuery for breakpoints

---

## Design Tokens (JSON)

```json
{
  "colors": {
    "primary": "#6366F1",
    "primaryLight": "#818CF8",
    "primaryDark": "#4F46E5",
    "secondary": "#80CBC4",
    "success": "#10B981",
    "background": "#FFFBF7",
    "surface": "#FFFFFF",
    "textPrimary": "#2C2C2C",
    "textSecondary": "#6B6B6B"
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 20,
    "xxl": 24,
    "screenPadding": 20
  },
  "typography": {
    "displayLarge": {"size": 34, "weight": 700},
    "titleLarge": {"size": 18, "weight": 600},
    "bodyMedium": {"size": 15, "weight": 400}
  },
  "radius": {
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 20,
    "round": 999
  }
}
```

