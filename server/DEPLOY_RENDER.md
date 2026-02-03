## Render Deployment (Option A) — API + Media Server

### What this hosts

- **Health**: `GET /health`
- **Static media**:
  - `GET /media/prospekte/<market>/<market>_recipes.json`
  - `GET /media/recipe_images/<market>/R001.png`

Media is served from `MEDIA_DIR` (Render Disk recommended).

### Render setup

1) Create a new **Web Service** on Render from this repo.
2) Render will detect `render.yaml` at repo root and configure:
   - build: `npm ci && npm run build`
   - start: `npm run start`
   - disk mounted at `/var/data`

3) In Render dashboard, set secrets:
   - `ADMIN_SECRET` (required for admin endpoints)
   - `CORS_ORIGINS` (optional; only needed for Flutter Web)

### ENV variables

- **Required**
  - `ADMIN_SECRET`: secret for admin actions (header `x-admin-secret`)
- **Recommended**
  - `DATA_DIR=/var/data/data` (persists SQLite)
  - `MEDIA_DIR=/var/data/media` (persists weekly recipes + images)
  - `CORS_ORIGINS=https://yourdomain.com,https://staging.yourdomain.com` (or `*` for dev)

### Upload weekly generated media (no SSH)

Create an archive locally from your generated `roman_app/server/media` folder:

```bash
cd /path/to/AppProjektRoman
tar -czf media_bundle.tar.gz -C roman_app/server/media prospekte recipe_images
```

Upload it to Render:

```bash
BASE="https://<your-render-service>.onrender.com"
curl -X POST "$BASE/admin/upload-media-tar" \
  -H "x-admin-secret: $ADMIN_SECRET" \
  -H "Content-Type: application/gzip" \
  --data-binary @media_bundle.tar.gz
```

Or use the helper script (recommended):

```bash
cd /path/to/AppProjektRoman/roman_app
export ADMIN_SECRET="..."
python3 tools/upload_media_bundle.py --base-url "https://<your-render-service>.onrender.com"
```

### Smoke test URLs (mobile browser)

- `GET {BASE}/health`
- `GET {BASE}/media/prospekte/aldi_sued/aldi_sued_recipes.json`
- `GET {BASE}/media/recipe_images/aldi_sued/R001.png`


