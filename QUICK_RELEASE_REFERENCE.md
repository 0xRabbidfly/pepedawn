# Quick Release Reference

## TL;DR

```bash
npm run release:patch     # Bug fixes (1.0.0 → 1.0.1)
npm run release:minor     # New features (1.0.0 → 1.1.0)
npm run release:major     # Breaking changes (1.0.0 → 2.0.0)
npm run release:frontend  # Frontend-only changes (skips contract build)
```

Then:
```bash
npm run build           # Rebuild frontend with new version
git push --follow-tags  # Push code + tags together
```

Done! Version appears at bottom of Rules page.

---

## What Each Command Does

| Command | Changes | Example | When to Use |
|---------|---------|---------|-------------|
| `release:patch` | Bug fixes | 1.0.0 → 1.0.1 | Fixed Brave wallet error |
| `release:minor` | New features | 1.0.0 → 1.1.0 | Added leaderboard page |
| `release:major` | Breaking changes | 1.0.0 → 2.0.0 | New contract deployment |
| `release:frontend` | Frontend-only | 1.0.0 → 1.0.1 | UI tweaks, CSS fixes, JS updates ⚡ |

## Full Workflow

### For Frontend-Only Changes (Fast):
```bash
# 1. Make your changes and commit them normally
git add .
git commit -m "fix: mobile Brave wallet issue"

# 2. Run frontend-only release (skips contract builds!)
npm run release:frontend

# 3. Build frontend with new version number
npm run build

# 4. Push code and tags together
git push --follow-tags

# 5. Deploy dist/ folder to pepedawn.art
```

### For Contract Changes (Full):
```bash
# 1. Make your changes and commit them normally
git add .
git commit -m "feat: add new betting feature"

# 2. Run full release command (includes contract version)
npm run release:minor

# 3. Build frontend with new version number
npm run build

# 4. Push code and tags together
git push --follow-tags

# 5. Deploy dist/ folder to pepedawn.art
```

## What `git push --follow-tags` Does

This single command does TWO things:
1. **Pushes your commits** (like `git push origin main`)
2. **Pushes version tags** (like `git push origin v0.3.1`)

### Without `--follow-tags`:
```bash
git push origin main        # Pushes commits
git push origin v0.3.1      # Pushes tag separately (annoying!)
```

### With `--follow-tags`:
```bash
git push --follow-tags      # Pushes both at once! 🎉
```

**Note:** It only pushes **annotated tags** (created with `git tag -a`), which is exactly what the bump-version script creates. Lightweight tags are ignored.

## Check Current Version

```bash
cat package.json | grep version
# or visit pepedawn.art/rules.html (bottom of page)
```

