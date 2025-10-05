# PEPEDAWN — Artist One‑Pager 🎨🧪🃏

## 🎯 What we’re building (non‑technical)
A playful, lightweight website where people connect an Ethereum wallet to place small bets for a 2‑week “round” and possibly win Emblem Vault packs of the Counterparty fake rare asset PEPEDAWN. A live leaderboard shows current odds for the top prize. Winners are chosen fairly using verifiable on‑chain randomness.

## 🗓️ Round timeline
- Duration: 2 weeks (open → close → draw → distribute prizes)
- After close: randomness → winners → prizes auto‑distributed

## 🏆 Prizes (display on main page)
- 1× Fake Pack (3 PEPEDAWN cards)
- 1× Kek Pack (2 PEPEDAWN cards)
- 8× Pepe Packs (1 PEPEDAWN card)

## 🧩 Skill boost (puzzle)
- Each wallet may submit exactly 1 puzzle solution per round
- Accepted solution increases odds by +40% (weight multiplier 1.4×)

---

## 📄 Pages and visual focus
1) Title Page (Landing)
- Big hero art with subtle loop animation ✨
- Ambient/lo‑fi theme music 🎵 (toggle on/off)
- Prominent “Enter” button
- Vibe: playful, collectible, rare card culture, a hint of mystery

2) Main Page (Betting + Leaderboard)
- Clear wallet connect area
- Betting widget: 1 / 5 / 10 ticket bundles (prices shown)
- Leaderboard right below: show wallet (masked) + % chance for the Fake Pack 📊
- Micro‑animations for changes (e.g., odds rising, confetti on successful bet)

3) Rules / About Page
- Simple, icon‑led explainer:
  - ⚖️ Fairness: Verifiable randomness (VRF)
  - 🔒 On‑chain escrow for wagers
  - 🧩 +40% skill boost via 1 puzzle submission
  - 📦 Prizes as Emblem Vault assets (auto‑distributed)
  - 🗓️ 2‑week rounds; timelines are fixed once opened

---

## 🎨 Art direction
- Color: rich greens/pepe tones + neon accents; dark background for card‑gallery feel
- Typography: bold display for headings, clean sans‑serif for body
- Texture: subtle halftone/noise overlays; trading‑card frames/borders for sections
- Motion: CSS/Lottie‑level only; keep it light and snappy (no heavy 3D)
- Iconography: emoji + simple line icons; consistent stroke and corner radius

## 📦 Asset checklist (from you)
- Logo/wordmark (SVG + PNG)
- Hero illustration(s) for title page (SVG/PNG; 2–3 variants preferred)
- Loop animation (Lottie JSON preferred, or MP4/WebM fallback ≤ 4–6 MB)
- Background textures/patterns (tileable)
- Icon set (SVG) for fairness, escrow, puzzle, prizes, timeline
- Audio track (loopable 30–60s) + license details
- OG/social preview image (1200×630 PNG)

## 🔧 Practical constraints (for performance & accessibility)
- Keep individual assets small (SVG where possible; images ≤ 300–500 KB)
- Prefer vector or short loops over long videos
- Provide alt text guidance for key images
- Ensure sufficient contrast (WCAG AA)
- Audio default: off or very low; always user‑controllable

## 🧭 Copy cues (you can style/Typography)
- Title: “PEPEDAWN” → subhead: “Provably fair draws. On‑chain prizes.”
- Buttons: “Enter”, “Connect Wallet”, “Place Bet”, “Submit Puzzle Proof”, “View Rules”
- Microcopy: playful, short, collectible‑culture tone

## 🔗 References (internal, no external links needed)
- Prizes and rules come from `spec.md` (this feature directory)
- Audio placeholders are acceptable now; creator to provide final track later (see FR‑022)

## ✅ Deliverables & format
- Source files: SVG/PNG, Lottie JSON (or MP4/WebM), audio WAV/MP3
- Hand‑off: a zipped `/assets` folder with a short README listing filenames, sizes, and usage

---

## 📬 Questions for you (quick)
- Do you prefer flat vector or textured collage?
- One hero or a small set we can rotate?
- Any signature motif you want repeated (frame, glyph, sticker)?

> Goal: a beautiful, lightweight, one‑look experience that feels like opening a rare pack — fast, fun, and fair.
