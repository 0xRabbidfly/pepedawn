# CSS Quick Reference - Where to Find Things

This guide helps you quickly locate styles in the new organized structure.

---

## 📁 Directory Structure

```
frontend/src/styles/
├── main.css                    ← START HERE (import hub)
├── 1-foundations/              ← Design tokens & base
│   ├── variables.css           ← Colors, spacing, typography
│   ├── reset.css               ← CSS reset & body
│   └── typography.css          ← Headings & text
├── 2-layout/                   ← Page structure
│   └── header.css              ← Header & navigation
├── 3-components/               ← Reusable components
│   ├── animations.css          ← ALL animations
│   ├── buttons.css             ← ALL buttons
│   ├── cards.css               ← Ticket/prize cards
│   ├── forms.css               ← Inputs, textareas
│   ├── sections.css            ← Page sections
│   └── status-badges.css       ← Status indicators
├── 4-pages/                    ← Page-specific styles
│   ├── home.css                ← Title/landing page
│   └── leaderboard.css         ← Leaderboard & winners
└── 5-utilities/                ← Helpers & overrides
    └── responsive.css          ← ALL MOBILE STYLES
```

---

## 🔍 Where to Find Specific Styles

### Colors & Variables
**File**: `1-foundations/variables.css`
- Primary green: `--primary-color`
- Background: `--background-color`
- Spacing: `--spacing-xs` to `--spacing-xl`
- Font sizes: `--font-size-xs` to `--font-size-3xl`

### Buttons
**File**: `3-components/buttons.css`
- Connect Wallet button: `#connect-wallet`
- Buy Tickets button: `.btn-buy-tickets`
- Submit Proof button: `#submit-proof`
- Claim button: `.claim-btn`
- Base button: `.btn`, `.btn-primary`, `.btn-secondary`

### Ticket Cards
**File**: `3-components/cards.css`
- Ticket option card: `.ticket-option-card`
- Ticket visuals: `.ticket-single`, `.ticket-stack`, `.ticket-bundle`
- Ticket info: `.ticket-label`, `.ticket-price`, `.ticket-discount`
- Prize cards: `.prize-card`
- Summary cards: `.summary-card`

### Navigation
**File**: `2-layout/header.css`
- Header: `header`
- Hamburger menu: `.hamburger-menu`
- Navigation: `.main-nav`
- Active link: `.main-nav a.active`

### Round Status
**File**: `3-components/status-badges.css`
- Status items: `.status-item`
- Active phases: `.open-phase.active`, `.drawing-phase.active`
- Merkle badge: `.merkle-badge`
- Dispenser: `.ticket-graphic`, `.ticket-icon`

### Forms & Inputs
**File**: `3-components/forms.css`
- Proof form: `#proof-form`
- Proof input: `#proof-input`
- Proof status: `#proof-status`
- Round selector: `.round-selector`

### Sections
**File**: `3-components/sections.css`
- Wallet section: `#wallet-section`
- Round status: `#round-status`
- Betting section: `#betting-section`
- Ticket office: `.ticket-office`
- User stats: `#user-stats`

### Animations
**File**: `3-components/animations.css`
- Pulse animations: `@keyframes pulse`, `pulse-glow`, etc.
- Bounce: `@keyframes bounce`
- Float: `@keyframes float`
- Slide in: `@keyframes slideIn`
- Card energize: `@keyframes card-energize`

### Mobile Styles
**File**: `5-utilities/responsive.css`
- **ALL mobile styles in ONE place!**
- Hamburger menu mobile: `@media (max-width: 768px)`
- Mobile ticket layout
- Mobile slideout
- Mobile navigation
- Mobile responsive everything!

### Home/Title Page
**File**: `4-pages/home.css`
- Title page: `.title-page`
- Title container: `.title-container`
- Title logo: `.title-logo`
- GIF overlay: `.title-gif-fullscreen`

### Leaderboard
**File**: `4-pages/leaderboard.css`
- Leaderboard table: `.leaderboard-header`, `.leaderboard-entry`
- Winners podium: `.winners-podium`
- Podium tiers: `.tier-1`, `.tier-2`, `.tier-3`

---

## 🎨 How to Make Common Changes

### Change Primary Color
**File**: `1-foundations/variables.css`
```css
--primary-color: #4CAF50;  /* Change this! */
```

### Adjust Spacing
**File**: `1-foundations/variables.css`
```css
--spacing-md: 1rem;        /* Adjust spacing scale */
```

### Modify Button Style
**File**: `3-components/buttons.css`
```css
.btn-primary {
  background-color: var(--primary-color);
  /* Edit here */
}
```

### Fix Mobile Layout
**File**: `5-utilities/responsive.css`
```css
@media (max-width: 768px) {
  /* ALL mobile fixes go here! */
}
```

### Add New Animation
**File**: `3-components/animations.css`
```css
@keyframes myAnimation {
  /* Add animation here */
}
```

---

## 📝 Import Order (Important!)

The CSS files are imported in this order in `main.css`:
```
1. Foundations (variables first!)
2. Layout
3. Components
4. Pages
5. Utilities (responsive overrides)
6. Legacy (temporary, will be removed)
```

**Why it matters**: Later imports can override earlier ones. Responsive styles should come last to override desktop styles.

---

## 🐛 Debugging Tips

### CSS Not Applying?
1. Check if the selector is in the right file
2. Check import order in `main.css`
3. Look for `!important` overrides (we removed most)
4. Check browser DevTools to see which CSS file the rule is from

### Mobile Styles Not Working?
1. **Check ONLY** `5-utilities/responsive.css`
2. All mobile styles are there (no more scattered queries!)
3. Check if `@media (max-width: 768px)` is wrapping your change

### Animation Not Playing?
1. Check `3-components/animations.css`
2. Make sure @keyframes is defined
3. Check element has animation property applied

---

## 🚀 Future Work (Optional)

### Easy Wins
- [ ] Extract remaining 300 lines from `styles-legacy.css`
- [ ] Add more CSS comments for complex sections
- [ ] Create visual component catalog (HTML page)

### Medium Effort
- [ ] Add CSS linting (stylelint)
- [ ] Add CSS minification to build
- [ ] Create design system documentation

### Advanced (Post-Launch)
- [ ] Consider CSS-in-JS if moving to React
- [ ] Add Storybook for component preview
- [ ] Performance monitoring

---

## 📚 Resources

- **CSS Architecture**: ITCSS methodology (Inverted Triangle)
- **File Naming**: Numbered prefixes ensure load order
- **Variables**: CSS Custom Properties for theming
- **Responsive**: Mobile-first approach with desktop overrides

---

## ❓ FAQ

**Q: Can I delete styles-legacy.css?**  
A: Not yet! It still has ~300 lines of styles. Wait until those are extracted.

**Q: Why are there numbers in folder names?**  
A: To ensure correct import order (1 loads before 2, etc.)

**Q: Where do mobile styles go?**  
A: **ALWAYS** in `5-utilities/responsive.css` - keeps them organized!

**Q: How do I add a new component?**  
A: Create a new file in `3-components/` and import it in `main.css`

**Q: What if I need a new CSS variable?**  
A: Add it to `1-foundations/variables.css` in the appropriate section

---

**Happy Coding!** 🎉

If you have questions about any style, use your editor's "Go to Definition" feature or search the styles/ directory. Everything is now logically organized and easy to find!

