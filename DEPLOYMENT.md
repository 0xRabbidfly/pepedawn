# GitHub Actions Deployment Pipeline

This repository includes an automated CI/CD pipeline that builds and deploys the pepedawn frontend to pepedawn.art.

## 🚀 Pipeline Overview

The pipeline automatically:
1. **Lints** JavaScript code using ESLint
2. **Type-checks** TypeScript code
3. **Builds** the Vite multi-page application
4. **Deploys** to pepedawn.art via FTP (main/master branch only)

## 📋 Prerequisites

### GitHub Repository Secrets
Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `FTP_SERVER`: Your FTP hostname (e.g., `ftp.pepedawn.art`)
- `FTP_USERNAME`: Your FTP username
- `FTP_PASSWORD`: Your FTP password

### Local Development
```bash
cd frontend
npm install
```

## 🔧 Available Scripts

### Development
```bash
npm run dev          # Start development server
npm run preview      # Preview production build locally
```

### Quality Assurance
```bash
npm run lint         # Lint JavaScript files
npm run type-check   # TypeScript type checking
npm run build        # Build for production
```

### Deployment Testing
```bash
npm run deploy:test  # Build and test deployment locally
npm run deploy:prod  # Build for production deployment
```

## 🏗️ Build Process

The build process creates a `dist/` directory with:
- **Multi-page HTML files**: `index.html`, `main.html`, `rules.html`
- **Optimized assets**: Minified JS/CSS bundles
- **Static assets**: Images, icons, and other resources

### File Structure After Build
```
frontend/dist/
├── index.html           # Title page
├── main.html            # Betting interface
├── rules.html           # Rules page
├── vite.svg            # Static assets
└── assets/             # Optimized bundles
    ├── index-*.js      # Main JavaScript bundle
    └── index-*.css     # Main CSS bundle
```

## 🚀 Deployment Process

### Automatic Deployment
- **Trigger**: Push to `main` or `master` branch
- **Process**: Build → Validate → Deploy via FTP
- **Target**: Root directory of pepedawn.art

### Manual Deployment
1. Build the project: `npm run build`
2. Upload contents of `frontend/dist/` to your web server
3. Ensure all files are uploaded to the root directory

## 🔍 Pipeline Steps

### 1. Code Quality
- **ESLint**: Checks JavaScript code quality
- **TypeScript**: Validates type safety
- **Build**: Compiles and optimizes assets

### 2. Validation
- Verifies build output exists
- Checks file structure
- Ensures all pages are generated

### 3. Deployment
- Uses FTP-Deploy-Action for secure deployment
- Excludes development files and source code
- Includes only production-ready assets

## 🛠️ Customization

### Excluded Files
The deployment excludes these file types:
- Development files (`.env`, `package.json`, `tsconfig.json`)
- Source code (`src/` directory)
- Git files (`.git*`)
- Node modules
- Development artifacts

### Build Configuration
Modify `frontend/vite.config.js` to:
- Add new pages to the multi-page build
- Configure build optimizations
- Adjust asset handling

### Linting Rules
Update `frontend/.eslintrc.json` to:
- Add custom linting rules
- Configure environment settings
- Modify code style preferences

## 🐛 Troubleshooting

### Common Issues

**Build Fails**
- Check TypeScript errors: `npm run type-check`
- Verify all imports are correct
- Ensure all dependencies are installed

**Linting Errors**
- Run `npm run lint` to see specific issues
- Fix code style violations
- Update ESLint configuration if needed

**Deployment Fails**
- Verify FTP credentials in GitHub Secrets
- Check FTP server status
- Ensure sufficient disk space on server

**Missing Files After Deployment**
- Check FTP permissions
- Verify file upload completed
- Review deployment logs in GitHub Actions

### Debug Commands
```bash
# Test build locally
npm run build && ls -la dist/

# Test deployment process
npm run deploy:test

# Check linting issues
npm run lint

# Verify TypeScript
npm run type-check
```

## 📊 Monitoring

### GitHub Actions
- View pipeline status in the Actions tab
- Check build logs for errors
- Monitor deployment success/failure

### Production Site
- Verify all pages load correctly
- Test functionality after deployment
- Check browser console for errors

## 🔐 Security Notes

- **Never commit** FTP credentials to the repository
- **Use GitHub Secrets** for all sensitive data
- **FTP over TLS** is used for secure connections
- **Environment variables** are for local testing only

## 📈 Performance

The pipeline is optimized for:
- **Fast builds**: Cached dependencies and parallel processing
- **Minimal uploads**: Only changed files are deployed
- **Secure deployment**: Encrypted FTP connections
- **Error handling**: Comprehensive validation and rollback

## 🤝 Contributing

1. Make changes to the codebase
2. Test locally: `npm run deploy:test`
3. Push to a feature branch
4. Create a pull request
5. Merge to main branch triggers automatic deployment

---

For questions or issues with the deployment pipeline, check the GitHub Actions logs or create an issue in the repository.
