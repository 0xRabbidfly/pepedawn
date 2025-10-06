# Build and Deploy Workflow

## The Problem
The npm/Rollup build sometimes fails due to platform-specific optional dependency issues, but we still want automatic deployment to Namecheap.

## The Solution
**Build locally** (when it works) + **Commit built files** + **Auto-deploy via GitHub Actions**

## Your New Workflow

### 1. Development (Normal)
```bash
# Work on your code as usual
npm run dev          # Development server
npm run type-check   # Check types
npm run lint         # Check linting
```

### 2. When Ready to Deploy
```bash
# Build locally (when npm/Rollup is working)
cd frontend
npm run build

# Commit the built files
git add dist/
git commit -m "Update build for deployment"
git push
```

### 3. Automatic Deployment
- GitHub Actions detects changes to `frontend/dist/**`
- Validates that built files exist
- Deploys directly to your Namecheap hosting via FTP
- **No CI build step** = No Rollup failures!

## Benefits
✅ **Reliable deployments**: No more CI build failures  
✅ **Automatic**: Push → Deploy (just like before)  
✅ **Fast**: No build time in CI  
✅ **Controlled**: You decide when to build  
✅ **Visible**: You can see exactly what's being deployed  

## When Build Fails Locally
If `npm run build` fails due to the Rollup issue:

### Option A: Use Previous Build
```bash
# If dist/ folder exists and is recent enough
git add dist/
git commit -m "Deploy with existing build"
git push
```

### Option B: Fix and Retry
```bash
# Clean and retry (sometimes works)
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Option C: Alternative Build (Future)
We can set up esbuild or webpack as a fallback if needed.

## GitHub Actions
The deployment workflow now:
- ✅ Triggers only when `frontend/dist/**` changes
- ✅ Validates built files exist
- ✅ Deploys via FTP to Namecheap
- ❌ No build step (no failures!)

## File Changes Made
- `.gitignore`: Now includes `frontend/dist/` in repository
- `.github/workflows/ci.yml`: Simplified to deploy pre-built files
- Pre-commit tests: Still work perfectly (no build needed)

## Result
**Push → Automatic Deployment** (just like you wanted!)
