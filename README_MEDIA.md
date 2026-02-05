# Media Architecture & Publishing Pipeline

## Overview

Grocify 2.0 separates **application code** from **media assets** (recipe images, weekly offer PDFs) to enable rapid updates without App Store/Play Store deployment cycles.

- **App Code**: Stored in the GitHub repo (Flutter frontend + backend API)
- **Media Assets**: Generated weekly via automation and published to a static media server
- **Bundled Fallback**: Small sample images and legacy recipes packaged in `assets/` for demo mode

## Media Structure

```
repo/
├── assets/
│   ├── recipe_images/          # Sample bundled images (for demo/fallback only)
│   │   ├── lidl/
│   │   │   ├── R001.png, R002.png, ...
│   │   ├── edeka/
│   │   │   ├── E001.png, E002.png, ...
│   └── prospekte/               # Bundled legacy recipe JSONs
│       ├── lidl_recipes.json
│       ├── edeka_recipes.json
│
├── server/
│   └── media/                   # Generated weekly by CI; served at `/media/*`
│       ├── recipe_images/
│       │   ├── lidl/
│       │   ├── edeka/
│       └── recipes.json         # Updated weekly with fresh recipes
│
└── tools/
    ├── weekly_pro.py            # Generates new recipes + images
    └── upload_media_bundle.py   # Uploads tar.gz to server
```

## Weekly Publishing Workflow

### 1. **Generation** (Sunday 19:00 UTC)

Run via GitHub Actions (`.github/workflows/publish-weekly-media.yml`):

```bash
python3 tools/weekly_pro.py --publish-server
```

**What it does:**
- Fetches latest offers from LIDL/EDEKA APIs or scrapers
- Uses OpenAI Vision to extract food items from PDFs
- Generates recipe descriptions using ChatGPT
- Produces images via Replicate or local fallback
- Outputs to `server/media/` with correct structure

**Environment required:**
- `OPENAI_API_KEY` (OpenAI API key for ChatGPT)
- `API_BASE_URL` (backend URL to write recipes to)
- `ADMIN_SECRET` (authentication for write operations)

### 2. **Upload** (Immediately after generation)

```bash
python3 tools/upload_media_bundle.py \
  --base-url $API_BASE_URL \
  --secret $ADMIN_SECRET
```

**What it does:**
- Tars the `server/media/` directory
- POSTs to backend: `POST /admin/upload-media-tar`
- Backend extracts and serves new images at `/media/recipe_images/<market>/<R###>.png`
- Updates `recipes.json` in the database

### 3. **App Retrieval** (On demand)

When the user opens Discover page or searches:
- App fetches fresh recipes from `$API_BASE_URL/api/recipes`
- Images loaded from `$API_BASE_URL/media/recipe_images/<market>/<R###>.png`
- On Web or if server unavailable: Falls back to bundled `assets/recipe_images/`

---

## For Developers

### Local Testing (without live server)

```bash
# 1. Copy .env.example to .env
cp .env.example .env

# 2. Leave API_BASE_URL empty or set to http://localhost:3000
echo "API_BASE_URL=" >> .env

# 3. Run app in Chrome (uses bundled assets)
flutter run -d chrome

# 4. App will display sample images from assets/recipe_images/
```

### Local Testing (with server)

```bash
# 1. Start backend server
cd server
npm install
node src/index.js
# Server runs on http://localhost:3000

# 2. Set API_BASE_URL in .env
echo "API_BASE_URL=http://localhost:3000" >> .env

# 3. Run app
flutter run -d chrome

# 4. If server has media, app fetches from /media/
```

### Generating Test Media Locally

```bash
# 1. Set up environment
export OPENAI_API_KEY="sk-proj-..."
export API_BASE_URL="http://localhost:3000"
export ADMIN_SECRET="test-secret"

# 2. Run weekly generator (fetches test offers, generates recipes + images)
python3 tools/weekly_pro.py --publish-server

# 3. Media appears in server/media/
ls -la server/media/recipe_images/

# 4. Upload to running server (optional if --publish-server already did it)
python3 tools/upload_media_bundle.py --base-url $API_BASE_URL --secret $ADMIN_SECRET
```

---

## CI/CD Secrets (GitHub Actions)

The workflow `.github/workflows/publish-weekly-media.yml` requires these secrets in GitHub Settings → Secrets:

| Secret | Purpose | Example |
|--------|---------|---------|
| `API_BASE_URL` | Backend API endpoint | `https://api.grocify.example.com` |
| `ADMIN_SECRET` | Auth token for admin endpoints | `your-secret-key-here` |
| `OPENAI_API_KEY` | ChatGPT for recipe generation | `sk-proj-...` |

### Setting Secrets in GitHub

```bash
# Via GitHub CLI
gh secret set API_BASE_URL --body "https://api.grocify.example.com"
gh secret set ADMIN_SECRET --body "your-secret"
gh secret set OPENAI_API_KEY --body "sk-proj-..."

# Or via web UI: Settings → Secrets and variables → Actions → New repository secret
```

---

## Deployment Architecture

```
┌─ GitHub Actions (Weekly CI)
│  ├─ Run: python3 tools/weekly_pro.py --publish-server
│  └─ Run: python3 tools/upload_media_bundle.py
│
└─→ Backend Server (Vercel / VPS / Docker)
   ├─ POST /admin/upload-media-tar
   │   └─ Extracts tar.gz → server/media/
   │
   ├─ GET /media/recipe_images/<market>/<id>.png
   │   └─ Serves images to app/web
   │
   └─ GET /api/recipes
       └─ Serves fresh recipes + image URLs to app
```

---

## Troubleshooting

### App Shows Placeholder Emoji Instead of Images

**Cause**: Server unreachable or image URL not found.

**Fix**:
1. Check `API_BASE_URL` is set and server is running: `curl $API_BASE_URL/media/recipe_images/`
2. Verify images exist: `ls server/media/recipe_images/lidl/`
3. On Web: Ensure `pubspec.yaml` has `- assets/recipe_images/` (fallback)
4. Check browser console for 404 errors

### Weekly Generation Fails

**Cause**: Missing `OPENAI_API_KEY` or backend unreachable.

**Fix**:
1. Verify `OPENAI_API_KEY` is set: `echo $OPENAI_API_KEY`
2. Check backend is running: `curl $API_BASE_URL`
3. Review logs: `cat ~/.github/workflows/logs/` or GitHub Actions UI

### Server Fails to Extract Upload

**Cause**: Corrupted tar file or wrong `ADMIN_SECRET`.

**Fix**:
1. Verify tar file: `tar -tzf server/media_bundle.tar.gz | head`
2. Check `ADMIN_SECRET` matches server: `env | grep ADMIN_SECRET`
3. Review server logs: `docker logs grocify-server` or `pm2 logs`

---

## Next Steps

- [ ] Set up GitHub Actions secrets for your deployment environment
- [ ] Configure backend `.env` with database and API keys
- [ ] Test weekly pipeline in staging first
- [ ] Monitor job runs in GitHub Actions → Workflow runs
- [ ] Set up alerts if publishing fails
