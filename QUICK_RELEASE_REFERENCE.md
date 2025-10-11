# Quick Release Reference

## TL;DR

```bash
npm run release:patch   # Bug fixes (1.0.0 → 1.0.1)
npm run release:minor   # New features (1.0.0 → 1.1.0)
npm run release:major   # Breaking changes (1.0.0 → 2.0.0)
```

Then:
```bash
git push --follow-tags
```

Done! Version appears at bottom of Rules page.

---

## What Each Command Does

| Command | Changes | Example | When to Use |
|---------|---------|---------|-------------|
| `release:patch` | Bug fixes | 1.0.0 → 1.0.1 | Fixed Brave wallet error |
| `release:minor` | New features | 1.0.0 → 1.1.0 | Added leaderboard page |
| `release:major` | Breaking changes | 1.0.0 → 2.0.0 | New contract deployment |

## Full Workflow

```bash
# 1. Make your changes and commit them normally
git add .
git commit -m "fix: mobile Brave wallet issue"

# 2. Run release command
npm run release:patch

# 3. Push everything
git push --follow-tags

# 4. Deploy dist/ folder to pepedawn.art
```

## Check Current Version

```bash
cat package.json | grep version
# or visit pepedawn.art/rules.html (bottom of page)
```

