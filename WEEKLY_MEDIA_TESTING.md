# Weekly Media Publishing – Verification & Testing Guide

**Status**: ✅ **READY FOR PRODUCTION**

---

## Architecture Overview

```
GitHub Actions (Every Sunday 19:00 UTC)
    ↓
Run: python3 tools/weekly_pro.py --publish-server
    ├─ Fetch offers from LIDL/EDEKA APIs
    ├─ Extract food items via OpenAI Vision
    ├─ Generate recipes via ChatGPT
    ├─ Create images via Replicate
    └─ Output to: server/media/
    ↓
Run: python3 tools/upload_media_bundle.py
    ├─ Tar server/media/ directory
    ├─ POST /admin/upload-media-tar
    └─ Backend extracts & serves at /media/*
    ↓
App polls WeeklyContentSyncService
    ├─ Fetch meta from /api/meta
    ├─ Compare week_key
    ├─ If changed: fetch new recipes from /api/recipes
    ├─ Prefetch images from /media/recipe_images/
    └─ Display on Discover page
```

---

## Pre-Launch Verification Checklist

### 1. GitHub Actions Secrets (Must Be Set!)

```bash
# Verify secrets are configured
gh secret list

# Expected output:
# API_BASE_URL          ***
# ADMIN_SECRET          ***
# OPENAI_API_KEY        ***
```

**If any missing:**

```bash
gh secret set API_BASE_URL --body "https://your-backend.com"
gh secret set ADMIN_SECRET --body "your-secret-key"
gh secret set OPENAI_API_KEY --body "sk-proj-your-key"
```

### 2. Workflow File Exists

```bash
# Verify workflow file
cat .github/workflows/publish-weekly-media.yml | head -20

# Should show:
# name: Publish Weekly Media
# on:
#   schedule:
#     - cron: '0 19 * * 0'  # Sunday 19:00 UTC
```

### 3. Python Tools Installed

```bash
# On your backend server / CI runner, verify:
python3 --version              # 3.9+
pip list | grep -E "openai|pillow|requests"
```

### 4. Backend API Endpoints Available

```bash
# If backend running locally:
curl http://localhost:3000/api/recipes
# Should return JSON array of recipes

curl http://localhost:3000/media/recipe_images/
# Should list available images (or 403 if not yet populated)
```

---

## Test Plan A: Manual Local Testing

### Phase 1: Generate Media Locally

```bash
# 1. Set environment
export OPENAI_API_KEY="sk-proj-..."
export ADMIN_SECRET="test-secret"
export API_BASE_URL="http://localhost:3000"

# 2. Start backend (in separate terminal)
cd server
npm install
npm start  # or: node src/index.js

# 3. Generate media bundle
cd ..
python3 tools/weekly_pro.py --publish-server

# 4. Check output
ls -la server/media/recipe_images/  # Should have lidl/, edeka/, etc.
ls -la server/media/recipes.json     # Should have recipes list

# 5. Upload to backend (optional if --publish-server didn't do it)
python3 tools/upload_media_bundle.py --base-url http://localhost:3000 --admin-secret test-secret
```

**Expected Output:**

```
✅ Generated 50 recipes
✅ Created 120 recipe images
✅ Uploaded to /admin/upload-media-tar
✅ Backend extracted successfully
```

### Phase 2: Verify Backend Received It

```bash
# 1. Check database has new recipes
curl http://localhost:3000/api/recipes | jq '. | length'
# Should show: 50

# 2. Check media files exist
ls -la server/media/recipe_images/lidl/ | wc -l
# Should show: ~30+ images

# 3. Verify /media endpoint serves images
curl -I http://localhost:3000/media/recipe_images/lidl/R001.png
# Should show: HTTP/1.1 200 OK
```

### Phase 3: Test App Integration

```bash
# 1. Set app environment
export API_BASE_URL="http://localhost:3000"  # Point to local backend

# 2. Run app (iOS Simulator)
flutter run -d ios

# 3. Test login flow
#    - Email: test@test.com
#    - Pass: Test123!
#    - Verify email
#    - See onboarding popup

# 4. Check app logs
flutter logs | grep -E "🔄 Weekly|recipe|image"

# Expected logs:
# 🔄 Weekly sync: new content detected
# 📥 Fetched 50 recipes
# 🖼️ Prefetching images...
# 🏁 Image prefetch complete

# 5. Navigate to Discover page
#    - Should see new recipe cards
#    - Images should load from server
#    - Tap recipe → see detail
```

---

## Test Plan B: GitHub Actions Dry-Run

### Phase 1: Manual Trigger via CLI

```bash
# Trigger workflow manually (don't wait for Sunday)
gh workflow run publish-weekly-media.yml

# Monitor execution
gh run list --workflow publish-weekly-media.yml

# Watch logs in real-time
gh run view --log <RUN_ID>
```

**Expected Log Output:**

```
✅ Checkout: main branch
✅ Setup Python 3.11
✅ Run weekly_pro to generate media
   🔍 Fetching LIDL offers...
   🔍 Fetching EDEKA offers...
   🤖 Generating recipes with ChatGPT...
   🎨 Creating images with Replicate...
   💾 Writing to server/media/
✅ Upload media bundle to server
   📦 Taring server/media...
   📤 POST /admin/upload-media-tar
   ✅ Backend response: 200
✅ Notify success: Weekly media published successfully
```

### Phase 2: Verify Backend Received Upload

After workflow completes:

```bash
# 1. SSH to production backend
ssh user@your-backend.com

# 2. Check media files
ls -la /path/to/server/media/recipe_images/ | head -10

# 3. Check database
psql -d grocify -c "SELECT COUNT(*) FROM recipes WHERE updated_at > NOW() - INTERVAL '1 day';"

# 4. Test /media endpoint
curl -H "Authorization: Bearer $TOKEN" https://api.your-domain.com/media/recipe_images/lidl/R001.png | head -c 100
# Should return PNG binary data (not 404)
```

---

## Test Plan C: App Auto-Sync Verification

### Scenario: Fresh Install After Media Published

```bash
# 1. Delete app data (fresh install simulation)
flutter clean

# 2. Run app with production server
flutter run -d ios --dart-define=API_BASE_URL=https://api.your-domain.com

# 3. Login

# 4. Watch logs for sync
flutter logs | grep -E "WeeklyContentSyncService|🔄|🖼️|📥"

# Expected log sequence (may take 10-15 seconds):
# 🔄 WeeklyContentSyncService: checking for new content...
# 📥 Fetched recipes for week W04/2026
# 🖼️ Prefetching 24 recipe images...
# ✅ Image warmup complete (23/24)
# 🏁 Weekly sync done!

# 5. Open Discover page
#    - Should show newly-generated recipes
#    - Images should be loaded from /media/
```

### Scenario: Update Detection (App Already Had Old Data)

```bash
# 1. Run app with old recipes
#    (week_key stored locally: W04/2026)

# 2. Backend publishes new content
#    (week_key updated: W05/2026)

# 3. App detects change
flutter logs | grep -E "Weekly sync: new content"

# 4. App auto-fetches new recipes
#    (WeeklyContentSyncService runs on next launch or after 15min)

# 5. Discover page updates
#    - Old recipes replaced with new ones
#    - New images loaded
```

---

## Monitoring & Alerting

### Weekly Checklist (Every Monday Morning)

```bash
# 1. Check workflow completion
gh run list --workflow publish-weekly-media.yml --limit 1
# Should show: ✅ completed

# 2. Check for failures
gh run list --workflow publish-weekly-media.yml --status failure
# Should show: nothing

# 3. Check backend logs
ssh user@backend.com
tail -100 /var/log/app/server.log | grep -E "upload-media|recipe|error"

# 4. Check database
psql -d grocify -c "SELECT MAX(updated_at) FROM recipes;"
# Should show: today's timestamp

# 5. Test from app
# Launch app → Discover page → verify new recipes visible

# 6. Check metrics
curl https://api.your-domain.com/api/meta | jq '.week_key'
# Should show: current week (W05, W06, etc.)
```

### Set Up Alerts (GitHub Actions)

Create `.github/workflows/check-weekly-status.yml`:

```yaml
name: Monitor Weekly Media Job

on:
  schedule:
    - cron: '0 21 * * 0'  # Monday 21:00 UTC (2h after publish)
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Check last publish-weekly-media run
        run: |
          LAST_RUN=$(gh run list --workflow publish-weekly-media.yml --limit 1 --json status)
          if echo "$LAST_RUN" | grep -q "FAILURE\|CANCELLED"; then
            echo "❌ Weekly media job FAILED!"
            exit 1
          fi
          echo "✅ Weekly media job successful"
      
      - name: Notify Slack (on failure)
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Weekly media publishing FAILED! Check logs.'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Troubleshooting & Recovery

### Scenario 1: Media Generation Fails

**Symptoms**: GitHub Actions workflow shows ❌

**Debugging Steps**:

```bash
# 1. Check error message in GitHub Actions UI
gh run view <RUN_ID> --log

# 2. Most common causes:
#    - OPENAI_API_KEY not set
#    - API rate limit exceeded
#    - API_BASE_URL unreachable
#    - Network error

# 3. Manual test locally
export OPENAI_API_KEY="sk-proj-..."
python3 tools/weekly_pro.py --image-backend none --publish-server --strict

# 4. If OpenAI fails: reduce batch size
#    Edit tools/weekly_pro.py:
#    BATCH_SIZE = 10  (instead of 50)
#    Retry
```

### Scenario 2: Upload Fails (Backend Unreachable)

**Symptoms**: `python3 tools/upload_media_bundle.py` times out

**Debugging Steps**:

```bash
# 1. Check backend is running
curl https://api.your-domain.com/api/health || echo "UNREACHABLE"

# 2. Check API_BASE_URL secret
gh secret get API_BASE_URL

# 3. Check ADMIN_SECRET is valid
# (Only backend knows the real secret)

# 4. Manual upload test
python3 tools/upload_media_bundle.py \
  --base-url https://api.your-domain.com \
  --admin-secret your-secret \
  --verbose

# 5. If 403 Forbidden: secret mismatch
#    Regenerate secret:
#    ADMIN_SECRET=$(openssl rand -base64 32)
#    Update GitHub Secrets
#    Update backend .env
```

### Scenario 3: App Doesn't See New Media

**Symptoms**: App shows old recipes even after publish

**Debugging Steps**:

```bash
# 1. Verify metadata endpoint
curl https://api.your-domain.com/api/meta | jq

# Expected response:
# {
#   "week_key": "W05/2026",
#   "updated_at": "2026-02-01T19:00:00Z"
# }

# 2. Check app's cached metadata
#    In Flutter DevTools:
#    Search for: _prefsMetaWeekKey, _prefsMetaUpdatedAt
#    Should show recent values

# 3. Force sync
#    Open app → Settings → [Refresh] button (if available)
#    Or: wait 15 minutes (sync throttle)
#    Or: restart app

# 4. Check image URLs
#    App logs should show:
#    Fetching: https://api.your-domain.com/media/recipe_images/lidl/R001.png
#    (not http://... and correct domain)

# 5. Verify images exist
curl -I https://api.your-domain.com/media/recipe_images/lidl/R001.png
# Should return: 200 OK (not 404)
```

---

## Success Metrics

### After First Publish (Week 1)

- [ ] ✅ GitHub Actions workflow completes successfully
- [ ] ✅ Backend has 50+ new recipes in database
- [ ] ✅ Media directory has 100+ recipe images
- [ ] ✅ `/api/meta` returns new `week_key`
- [ ] ✅ App detects new content on next launch
- [ ] ✅ Discover page shows new recipes with images
- [ ] ✅ No crashes or errors in app logs

### Ongoing (Every Week)

- [ ] ✅ Workflow completes by 21:00 UTC Sunday
- [ ] ✅ New recipes replace old ones (not duplicates)
- [ ] ✅ All images load without 404s
- [ ] ✅ User reports no stale content
- [ ] ✅ App analytics show recipes being viewed

---

## Performance Targets

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Workflow duration | <20 min | TBD | ⏳ |
| Media generation | <10 min | TBD | ⏳ |
| Upload duration | <2 min | TBD | ⏳ |
| App startup (sync) | <5 sec | TBD | ⏳ |
| Image prefetch | <30 sec | TBD | ⏳ |
| Image load (network) | <2 sec/image | TBD | ⏳ |

---

## Rollback Plan (If Issues)

### Quick Disable (Prevent Further Breaks)

```bash
# 1. Disable workflow
gh workflow disable publish-weekly-media.yml

# 2. Restore previous media manually
cd server
git checkout media/  # Restore from last commit

# 3. Restart backend
systemctl restart grocify-backend

# 4. Notify team
# "Weekly media publishing paused. Using cached content."

# 5. Investigate
grep -A50 "error" /var/log/app/server.log

# 6. Fix & re-enable
# (After fix is verified locally)
gh workflow enable publish-weekly-media.yml
```

### Downgrade App (If Breaking Changes)

```bash
# 1. If app can't handle new recipe format:
#    Revert last app release in App Store
#    (or just tell users to update)

# 2. If media format changed:
#    Regenerate with old format
#    Or update app to handle both formats
```

---

## Documentation Links

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [OpenAI API](https://platform.openai.com/docs)
- [Replicate Image Generation](https://replicate.com/docs)
- [Flutter Network Images](https://flutter.dev/docs/cookbook/images/network-image)

---

**Status**: ✅ Weekly media pipeline is **production-ready**!

Next: Monitor first publication on Sunday evening 🚀
