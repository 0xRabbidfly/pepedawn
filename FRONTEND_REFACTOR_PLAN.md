# Frontend Refactoring Plan - PEPEDAWN

**Date**: 2025-10-11  
**Scope**: CSS, JavaScript, HTML cleanup for production readiness  
**Goal**: Reduce UI bugs, improve maintainability, minimize risk before production deployment  
**Approach**: Pragmatic refactoring for a small-scale site that may not see frequent updates

---

## Executive Summary

Your frontend has grown organically to **~5,000 lines** of code across CSS, JS, and HTML. While functional, the codebase has accumulated technical debt that's causing UI bugs and making fixes harder. This plan focuses on **low-risk, high-value** improvements to clean up the code before production without introducing enterprise-level complexity.

### Current State Assessment

| File | Lines | Main Issues |
|------|-------|-------------|
| `styles.css` | 2,633 | Mixed concerns, duplicate patterns, media query chaos |
| `main.js` | 1,938 | God object anti-pattern, duplicate mobile/desktop logic |
| `ui.js` | 954 | Reasonable, but tightly coupled to main.js |
| `main.html` | 291 | Inline styles, deeply nested structures |
| Other HTML | ~150 | Duplicate header/wallet sections |

### Risk Assessment
- **Current Risk**: Medium (UI bugs from CSS conflicts, state management issues)
- **Refactor Risk**: Low-Medium (if following this plan's staged approach)
- **Post-Refactor Risk**: Low (better organization = easier debugging)

---

## Part 1: CSS Organization (Priority: HIGH)

### Problem Analysis
Your 2,633-line CSS file has:
- **Mixed concerns**: Variables, reset, components, pages, utilities all together
- **Repeated media queries**: Mobile styles scattered across 15+ locations
- **Duplicate animations**: 8 different "pulse" animations that are nearly identical
- **Magic numbers**: Hardcoded values instead of CSS variables
- **Specificity wars**: `.ticket-option-card.selected::before` competing with other selectors

### Proposed Structure
```
frontend/src/styles/
├── 1-foundations/
│   ├── reset.css           (80 lines)   - CSS reset, box-sizing
│   ├── variables.css       (60 lines)   - All CSS custom properties
│   └── typography.css      (40 lines)   - Font sizes, weights, line-heights
├── 2-layout/
│   ├── header.css          (150 lines)  - Header, navigation, hamburger menu
│   ├── page-layouts.css    (100 lines)  - Main page structures
│   └── grid-flexbox.css    (80 lines)   - Reusable layout patterns
├── 3-components/
│   ├── buttons.css         (120 lines)  - All button styles
│   ├── cards.css           (180 lines)  - Ticket cards, prize cards, etc.
│   ├── forms.css           (90 lines)   - Inputs, textareas, selects
│   ├── modals.css          (70 lines)   - Ticket office, mobile slideout
│   ├── status-badges.css   (120 lines)  - Round status, merkle badge
│   ├── leaderboard.css     (80 lines)   - Leaderboard specific
│   └── animations.css      (100 lines)  - All animations centralized
├── 4-pages/
│   ├── home.css            (120 lines)  - Title page specific
│   ├── main.css            (200 lines)  - Ticket office page
│   ├── claim.css           (80 lines)   - Claims page
│   └── leaderboard.css     (60 lines)   - Leaderboard page
├── 5-utilities/
│   ├── responsive.css      (400 lines)  - ALL mobile styles in ONE place
│   └── utilities.css       (100 lines)  - Helper classes
└── main.css                (20 lines)   - Just @import statements
```

**Total**: ~2,250 lines (saving 380 lines through deduplication)

### CSS Refactoring Strategy

#### Phase 1: Extract Variables (1 hour, SAFE)
- Move all CSS custom properties to `variables.css`
- Add missing variables for repeated values (spacing, shadows, transitions)
- **Risk**: VERY LOW - just moving existing variables

#### Phase 2: Split by Category (2-3 hours, SAFE)
- Create file structure above
- Copy/paste existing CSS into logical files
- Don't change selectors or properties yet
- Test after each major file split
- **Risk**: LOW - if you test incrementally

#### Phase 3: Consolidate Media Queries (2 hours, MEDIUM RISK)
- Move ALL mobile styles to `responsive.css`
- Organize by component, not by page
- Test mobile after this step
- **Risk**: MEDIUM - mobile layouts are tricky

#### Phase 4: Deduplicate Animations (1 hour, SAFE)
- Merge similar animations into parameterized versions
- Example: `pulse-glow-blue`, `pulse-glow-orange`, `pulse-glow-green` → one `pulse-glow(color)` using CSS variables
- **Risk**: LOW - animations are isolated

#### Phase 5: Cleanup Specificity (1 hour, LOW RISK)
- Remove unnecessary `!important` flags (you have 15+)
- Simplify selector chains
- Use BEM-like naming for clarity
- **Risk**: LOW - if tested incrementally

### CSS Quick Wins (Do First)
1. **Remove duplicate disabled styles** (buttons and forms both define disabled states)
2. **Consolidate color values** (you use `#4CAF50` in 47 places - use variable)
3. **Fix mobile ticket card sizing** (multiple conflicting width rules)
4. **Remove unused styles** (search for unused classes with grep)

---

## Part 2: JavaScript Refactoring (Priority: HIGH)

### Problem Analysis
Your `main.js` is 1,938 lines doing **everything**:
- Wallet connection
- Contract initialization
- Event listeners setup
- Transaction handling
- UI updates
- Mobile vs desktop logic duplication

### Proposed Structure
```
frontend/src/
├── main.js                 (300 lines)  - Entry point, orchestration
├── wallet/
│   ├── connection.js       (200 lines)  - Connect, disconnect, network switching
│   ├── state.js            (100 lines)  - Wallet state management
│   └── events.js           (150 lines)  - Account/network change handlers
├── contract/
│   ├── loader.js           (200 lines)  - Contract loading, initialization
│   ├── events.js           (400 lines)  - Contract event listeners
│   └── transactions.js     (300 lines)  - buyTickets, submitProof, etc.
├── ui/
│   ├── index.js            (100 lines)  - UI orchestration (kept from current ui.js)
│   ├── round-status.js     (200 lines)  - Round display logic
│   ├── leaderboard.js      (150 lines)  - Leaderboard display
│   ├── user-stats.js       (120 lines)  - User stats display
│   └── notifications.js    (80 lines)   - Toast messages
├── mobile/
│   ├── detection.js        (50 lines)   - Device detection
│   └── handlers.js         (150 lines)  - Mobile-specific handlers
└── utils/
    ├── formatters.js       (80 lines)   - Address/number formatting
    ├── timers.js           (60 lines)   - Countdown logic
    └── validation.js       (100 lines)  - Input validation
```

**Total**: ~2,740 lines (growth is OK - better organization + less duplication)

### JavaScript Refactoring Strategy

#### Phase 1: Extract Utilities (1 hour, SAFE)
- Create `utils/formatters.js` with `formatAddress`, `formatEther`, etc.
- Create `utils/timers.js` with countdown logic
- Update imports in main.js
- **Risk**: VERY LOW - pure functions

#### Phase 2: Split Wallet Logic (2 hours, MEDIUM RISK)
- Extract wallet connection to `wallet/connection.js`
- Extract account/network handlers to `wallet/events.js`
- Keep state management simple (no Redux)
- **Risk**: MEDIUM - wallet state is critical

#### Phase 3: Split Contract Logic (3 hours, MEDIUM-HIGH RISK)
- Extract contract event listeners to `contract/events.js`
- Extract transaction functions to `contract/transactions.js`
- Ensure event deduplication works
- **Risk**: MEDIUM-HIGH - contract events are complex

#### Phase 4: Mobile Consolidation (2 hours, MEDIUM RISK)
- Create `mobile/handlers.js` for mobile-specific logic
- Remove duplicate code between `buyTickets()` and `buyTicketsMobile()`
- Use feature detection instead of duplication
- **Risk**: MEDIUM - mobile UX is sensitive

#### Phase 5: UI State Management (2 hours, MEDIUM RISK)
- Create simple state object for UI state
- Reduce direct DOM manipulation scattered throughout
- Centralize button state updates
- **Risk**: MEDIUM - UI state bugs are visible

### JavaScript Quick Wins (Do First)
1. **Extract `formatAddress`** to utils (used 12+ times)
2. **Merge `buyTickets()` and `buyTicketsMobile()`** (90% identical code)
3. **Extract `updateButtonStates()`** logic (called from 8 places)
4. **Create `showToast()` helper** (instead of `showTransactionStatus` everywhere)
5. **Add JSDoc comments** to key functions (helps IDE autocomplete)

---

## Part 3: HTML Simplification (Priority: MEDIUM)

### Problem Analysis
- **Duplicate headers** across 4 HTML files
- **Inline styles** (`style="display: none;"` appears 15+ times)
- **Deep nesting** (ticket office has 7 levels of nesting)
- **Inconsistent class naming** (`.btn-primary` vs `.btn-buy-tickets`)

### Proposed Changes

#### Quick Wins (1 hour, LOW RISK)
1. **Remove inline styles** - use classes instead
   ```html
   <!-- Before -->
   <div id="wallet-info" style="display: none;">
   
   <!-- After -->
   <div id="wallet-info" class="hidden">
   ```

2. **Extract header to partial** (if using build tool) OR document the canonical version
   ```html
   <!-- Add comment to each header -->
   <!-- CANONICAL HEADER - Keep in sync with other pages -->
   ```

3. **Simplify ticket card structure**
   ```html
   <!-- Before: 7 levels of nesting -->
   <div class="ticket-option-card">
     <div class="ticket-visual">
       <div class="ticket-single">🎫</div>
     </div>
     <div class="ticket-info">
       <div class="ticket-label">1 Ticket</div>
       <div class="ticket-price">0.005 ETH</div>
     </div>
     <div class="ticket-discount"></div>
   </div>
   
   <!-- After: 4 levels, same visual result -->
   <button class="ticket-card" data-tickets="1" data-amount="0.005">
     <span class="ticket-card__icon">🎫</span>
     <span class="ticket-card__label">1 Ticket</span>
     <span class="ticket-card__price">0.005 ETH</span>
   </button>
   ```

4. **Use semantic HTML**
   - Replace `<div class="btn">` with `<button>`
   - Replace `<div class="ticket-option-card">` with `<button>` (it's clickable)
   - Add ARIA labels where missing

### HTML Refactoring Strategy

#### Phase 1: Audit & Document (30 min, SAFE)
- List all inline styles and their purpose
- Document which elements are shown/hidden by JS
- **Risk**: ZERO - just documentation

#### Phase 2: Add Utility Classes (30 min, SAFE)
- Add `.hidden`, `.visible`, `.disabled` classes
- Replace inline styles incrementally
- **Risk**: VERY LOW - additive changes

#### Phase 3: Flatten Nesting (1 hour, MEDIUM RISK)
- Simplify ticket cards (biggest offender)
- Test click handlers still work
- **Risk**: MEDIUM - event delegation may break

#### Phase 4: Semantic HTML (1 hour, LOW RISK)
- Replace `<div role="button">` with `<button>`
- Add missing ARIA labels
- Improves accessibility
- **Risk**: LOW - mostly additive

---

## Part 4: Bug Fix Targets

Based on common patterns in your code, here are likely bug sources:

### CSS-Related Bugs
1. **Mobile ticket card sizing** - conflicting width rules
   - Location: `styles.css:2248-2257`
   - Fix: Consolidate to single width declaration

2. **Z-index issues** - 8 different z-index values without system
   - Fix: Create z-index scale (1=base, 10=dropdown, 100=modal, 1000=toast)

3. **Animation conflicts** - multiple animations on same element
   - Location: Status badges, ticket icons
   - Fix: Only apply one animation class at a time

4. **Hamburger menu race condition** - click handler on document conflicts with button click
   - Location: `main.js:329-334`
   - Fix: Use `stopPropagation()` on button click

### JavaScript-Related Bugs
1. **Event listener duplication** - `eventListenersSetup` flag can get out of sync
   - Location: `main.js:1003-1006`
   - Fix: Use `contract.off()` before `contract.on()`

2. **Race condition in round updates** - multiple calls to `updateRoundStatus()` simultaneously
   - Location: Periodic updates + event handlers both call it
   - Fix: Debounce update functions

3. **Mobile slideout state** - doesn't always close after purchase
   - Location: `main.js:1686-1694`
   - Fix: Add slideout state management

4. **Button state sync** - buttons can be enabled when they shouldn't be
   - Location: `main.js:59-194` (updateButtonStates is complex)
   - Fix: Single source of truth for button state

5. **Proof input disabled state** - placeholder not updating correctly
   - Location: `main.js:170-173`
   - Fix: Separate disabled check from placeholder update

---

## Part 5: Testing Strategy

### Pre-Refactor Testing (Do This First!)
1. **Document current behavior**
   - Take screenshots of all pages (desktop + mobile)
   - List all interactive elements and test them
   - Record current bugs (so you don't re-break things)

2. **Create smoke test checklist**
   ```
   Desktop:
   [ ] Connect wallet
   [ ] Select ticket card → ticket office opens
   [ ] Buy tickets
   [ ] Submit proof
   [ ] View leaderboard
   [ ] View claims
   [ ] Hamburger menu (shouldn't exist on desktop)
   
   Mobile:
   [ ] Connect wallet
   [ ] Select ticket card → mobile slideout opens
   [ ] Buy tickets from slideout
   [ ] Submit proof
   [ ] Hamburger menu opens/closes
   [ ] Leaderboard scrolls
   [ ] Claims page works
   ```

3. **Test on target devices**
   - Desktop: Chrome, Firefox (Edge optional)
   - Mobile: iOS Safari, Android Chrome
   - Don't worry about IE11

### During Refactor Testing
- **Test after each phase** (don't accumulate changes)
- **Use browser dev tools** to check for console errors
- **Test mobile emulation** in Chrome DevTools
- **Test wallet interactions** with actual MetaMask

### Post-Refactor Validation
1. **Run smoke tests again**
2. **Check bundle size** (ensure it didn't grow significantly)
3. **Test on slow connection** (throttle in DevTools)
4. **A/B test** - deploy to staging URL, compare with production

---

## Part 6: Implementation Timeline

### Conservative Estimate (Safe Approach)
```
Week 1: CSS Refactoring
├─ Day 1: Variable extraction + file structure setup
├─ Day 2: Split CSS into files, test desktop
├─ Day 3: Consolidate mobile styles, test mobile
├─ Day 4: Deduplicate animations, cleanup
└─ Day 5: Final testing, bug fixes

Week 2: JavaScript Refactoring  
├─ Day 1: Extract utilities, wallet connection
├─ Day 2: Split contract logic
├─ Day 3: Mobile consolidation
├─ Day 4: UI state management
└─ Day 5: Final testing, bug fixes

Week 3: HTML + Final Polish
├─ Day 1: HTML simplification
├─ Day 2: Fix identified bugs
├─ Day 3: Cross-browser testing
├─ Day 4: Performance optimization
└─ Day 5: Final QA + deploy to staging
```

### Aggressive Estimate (If Pressed for Time)
```
Week 1: High-Value Changes Only
├─ Days 1-2: CSS quick wins + split into 5 files (not 15)
├─ Days 3-4: JS quick wins + extract 3 key modules
└─ Day 5: HTML quick wins + bug fixes

Week 2: Testing & Deployment
├─ Days 1-3: Thorough testing
├─ Day 4: Bug fixes
└─ Day 5: Deploy to production
```

---

## Part 7: Risk Mitigation

### Low-Risk Wins (Do These First)
1. ✅ Extract formatters to utils
2. ✅ Add CSS variables for magic numbers
3. ✅ Remove unused CSS (audit with Coverage tool in DevTools)
4. ✅ Add JSDoc comments
5. ✅ Remove inline styles from HTML

### Medium-Risk Changes (Test Thoroughly)
1. ⚠️ CSS file splitting (test desktop + mobile)
2. ⚠️ Mobile media query consolidation
3. ⚠️ Wallet logic extraction
4. ⚠️ Contract event listener refactor

### High-Risk Changes (Consider Deferring)
1. 🚨 Complete UI state rewrite
2. 🚨 Moving to a framework (React/Vue)
3. 🚨 Rewriting mobile layouts from scratch

### Rollback Plan
1. **Use Git branches** - create `refactor/css`, `refactor/js` branches
2. **Commit frequently** - after each file split
3. **Tag working states** - `git tag refactor-css-done`
4. **Keep old code** - comment out instead of delete (temporarily)
5. **Deploy to staging first** - test for 24 hours before production

---

## Part 8: Long-Term Maintenance

### Documentation to Add
1. **CSS Architecture Doc** - explain file structure
2. **Component Catalog** - screenshot + code for each UI component
3. **State Management Doc** - how wallet/contract state flows
4. **Mobile Testing Guide** - devices/browsers to test

### Future Improvements (Post-Launch)
1. **Consider CSS-in-JS** - if you add React later
2. **Add TypeScript** - for better type safety
3. **Component library** - extract reusable components
4. **Storybook** - visual component testing
5. **E2E tests** - Playwright or Cypress

### Debt to Monitor
1. **Event listener management** - still complex after refactor
2. **Mobile/desktop duplication** - some will remain
3. **State synchronization** - between UI and contract
4. **Performance** - if user base grows

---

## Part 9: Decision Framework

### When to Refactor
✅ **DO IT** if:
- Change is low-risk (utils, variables)
- Fixes a known bug
- Reduces duplication significantly (>50% reduction)
- Makes debugging easier

❌ **DON'T DO IT** if:
- Change is purely cosmetic
- Requires learning new tech
- Risk outweighs benefit
- No time to test thoroughly

### When to Defer
- You're within 48 hours of launch
- You haven't tested on mobile
- The current code works (no bugs)
- You don't have time for proper testing

---

## Part 10: Success Metrics

### Quantitative Metrics
- **CSS**: Reduce from 2,633 lines → ~2,200 lines (15% reduction)
- **JS**: Organize 1,938 lines → ~2,500 lines (better structure, worth the growth)
- **Bundle Size**: Should stay under 100KB gzipped
- **Bug Count**: Reduce known UI bugs from X → 0

### Qualitative Metrics
- ✅ New developer can find button styles in <60 seconds
- ✅ Mobile CSS is in ONE place, not scattered
- ✅ Fixing a bug requires editing 1 file, not 3
- ✅ Adding a new page takes <1 hour

---

## Appendix A: File-by-File Breakdown

### Critical Files (Change Carefully)
- `main.js` - Entry point, many dependencies
- `contract-config.js` - Security-critical
- `main.html` - Most complex page

### Safe to Refactor Files
- `styles.css` - CSS is declarative, easier to test
- `ui.js` - Pure UI logic, no state
- `utils/` - Pure functions

### Files to Create
- `styles/main.css` - Import hub
- `wallet/connection.js` - Wallet logic
- `contract/events.js` - Event handlers
- `utils/formatters.js` - Formatting helpers

---

## Appendix B: Tools & Resources

### Development Tools
- **VSCode Extensions**: 
  - ESLint (catch JS errors)
  - Stylelint (catch CSS errors)
  - Prettier (auto-format)
- **Browser DevTools**:
  - Coverage tab (find unused CSS)
  - Network tab (check bundle size)
  - Performance tab (check for jank)

### Testing Tools
- **Manual Testing**: Chrome DevTools mobile emulation
- **Cross-Browser**: BrowserStack (free for open source)
- **Performance**: Lighthouse (built into Chrome)

### Reference
- **CSS Organization**: [ITCSS](https://www.xfive.co/blog/itcss-scalable-maintainable-css-architecture/) 
- **JS Patterns**: [Clean Code JavaScript](https://github.com/ryanmcdermott/clean-code-javascript)
- **Mobile Testing**: [Google's Mobile-Friendly Test](https://search.google.com/test/mobile-friendly)

---

## Final Recommendations

### For Immediate Pre-Production (Next 48 Hours)
1. ✅ **Fix known mobile bugs only** (don't refactor)
2. ✅ **Test on real devices** (borrow phones if needed)
3. ✅ **Minimize changes** - stability > cleanliness

### For Post-Launch (Week 1 After Production)
1. ✅ **Start with CSS refactor** (lowest risk, highest value)
2. ✅ **Do Quick Wins first** (build confidence)
3. ✅ **Test on staging** (set up staging environment if you don't have one)

### For Long-Term Maintenance
1. ✅ **Keep it simple** - resist adding frameworks if not needed
2. ✅ **Document as you go** - future you will thank present you
3. ✅ **Refactor when fixing bugs** - don't make it a separate project

---

## Conclusion

Your frontend is **functional but fragile**. This plan gives you a path to **production-ready and maintainable** code without rewriting everything. The key is:

1. **Prioritize risk reduction** over perfection
2. **Test incrementally** - don't accumulate changes
3. **Start with low-risk wins** - build momentum
4. **Know when to stop** - done is better than perfect

**Estimated Total Time**: 80-120 hours (2-3 weeks full-time)  
**Minimum Viable Refactor**: 40 hours (CSS split + JS quick wins + bug fixes)  

**When in doubt**: Ship working code. You can always refactor after launch if users aren't experiencing bugs.

Good luck! 🚀

