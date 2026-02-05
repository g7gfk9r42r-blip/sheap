# Grocify 2.0 – Architecture Overview

## System Design

Grocify is a **cross-platform grocery shopping assistant** built with Flutter on the frontend and Node.js/Express on the backend. It enables users to discover recipes based on available offers from LIDL and EDEKA supermarkets.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Mobile App (Flutter)                        │
│  ├─ iOS (native iOS build)                                       │
│  ├─ Android (native Android build)                               │
│  └─ Web (Chrome, Firefox, Safari)                                │
└────────────────────┬──────────────────────────────────────────────┘
                     │ REST API + WebSocket
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Backend API (Node.js/Express)                   │
│  ├─ GET /api/recipes                 (fetch recipes)             │
│  ├─ POST /api/offers                 (list current offers)       │
│  ├─ POST /admin/refresh-offers       (trigger offer fetch)       │
│  ├─ POST /admin/refresh-recipes      (trigger recipe gen)        │
│  ├─ POST /admin/upload-media-tar     (receive media bundle)      │
│  └─ GET /media/*                     (serve recipe images)       │
└────────────────┬─────────────────────┬─────────────────────────────┘
                 │                     │
                 ▼                     ▼
      ┌──────────────────┐   ┌──────────────────┐
      │  SQLite / PG     │   │  Media Files     │
      │  (Recipes DB)    │   │  (Images, etc)   │
      └──────────────────┘   └──────────────────┘
                 ▲
                 │ Weekly CI
                 │ (GitHub Actions)
┌────────────────────────────────────────────────────────────────┐
│           Media Generation Pipeline (Python)                    │
│  ├─ Fetch offers from LIDL/EDEKA APIs & PDFs                   │
│  ├─ Extract food items via OpenAI Vision                        │
│  ├─ Generate recipes via ChatGPT                                │
│  ├─ Create images via Replicate                                 │
│  └─ Upload tar.gz bundle to /admin/upload-media-tar             │
└────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
roman_app/
├── lib/                              # Dart/Flutter source
│   ├── main.dart                     # App entry point
│   ├── core/
│   │   ├── models/                   # Shared data models
│   │   ├── services/                 # Shared services
│   │   └── widgets/
│   │       └── molecules/            # Reusable UI components
│   ├── data/
│   │   ├── services/
│   │   │   ├── offer_api.dart        # API client for offers
│   │   │   └── recipe_repository.dart
│   │   └── models/
│   ├── features/
│   │   ├── discover/                 # Discover page (recipes, filters)
│   │   ├── onboarding/               # Post-login quick popup
│   │   ├── search/                   # Recipe search
│   │   ├── favorites/                # Bookmarked recipes
│   │   └── settings/                 # User preferences
│   ├── screens/
│   ├── theme/
│   └── utils/
│       ├── week.dart                 # ISO week key generation
│       └── constants.dart
│
├── server/                           # Node.js backend
│   ├── src/
│   │   ├── index.ts                  # Server entry point
│   │   ├── route.ts                  # API endpoints
│   │   ├── db.ts                     # Database adapters
│   │   ├── controllers/
│   │   └── middleware/
│   ├── media/                        # Generated recipe images & data (NOT in git)
│   ├── package.json
│   └── README.md
│
├── tools/                            # Automation scripts
│   ├── weekly_pro.py                 # Main generation script
│   ├── upload_media_bundle.py        # Upload to server
│   └── generate_recipes_from_offers.dart
│
├── assets/
│   ├── recipe_images/                # Bundled sample images (fallback only)
│   ├── prospekte/                    # Legacy recipe JSON data
│   ├── legal/                        # Privacy policies, licenses
│   └── ...
│
├── .github/
│   └── workflows/
│       ├── publish-weekly-media.yml  # Automated weekly publishing
│       └── refresh-offers.yml        # Backup offer refresh job
│
├── .env.example                      # Environment template
├── .gitignore
├── pubspec.yaml                      # Flutter dependencies
├── analysis_options.yaml              # Dart linting rules
├── vercel.json                       # Vercel deployment config
├── docker-compose.yml                # Local dev environment
├── ARCHITECTURE.md                   # This file
├── SECURITY.md                       # Secret management
├── README_MEDIA.md                   # Media publishing guide
└── README.md                         # Main documentation
```

---

## Frontend (Flutter/Dart)

### Key Features

1. **Discover Page** (`lib/features/discover/`)
   - Browse recipes from current weekly offers
   - Filter by supermarket (LIDL, EDEKA)
   - Sort by price, rating, cuisine type
   - Tap to view full recipe + offers

2. **Quick Onboarding** (`lib/features/onboarding/`)
   - Compact gradient popup after login (not full screens)
   - User confirms they're ready to explore
   - Sets onboarding completion flag

3. **Search & Favorites** (`lib/features/search/`, `lib/features/favorites/`)
   - Full-text recipe search
   - Bookmark favorite recipes
   - Persist favorites locally

4. **Web Support**
   - Full Flutter Web build
   - Uses bundled assets when server unavailable
   - Fallback image loading from `assets/recipe_images/`

### Key Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_auth: ^5.7.0         # Auth (optional)
  cloud_firestore: ^5.6.12      # Database (optional)
  http: ^1.1.0                  # API calls
  provider: ^6.0.0              # State management
  flutter_dotenv: ^5.0.0        # Load .env
  image_picker: ^1.0.0          # Media selection
  cached_network_image: ^3.3.0  # Image caching
```

### Image Loading Strategy

**On Web or when `API_BASE_URL` is empty:**
```dart
// Falls back to bundled assets
Image.asset('assets/recipe_images/lidl/R001.png')
```

**When server is available:**
```dart
// Fetches from `$API_BASE_URL/media/recipe_images/<market>/<id>.png`
Image.network('$apiBaseUrl/media/recipe_images/lidl/R001.png')
```

---

## Backend (Node.js/Express)

### API Endpoints

#### Public Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/recipes` | List all recipes (optional filters) |
| GET | `/api/recipes/:id` | Get single recipe details |
| GET | `/api/offers` | List current offers by market |
| GET | `/media/*` | Serve static recipe images |

#### Admin Endpoints (Protected with `x-admin-secret` header or `?key=` query)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin/refresh-offers` | Fetch & parse latest offers |
| POST | `/admin/refresh-recipes` | Generate new recipes from offers |
| POST | `/admin/upload-media-tar` | Receive & extract media bundle |

### Database Schema

**SQLite (default) or PostgreSQL (production)**

```sql
-- Recipes Table
CREATE TABLE recipes (
  id TEXT PRIMARY KEY,           -- e.g., "lidl_R001"
  title TEXT,
  description TEXT,
  instructions TEXT,
  ingredients TEXT,              -- JSON array
  market TEXT,                   -- "lidl" or "edeka"
  image_path TEXT,              -- "/media/recipe_images/lidl/R001.png"
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Offers Table
CREATE TABLE offers (
  id TEXT PRIMARY KEY,
  title TEXT,
  price REAL,
  market TEXT,
  product_url TEXT,
  fetched_at TIMESTAMP
);
```

---

## Weekly Media Generation Pipeline

### Trigger: GitHub Actions (Sunday 19:00 UTC)

**Workflow**: `.github/workflows/publish-weekly-media.yml`

```yaml
schedule:
  - cron: '0 19 * * 0'  # Weekly at Sunday 19:00 UTC
```

### Steps

1. **Checkout code**
   - Clone the repository

2. **Setup Python + Dependencies**
   - Install OpenAI, Replicate, Pillow, etc.

3. **Run `tools/weekly_pro.py --publish-server`**
   - Fetches offers from APIs
   - Parses PDFs via OCR (OpenAI Vision)
   - Generates recipes (ChatGPT)
   - Creates images (Replicate)
   - Outputs to `server/media/`

4. **Run `tools/upload_media_bundle.py`**
   - Tars `server/media/`
   - POSTs to `/admin/upload-media-tar`
   - Backend extracts and serves

5. **App Polls for Updates**
   - On next app launch, fetches fresh recipes
   - Displays new images from `/media/`

---

## Environment Configuration

### Development (Local)

```bash
# .env (local only, never committed)
API_BASE_URL=http://localhost:3000
OPENAI_API_KEY=sk-proj-...
ADMIN_SECRET=local-secret
```

```bash
# Start server
cd server && npm install && node src/index.js

# Start app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

### Staging / Production

```bash
# GitHub Secrets (encrypted, not in repo)
API_BASE_URL=https://api-staging.example.com
ADMIN_SECRET=<strong-random-key>
OPENAI_API_KEY=sk-proj-...
```

Backend deployed via:
- **Vercel** (serverless)
- **Docker + VPS** (full control)
- **AWS Lambda** (scalable)

---

## Security Considerations

1. **No Secrets in Repo**
   - `.env` in `.gitignore`
   - `.env.example` with placeholders
   - Secrets stored in GitHub Secrets

2. **Admin Endpoints Protected**
   - Require `x-admin-secret` header
   - Rate-limited
   - Logged for audit

3. **Media Server**
   - Static files (images, JSON)
   - Long cache headers (1 week)
   - CDN-friendly

4. **CI/CD Security**
   - Pre-commit hooks to prevent secret commits
   - GitHub secret scanning enabled
   - Branch protection rules enforced

---

## Deployment Checklist

- [ ] Backend `.env` configured with production database
- [ ] Secrets set in GitHub Actions
- [ ] Media bucket / server storage ready
- [ ] SSL/TLS certificates configured
- [ ] Rate limiting & DDoS protection active
- [ ] Monitoring & alerting set up
- [ ] Backup & disaster recovery plan
- [ ] Legal (privacy policy, terms) reviewed

---

## Future Enhancements

- [ ] GraphQL API for more efficient data fetching
- [ ] Real-time recipe updates (WebSocket)
- [ ] User meal planning & shopping lists
- [ ] Social sharing (recipes, meal plans)
- [ ] ML-based recipe recommendations
- [ ] Multi-language support (DE, EN, FR)
- [ ] More supermarkets (Kaufland, Rewe, etc.)

---

For more details, see:
- [README_MEDIA.md](README_MEDIA.md) – Media publishing pipeline
- [SECURITY.md](SECURITY.md) – Secret management & security practices
- [server/README.md](server/README.md) – Backend-specific setup
