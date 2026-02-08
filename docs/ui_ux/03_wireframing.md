# Phase 3: Wireframing & Prototyping

## HomeScreen Wireframe (Textual Description)

### Layout Structure

```
┌─────────────────────────────────────┐
│ SAFE AREA (Top)                     │
├─────────────────────────────────────┤
│                                     │
│ [HEADER SECTION]                    │
│ ┌─────────────────────────────┐    │
│ │ Guten Morgen, Roman 👋      │    │
│ │ Lass uns heute smart...     │    │
│ │                    [Avatar]  │    │
│ └─────────────────────────────┘    │
│                                     │
│ [SPACING: 24px]                     │
│                                     │
│ [TODAY'S MEAL CARD]                 │
│ ┌─────────────────────────────┐    │
│ │ 🍽️ Was steht heute an?      │    │
│ │    Mittagessen              │    │
│ │                             │    │
│ │ [Recipe Image Placeholder]  │    │
│ │                             │    │
│ │ Recipe Title                │    │
│ │ 🏪 Retailer  ~€4.50 sparen  │    │
│ │                             │    │
│ │ [Rezept öffnen Button]      │    │
│ └─────────────────────────────┘    │
│                                     │
│ [SPACING: 24px]                     │
│                                     │
│ [WEEKLY HIGHLIGHTS SECTION]         │
│ ┌─────────────────────────────┐    │
│ │ Top-Rezepte dieser Woche [Alle]│ │
│ └─────────────────────────────┘    │
│ ┌──────┐ ┌──────┐ ┌──────┐          │
│ │Card 1│ │Card 2│ │Card 3│ →        │
│ │[Img] │ │[Img] │ │[Img] │          │
│ │Title │ │Title │ │Title │          │
│ │Badge │ │Badge │ │Badge │          │
│ └──────┘ └──────┘ └──────┘          │
│                                     │
│ [SPACING: 24px]                     │
│                                     │
│ [REFLECTION SECTION]                 │
│ ┌─────────────────────────────┐    │
│ │ 🌱 Motivational Quote...     │    │
│ └─────────────────────────────┘    │
│ ┌─────────────────────────────┐    │
│ │ ✨ Dein Start in den Tag    │    │
│ │                             │    │
│ │ [🔥 Fokus] [😌 Entspannt]   │    │
│ │ [🥱 Müde] [🤯 Überladen]     │    │
│ │                             │    │
│ │ [Reflection Text Input]     │    │
│ │                             │    │
│ │              [Speichern]     │    │
│ └─────────────────────────────┘    │
│                                     │
│ [SPACING: 16px]                     │
│                                     │
│ [HYDRATION TRACKER]                 │
│ ┌─────────────────────────────┐    │
│ │ 💧 Schon genug getrunken... │    │
│ │ [Progress Bar] 3/8 [+ Button]│   │
│ └─────────────────────────────┘    │
│                                     │
│ [SPACING: 24px + 20px]              │
│ (Bottom padding for nav bar)        │
└─────────────────────────────────────┘
```

---

## Component Breakdown

### 1. Header Section

**Layout Block:**
- **Type**: Row layout
- **Left Side**: Column with greeting text
  - Line 1: Greeting + Name (Flexible text, max 1 line)
  - Line 2: Subtitle (full width)
- **Right Side**: Avatar circle (56x56dp, fixed size)
- **Padding**: 20px horizontal, 20px top
- **Spacing**: 8px between greeting and emoji, 8px between lines

**Content:**
- Dynamic greeting based on time
- User name (hardcoded for now, future: from profile)
- Motto/subtitle
- Avatar with initial

**Interactions:**
- Avatar: Tappable (future: navigate to profile)
- No other interactions

---

### 2. Today's Meal Card

**Layout Block:**
- **Type**: Card container
- **Padding**: 16px internal
- **Border Radius**: 20px
- **Content Structure**:
  1. Header row: Icon + Text column
  2. Image placeholder (180px height)
  3. Recipe title
  4. Metadata row (retailer + savings badge)
  5. Primary action button

**States:**
- **With Meal**: Shows recipe details
- **Empty State**: Shows emoji, message, CTA button

**Content (With Meal):**
- Icon: 🍽️ in colored container
- Label: "Was steht heute an?" (14px)
- Meal type: "Mittagessen" (16px, bold)
- Image: Gradient placeholder with icon
- Title: Recipe name (18px, bold)
- Metadata: Store icon + name, savings badge
- Button: "Rezept öffnen" (full width, 56px height)

**Content (Empty State):**
- Large emoji: 🍳 (48px)
- Title: "Noch kein Rezept für heute geplant?" (16px, bold)
- Description: 2-3 lines of text (14px)
- Button: "Inspiration holen" (full width)

**Interactions:**
- Button: Navigate to recipe detail or discovery
- Card: Not tappable (button is primary action)

---

### 3. Weekly Highlights Section

**Layout Block:**
- **Type**: Column with header + horizontal list
- **Header**: Row with title + "Alle" button
- **Content**: Horizontal scrollable ListView

**Header:**
- Title: "Top-Rezepte dieser Woche" (left, flexible)
- Button: "Alle" (right, 48x48dp minimum)
- Padding: 20px horizontal

**Card Structure** (180px width each):
- Image area: 130px height
- Content area: Padding 16px
  - Title: 2 lines max, ellipsis
  - Badge: Savings/Favorite/Top indicator

**Spacing:**
- Between cards: 16px
- List padding: 20px horizontal
- Section spacing: 24px above/below

**Interactions:**
- Cards: Tappable, navigate to detail
- "Alle" button: Navigate to full recipe list
- Horizontal scroll: Smooth, with bounce physics

---

### 4. Reflection Section

**Layout Block:**
- **Type**: Column with 2 cards
- **Card 1**: Motivation quote
- **Card 2**: Mood selection + text input

**Motivation Card:**
- Row layout: Icon container + text
- Icon: Emoji in colored container (12px padding)
- Text: Quote (14px, flexible width)
- Padding: 16px internal

**Reflection Card:**
- Header: Icon + title row
- Mood chips: Wrap layout (4 chips)
- Text input: Multi-line (3 lines max)
- Save button: Conditional (only if text entered)

**Mood Chip Structure:**
- Minimum size: 48x48dp (accessibility)
- Content: Emoji (20px) + Label (14px)
- Spacing: 12px between chips
- Border: 1-1.5px, colored when selected

**Interactions:**
- Mood chips: Toggle selection, haptic feedback
- Text input: Standard text field
- Save button: Appears on text change, saves on tap

---

### 5. Hydration Tracker

**Layout Block:**
- **Type**: Row layout
- **Left**: Icon container (56x56dp)
- **Center**: Column with title + progress
- **Right**: Add button (48x48dp minimum)

**Content:**
- Icon: 💧 in gradient container
- Title: "Schon genug getrunken heute?" (14px)
- Progress: LinearProgressIndicator + counter badge
- Button: "+" icon or checkmark when complete

**Progress Bar:**
- Height: 10px
- Border radius: 8px
- Color: Changes to green when complete
- Counter: "X/8" in colored badge

**Interactions:**
- Add button: Increment counter, haptic feedback
- Button disabled/changes when goal reached
- Success message on completion

---

## Responsive Breakpoints

### Mobile (320px - 480px)
- **Single column**: All sections stack vertically
- **Card width**: Full width minus 40px padding
- **Recipe cards**: 160px width (smaller screens)
- **Touch targets**: Minimum 48x48dp

### Tablet (481px - 768px)
- **Card width**: Max 600px, centered
- **Recipe cards**: 200px width
- **Reflection + Hydration**: Could be side-by-side (future)

### Desktop (769px+)
- **Content width**: Max 800px, centered
- **Grid layout**: Multiple recipe cards per row (future)
- **Sticky elements**: Header could be sticky (future)

---

## Wireframe JSON Structure

```json
{
  "screen": "HomeScreen",
  "layout": "vertical_scroll",
  "sections": [
    {
      "id": "header",
      "type": "header",
      "layout": "row",
      "components": [
        {
          "id": "greeting",
          "type": "text_column",
          "flex": 1,
          "content": ["greeting_text", "subtitle"]
        },
        {
          "id": "avatar",
          "type": "avatar",
          "size": "56x56",
          "fixed": true
        }
      ]
    },
    {
      "id": "today_meal",
      "type": "card",
      "states": ["with_meal", "empty"],
      "components": [
        {"id": "meal_header", "type": "row"},
        {"id": "meal_image", "type": "image_placeholder", "height": 180},
        {"id": "meal_title", "type": "text"},
        {"id": "meal_metadata", "type": "row"},
        {"id": "meal_action", "type": "button", "primary": true}
      ]
    },
    {
      "id": "weekly_highlights",
      "type": "section",
      "components": [
        {"id": "section_header", "type": "row"},
        {
          "id": "recipe_list",
          "type": "horizontal_list",
          "item_width": 180,
          "item_template": "recipe_card"
        }
      ]
    },
    {
      "id": "reflection",
      "type": "section",
      "components": [
        {"id": "motivation_card", "type": "card"},
        {"id": "reflection_card", "type": "card"}
      ]
    },
    {
      "id": "hydration",
      "type": "card",
      "layout": "row",
      "components": [
        {"id": "hydration_icon", "type": "icon_container"},
        {"id": "hydration_progress", "type": "column"},
        {"id": "hydration_button", "type": "button"}
      ]
    }
  ]
}
```

---

## Interaction States

### Card States
- **Default**: White background, subtle shadow
- **Pressed**: Slight scale down (0.95), darker shadow
- **Loading**: Skeleton screen or shimmer effect

### Button States
- **Enabled**: Full opacity, gradient background
- **Disabled**: 50% opacity, no interaction
- **Pressed**: Scale animation (0.95)
- **Loading**: Spinner replaces content

### Input States
- **Default**: Light gray background
- **Focused**: Border highlight, slightly elevated
- **Error**: Red border (future feature)
- **Filled**: Background color change

---

## Animation Specifications

### Transitions
- **Page Load**: Fade in (300ms)
- **Card Appear**: Slide up + fade (300ms, staggered)
- **State Change**: Smooth color/opacity transition (200ms)
- **Navigation**: Fade transition (300ms)

### Micro-interactions
- **Button Tap**: Scale 0.95 (100ms)
- **Chip Selection**: Border color + background (200ms)
- **Progress Update**: Smooth value animation (400ms)
- **Haptic Feedback**: Light impact on interactions

### Scroll Behavior
- **Physics**: BouncingScrollPhysics (iOS-like)
- **Scroll Indicators**: Auto-hide after 2 seconds
- **Pull to Refresh**: (Future feature)

---

## Empty States

### No Meal Planned
- **Visual**: Large emoji (🍳, 48px)
- **Message**: Encouraging, not negative
- **Action**: Clear CTA button
- **Tone**: "Opportunity" not "Failure"

### No Highlights
- **Visual**: Chart emoji (📊, 40px)
- **Message**: Explains when content will appear
- **Action**: None (passive state)
- **Tone**: Informative, not empty

### No Reflection
- **Visual**: Sparkle emoji (✨, 20px)
- **Message**: Encourages daily reflection
- **Action**: Text input is always available
- **Tone**: Inviting, not required

