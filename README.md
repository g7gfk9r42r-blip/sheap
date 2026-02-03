# roman_app

A Flutter + Node/Express monorepo for grocery offers and recipe recommendations.

## Features

- **Offers Management**: Fetch and display current grocery offers from major German retailers (REWE, EDEKA, LIDL, ALDI, NETTO)
- **Recipe Generation**: AI-powered recipe suggestions based on current offers (Phase 3: Mock data, Phase 4: Real AI)
- **Flutter App**: Modern mobile interface with bottom navigation and pull-to-refresh
- **Data Persistence**: Lightweight JSON file storage for offers and recipes
- **Automated Refresh**: Weekly offer updates via Vercel Cron and GitHub Actions

## API Endpoints

### Public Endpoints
- `GET /healthz` - Health check
- `GET /offers?retailer={retailer}&week={weekKey}` - Fetch offers (optional filters)
- `GET /recipes?retailer={retailer}&week={weekKey}` - Fetch recipes (optional filters)

### Admin Endpoints
- `POST /admin/refresh-offers` - Refresh offers (requires x-admin-secret header)
- `GET /admin/refresh-offers?key={secret}` - Refresh offers (for Vercel Cron)
- `POST /admin/refresh-recipes` - Generate AI recipes (requires x-admin-secret header)
- `GET /admin/refresh-recipes?key={secret}` - Generate AI recipes (for Vercel Cron)

## Local development

Server:
```bash
cd server
cp .env.example .env
# Edit .env and set:
# - ADMIN_SECRET=your_secret_here
# - OPENAI_API_KEY=your_openai_key_here (optional)
# - DB=sqlite (default)
npm ci
npm run dev
```

Smoke test (in another terminal):
```bash
ADMIN_SECRET=changeme API_BASE_URL=http://localhost:3000 DB=sqlite ./scripts/smoke.sh
# or via npm: npm --prefix server run smoke
```

Flutter app:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000 \
            --dart-define=DEBUG_ADMIN_SECRET=changeme
```

## Scheduling

Vercel Cron is configured in `vercel.json`:

```json
{
  "crons": [
    { "path": "/admin/refresh-offers?key=${ADMIN_SECRET}", "schedule": "0 18 * * 0" },
    { "path": "/admin/refresh-recipes?key=${ADMIN_SECRET}", "schedule": "30 18 * * 0" }
  ]
}
```

Set `ADMIN_SECRET` and `OPENAI_API_KEY` in Vercel Project Settings → Environment Variables.

### GitHub Actions fallback

Workflow `.github/workflows/refresh-offers.yml` runs weekly (UTC) and can be triggered manually.

- Set repo secrets: `API_BASE_URL`, `ADMIN_SECRET`.
- Manual dry-run: use the “Run workflow” button (enabled via `workflow_dispatch`).

## Flutter App Usage

### Navigation
- **Home**: Daily overview with meal planning and trackers
- **Weekly Planner**: Plan your meals for the week
- **Markets**: Browse current offers by retailer
- **Rezepte**: Discover recipes based on current offers
- **Profile**: User settings (coming soon)

### Recipe Screen Features
- Filter recipes by retailer (All, REWE, EDEKA, LIDL, ALDI, NETTO)
- Pull-to-refresh to reload recipes
- Modern beige/cream design with ingredient tags
- Responsive layout with smooth animations

## Cleaning & Reset

Reset your development environment:
```bash
./scripts/clean.sh
```

This removes:
- Generated data files (`/data/`)
- Log files (`/logs/`)
- Flutter build artifacts (`/build/`)
- Node.js dependencies (`node_modules/`)
- Lock files (`pubspec.lock`, `package-lock.json`)

## Runbook

- Local dev:
  - `cd server && cp .env.example .env` and set `ADMIN_SECRET`
  - `npm ci && npm run dev`
  - In another terminal: `ADMIN_SECRET=changeme API_BASE_URL=http://localhost:3000 ./scripts/smoke.sh`
  - Flutter: `flutter run --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=DEBUG_ADMIN_SECRET=changeme`
- Vercel Cron: set `ADMIN_SECRET` in Vercel Project Settings → Environment Variables.
- GitHub Actions: set repo secrets `API_BASE_URL`, `ADMIN_SECRET`; manual dry-run via "Run workflow".

## Phase 4 Status ✅

Phase 4 (Real AI recipe generation, SQLite persistence, and automated refresh) is complete:

- ✅ Real AI recipe generation with OpenAI GPT-4o-mini
- ✅ SQLite database with proper migrations and indexing
- ✅ Database adapter pattern (SQLite + memory fallback)
- ✅ POST /admin/refresh-recipes endpoint for AI generation
- ✅ Automated weekly refresh for both offers and recipes
- ✅ Enhanced smoke tests with database verification
- ✅ Updated Vercel Cron and GitHub Actions
- ✅ Environment configuration with .env.example
- ✅ Comprehensive documentation updates

## Features

### AI Recipe Generation
- Uses OpenAI GPT-4o-mini for intelligent recipe suggestions
- Falls back to mock recipes in development or if API key is missing
- Generates 3 recipes per retailer based on current offers
- Validates and sanitizes AI responses

### Database Storage
- SQLite database with proper schema and indexes
- Supports both offers and recipes persistence
- Configurable via `DB=sqlite|memory` environment variable
- Automatic migrations on startup

### Automated Scheduling
- Vercel Cron: Offers refresh at 18:00, Recipes at 18:30 (Sundays)
- GitHub Actions: Both offers and recipes refresh with fallback
- Proper error handling and logging

## Next Steps

The system is now production-ready with:
- Real AI-powered recipe generation
- Persistent SQLite storage
- Automated weekly refresh
- Comprehensive testing and monitoring
