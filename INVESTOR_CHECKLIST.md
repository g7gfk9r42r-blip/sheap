# Investor-Ready Repository Checklist

## Phase 1: Quick Fixes (Today, ~1 hour)

- [x] Created `.env.example` with all required variables
- [x] Verified `.env` is in `.gitignore` (already there)
- [x] Created `ARCHITECTURE.md` – System design for investors
- [x] Created `SECURITY.md` – Security practices & history cleanup guide
- [x] Created `README_MEDIA.md` – Media publishing workflow
- [x] Created `INVESTOR_README.md` – Business pitch & use of funds

### Next Steps (Do This):

```bash
# 1. Add all new docs to git
git add .env.example ARCHITECTURE.md SECURITY.md README_MEDIA.md INVESTOR_README.md

# 2. Commit
git commit -m "docs: Add investor-ready documentation and security guidelines"

# 3. Push
git push origin main
```

---

## Phase 2: History Cleanup (If Needed, ~30 min)

**Only do this if your repo contains committed secrets. Otherwise, skip to Phase 3.**

### Check for Secrets First

```bash
# Search for common secret patterns
grep -r "sk-proj-" . --exclude-dir=.git --exclude-dir=node_modules || echo "✅ No OpenAI keys found"
grep -r "ADMIN_SECRET\s*=" . --exclude-dir=.git --exclude-dir=node_modules || echo "✅ No admin secrets found"
grep -r "-----BEGIN PRIVATE KEY" . --exclude-dir=.git --exclude-dir=node_modules || echo "✅ No private keys found"
```

### If You Found Secrets:

```bash
# 1. Install BFG (macOS)
brew install bfg

# 2. Create a SAFE mirror (doesn't touch your working repo)
cd /tmp
git clone --mirror git@github.com:YOUR_USERNAME/YOUR_REPO.git your_repo.git
cd your_repo.git

# 3. Delete .env files from history
bfg --delete-files .env /tmp/your_repo.git

# 4. Create replacements.txt with patterns
cat > /tmp/replacements.txt << 'EOF'
sk-proj-.*==>***REDACTED***
ADMIN_SECRET=.*==>ADMIN_SECRET=***REDACTED***
API_KEY=.*==>API_KEY=***REDACTED***
EOF

# 5. Replace sensitive strings
bfg --replace-text /tmp/replacements.txt /tmp/your_repo.git

# 6. Finalize cleanup
cd /tmp/your_repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 7. Mirror push (FORCE PUSH - rewrite history!)
git push --mirror git@github.com:YOUR_USERNAME/YOUR_REPO.git --force

# 8. In your working repo: fetch updates
cd ~/dev/AppProjektRoman/roman_app
git fetch --all
git reset --hard origin/main
```

### After History Cleanup:

1. **Rotate ALL secrets** (they're now public in history):
   ```bash
   # New OpenAI key: https://platform.openai.com/account/api-keys
   # New Admin Secret: openssl rand -base64 32
   # New Firebase creds: Download from Firebase Console
   ```

2. **Update GitHub Secrets** (see Phase 3)

3. **Alert your team** that history was rewritten (git pull --rebase required)

---

## Phase 3: Repository Configuration (15 min)

### 3A. Enable GitHub Security Features

```bash
# Using GitHub CLI
gh repo edit YOUR_USERNAME/YOUR_REPO \
  --enable-security-and-analysis \
  --enable-vulnerability-alerts

# Or manually: Settings → Code security and analysis → Enable all
```

### 3B. Set GitHub Repository Secrets

Required for CI/CD to work:

```bash
# Method 1: GitHub CLI (easiest)
gh secret set API_BASE_URL --body "https://api.your-domain.com"
gh secret set ADMIN_SECRET --body "$(openssl rand -base64 32)"
gh secret set OPENAI_API_KEY --body "sk-proj-your-new-key-here"

# Method 2: Web UI
# Go to: Settings → Secrets and variables → Actions → New repository secret
# Add:
#   - API_BASE_URL
#   - ADMIN_SECRET
#   - OPENAI_API_KEY
```

**Verify secrets are set:**

```bash
gh secret list
```

### 3C. Enable Branch Protection

```bash
# Settings → Branches → Add rule

# Rule: "main"
# ✅ Require pull request reviews before merging (1 reviewer)
# ✅ Require status checks to pass (GitHub Actions)
# ✅ Require branches to be up to date before merging
# ✅ Include administrators
```

### 3D. Enable Pre-Commit Hooks (Optional)

Prevents accidental secret commits:

```bash
# 1. Install pre-commit framework
pip install pre-commit

# 2. Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: detect-private-key
      - id: check-env-file
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.1
    hooks:
      - id: gitleaks
EOF

# 3. Install the hook
pre-commit install

# 4. Test it
pre-commit run --all-files
```

---

## Phase 4: Make Repository Investor-Ready (10 min)

### 4A. Update Main README.md

Add to top of `README.md`:

```markdown
# Grocify 2.0 – AI-Powered Grocery Shopping

> ⭐ Interested in investing? See [INVESTOR_README.md](INVESTOR_README.md)

## Quick Links

- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Security & Secrets**: [SECURITY.md](SECURITY.md)
- **Media Publishing**: [README_MEDIA.md](README_MEDIA.md)
- **Local Setup**: See below
```

### 4B. Add Getting Started Section

```markdown
## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Node.js 18+
- Python 3.9+

### Setup (5 minutes)

```bash
# 1. Clone repo
git clone https://github.com/YOUR_ORG/grocify.git
cd grocify

# 2. Copy environment template
cp .env.example .env
# Edit .env with your values (optional for demo)

# 3. Install & run
flutter run -d chrome
```

For backend: See [server/README.md](server/README.md)
```

### 4C. Repository Visibility (Optional)

**For maximum investor confidence, consider:**

```bash
# Option 1: Keep public (transparency)
# → Shows open-source commitment, code quality

# Option 2: Make private (security-first)
# → Add investors to team for access
gh repo edit YOUR_USERNAME/YOUR_REPO --visibility private
```

---

## Phase 5: Verify Everything

Run this checklist:

```bash
# ✅ All new docs in repo?
ls -1 .env.example ARCHITECTURE.md SECURITY.md README_MEDIA.md INVESTOR_README.md

# ✅ .env not committed?
git log --all --full-history -- ".env" | head -5 || echo "✅ .env clean"

# ✅ No secrets in current code?
grep -r "sk-proj-\|ADMIN_SECRET\s*=" lib/ server/src/ || echo "✅ No hardcoded secrets"

# ✅ GitHub Secrets set?
gh secret list | grep -E "API_BASE_URL|ADMIN_SECRET|OPENAI"

# ✅ .gitignore has .env?
grep -q "^\.env$" .gitignore && echo "✅ .env in .gitignore"

# ✅ CI/CD workflow exists?
ls .github/workflows/publish-weekly-media.yml && echo "✅ CI workflow found"
```

---

## Phase 6: Communicate with Investors

### Email Template

Subject: **Grocify 2.0 – Repository & Technical Overview**

```
Hi [Investor],

We've prepared our codebase for evaluation. Here's what you need to know:

📂 **Repository Structure**
- Code: GitHub (link)
- Architecture: ARCHITECTURE.md
- Security: SECURITY.md
- Media Pipeline: README_MEDIA.md

🚀 **Quick Start**
1. Clone: git clone ...
2. Setup: cp .env.example .env
3. Run: flutter run -d chrome

💰 **Business Pitch**
See: INVESTOR_README.md (5-min read)

📊 **Key Metrics**
- Tech Stack: Flutter + Node.js
- Cross-Platform: iOS, Android, Web
- Weekly Automation: CI/CD with GitHub Actions
- Deployment Ready: Vercel / Docker / AWS

🔒 **Security**
- No hardcoded secrets
- GitHub secret scanning enabled
- Secrets rotated regularly
- See SECURITY.md for details

Questions? Let's hop on a call.

Best,
[Your Name]
```

---

## Ongoing Maintenance

### Weekly
- ✅ Monitor GitHub Actions for workflow failures
- ✅ Review new dependencies for security issues

### Monthly
- ✅ Rotate API keys (optional but recommended)
- ✅ Review GitHub security alerts
- ✅ Check disk usage (build/ artifacts)

### Quarterly
- ✅ Update Flutter & dependencies
- ✅ Audit codebase for secrets
- ✅ Review and update ARCHITECTURE.md

---

## Support & Troubleshooting

### CI/CD Fails with "Secret not found"

```bash
# Check GitHub Secrets are set
gh secret list

# Regenerate secret
gh secret set ADMIN_SECRET --body "$(openssl rand -base64 32)"

# Re-run workflow: GitHub Actions UI → Click "Re-run"
```

### Build Fails on macOS

```bash
# Clean everything
flutter clean
cd server && npm ci
cd ios && rm -rf Pods && pod install && cd ..

# Rebuild
flutter run -d chrome
```

### Media Images Not Loading

```bash
# 1. Check server is running
curl http://localhost:3000/api/recipes

# 2. Check media files exist
ls server/media/recipe_images/lidl/

# 3. Check .env has API_BASE_URL set
cat .env | grep API_BASE_URL
```

---

## Questions?

1. **Technical Setup**: Check README.md & ARCHITECTURE.md
2. **Security**: See SECURITY.md
3. **Media Publishing**: See README_MEDIA.md
4. **Business**: See INVESTOR_README.md
5. **Help**: Open an issue on GitHub or email support

---

✅ **Repository is now investor-ready!**

Next: Share with investors & gather feedback.
