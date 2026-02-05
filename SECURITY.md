# Security & Secret Management

## Overview

This document outlines best practices for securing this repository and removing any previously-committed secrets from the git history.

---

## ⚠️ If Secrets Are Currently in Git History

If you've committed `.env` files or API keys in the past, follow this procedure to clean them up:

### Step 1: Install BFG Repo-Cleaner

```bash
# macOS
brew install bfg

# Linux
wget https://repo1.maven.org/maven2/com/newrelic/agent/java/newrelic-agent/7.0.0/newrelic-agent-7.0.0.jar
mv newrelic-agent-7.0.0.jar bfg.jar
java -jar bfg.jar

# Or use git-filter-repo (alternative)
pip install git-filter-repo
```

### Step 2: Create a Mirror Clone (SAFE - doesn't affect your working repo)

```bash
cd /tmp
git clone --mirror git@github.com:YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO.git
```

### Step 3: Delete `.env` Files from History

```bash
bfg --delete-files .env /tmp/YOUR_REPO.git
```

### Step 4: Remove Sensitive Strings

Create a file `replacements.txt` with patterns to redact (one per line):

```
sk-proj-.*==>***REDACTED***
ADMIN_SECRET=.*==>ADMIN_SECRET=***REDACTED***
OPENAI_API_KEY=.*==>OPENAI_API_KEY=***REDACTED***
```

Run the replacement:

```bash
bfg --replace-text /tmp/replacements.txt /tmp/YOUR_REPO.git
```

### Step 5: Finish the Cleanup

```bash
cd /tmp/YOUR_REPO.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### Step 6: Force-Push the Cleaned History

⚠️ **WARNING**: This will rewrite your repository history. Make sure all contributors are aware!

```bash
# Delete the mirror backup (we're confident it's clean)
cd /tmp/YOUR_REPO.git
git push --mirror git@github.com:YOUR_USERNAME/YOUR_REPO.git --force

# Or push to your working repo
cd ~/dev/AppProjektRoman/roman_app
git push --force --all
git push --force --tags
```

### Step 7: Rotate All Secrets

Once history is cleaned, rotate all secrets:

1. **OpenAI API Key**: https://platform.openai.com/account/api-keys → Delete old key → Create new key
2. **Admin Secret**: Generate a new strong random string (use `openssl rand -base64 32`)
3. **Firebase Credentials**: Re-download from Firebase Console
4. **Database Credentials**: Update in your backend `.env`

### Step 8: Add Secrets to GitHub Actions

```bash
gh secret set OPENAI_API_KEY --body "sk-proj-your-new-key"
gh secret set ADMIN_SECRET --body "your-new-secret"
gh secret set API_BASE_URL --body "https://your-api-endpoint.com"
```

---

## ✅ Preventing Future Leaks

### 1. Use `.env.example` (Already in Repo)

- Commit `.env.example` with placeholder values
- Never commit `.env` (already in `.gitignore`)
- Document all required env vars in `.env.example`

### 2. Enable GitHub Secret Scanning

```bash
# Enable via GitHub CLI
gh repo edit YOUR_USERNAME/YOUR_REPO --enable-security-and-analysis

# Or: Settings → Code security and analysis → Enable GitHub secret scanning
```

### 3. Use Pre-Commit Hooks (Optional but Recommended)

Install pre-commit framework:

```bash
pip install pre-commit
```

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: detect-private-key
      - id: detect-aws-credentials
      - id: check-env-file
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.1
    hooks:
      - id: gitleaks
```

Install the hook:

```bash
pre-commit install
```

### 4. Branch Protection Rules

In GitHub: Settings → Branches → Branch protection rules

Enable:
- ✅ Require status checks to pass before merging
- ✅ Dismiss stale pull request approvals
- ✅ Require code reviews before merge (minimum 1)
- ✅ Restrict who can push (optional)

---

## Repository Access Control

### Make Repo Private (For Sensitive Development)

```bash
gh repo edit YOUR_USERNAME/YOUR_REPO --visibility private
```

### Or Keep Public but Restrict Secrets

If public, never commit:
- ✅ Any `.env` files
- ✅ Private keys (`.pem`, `.jks`, `.p12`)
- ✅ Firebase service account JSON
- ✅ OAuth tokens or API keys
- ✅ Database passwords
- ✅ Certificates

---

## Deployment Security (CI/CD)

### GitHub Actions Best Practices

In `.github/workflows/publish-weekly-media.yml`:

```yaml
name: Publish Weekly Media

on:
  schedule:
    - cron: '0 19 * * 0'  # Sunday 19:00 UTC

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: production  # Use GitHub Environments for extra protection
    permissions:
      contents: read        # Minimum required permissions
    steps:
      - uses: actions/checkout@v3
      - name: Publish Media
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
          ADMIN_SECRET: ${{ secrets.ADMIN_SECRET }}
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          python3 tools/weekly_pro.py --publish-server
          python3 tools/upload_media_bundle.py --base-url $API_BASE_URL --secret $ADMIN_SECRET
```

**Key points:**
- Use `${{ secrets.VARIABLE }}` (not `env:` directly)
- Set `environment: production` to require approvals (optional)
- Limit `permissions` to only what's needed
- Never log secrets: `set +x` before using them
- Use GitHub's built-in secret masking (automatic)

### Server-Side Security

```bash
# Backend (.env)
NODE_ENV=production
DATABASE_URL=postgresql://user:password@db-host:5432/grocify  # Use strong password
ADMIN_SECRET=$(openssl rand -base64 32)  # Generate strong secret
OPENAI_API_KEY=sk-proj-...                # Use dedicated API key
JWT_SECRET=$(openssl rand -base64 32)     # For token signing
```

---

## Audit & Monitoring

### Check for Secrets in Current Repo

```bash
# Using gitleaks
gitleaks detect --source . -v

# Using git-secrets
git secrets --scan

# Manual check
grep -r "sk-proj-\|-----BEGIN\|PRIVATE\|SECRET" . --exclude-dir=.git --exclude-dir=node_modules
```

### Rotate Secrets Regularly

- **API Keys**: Monthly or quarterly
- **Admin Secrets**: After any unauthorized access suspected
- **Database Passwords**: Quarterly
- **Certificates**: Before expiration

### Monitor CI/CD Logs

- GitHub Actions: Check "Summary" for any exposed values
- Set up alerts for failed deployments
- Review failed job logs to ensure no secrets are leaked

---

## Compliance Checklists

### ✅ Before Making Repo Public

- [ ] No `.env` files committed
- [ ] No `.pem` or `.jks` files committed
- [ ] No API keys in code comments
- [ ] `.env.example` exists with placeholders
- [ ] `.gitignore` includes `.env`, `*.pem`, `*.jks`, `*.p12`
- [ ] GitHub secret scanning enabled
- [ ] Pre-commit hooks configured (optional)
- [ ] Branch protection rules set
- [ ] All secrets rotated

### ✅ Before Production Deployment

- [ ] All environment variables set in GitHub Secrets
- [ ] Database credentials use strong passwords (min 32 chars)
- [ ] API keys are production-grade (not sandbox/test keys)
- [ ] Admin secret is cryptographically secure
- [ ] Firebase credentials are from production project
- [ ] CI/CD pipeline tested in staging first
- [ ] Monitoring and alerting configured
- [ ] Backup and disaster recovery plan in place

---

## Contacts & Resources

- **GitHub Security**: https://docs.github.com/en/code-security
- **BFG Repo-Cleaner**: https://rtyley.github.io/bfg-repo-cleaner/
- **git-filter-repo**: https://github.com/newren/git-filter-repo
- **Gitleaks**: https://github.com/gitleaks/gitleaks
- **Pre-commit Hooks**: https://pre-commit.com/

---

## Questions?

If you discover a security vulnerability, **do not** open a public issue. Instead:
1. Email your security contact privately
2. Or use GitHub's "Report a security vulnerability" feature (Settings → Security)
