# ✨ PEPEDAWN — Stakeholder One‑Pager (Product Features & Prize Mechanics)

## 💎 Value Proposition (business)
A simple, fair, and transparent on‑chain experience where users place small bets during a 2‑week round to win PEPEDAWN prize packs. Odds are visible, outcomes are provably fair, and prizes are automatically delivered.

## 🧩 Product Features (business language)
- 🔐 Wallet-based entry on Ethereum; no accounts/passwords
- 🧮 Ticket bundles with discounts (1 / 5 / 10) to encourage participation
- 🧠 Skill boost: submit one puzzle solution per wallet for +40% odds boost
- 📊 Live leaderboard shows each wallet’s chance for the top prize (Fake Pack)
- ⏱️ 2‑week rounds with clear open/close and countdown
- 📦 Automatic prize distribution via Emblem Vault upon round completion
- 🧾 Transparent, on‑chain events for wagers, proofs, draws, winners, distribution
- ⚖️ Clear rules & compliance: denylist supported; no allowlist
- 💰 Fee policy: 80% creators, 20% retained as a reward pool for the next round
- 🚦 Per‑wallet cap per round to keep play fair and accessible

## 🎰 How the Betting Mechanic Distributes Prizes (end‑to‑end)
1) 🧭 Round setup: define timeline, ticket pricing/discounts, prize tiers; preload Emblem Vault prizes.
2) 🎟️ Wagering: users connect a wallet and purchase tickets (bundles encouraged). Wagers are escrowed on‑chain.
3) 🧠 Skill boost: each wallet may submit a single puzzle proof for a +40% weight boost (capped).
4) 🧊 Snapshot: before the draw, we snapshot eligible wallets and weights to lock the participant set.
5) 🎲 Fair draw: request verifiable randomness on Ethereum; result is reproducible from on‑chain data.
6) 🏅 Winner selection: assign winners to prize tiers (Fake/Kek/Pepe) using the random output and snapshot.
7) 📦 Distribution: automatically transfer Emblem Vault assets to winners (or escrow for claim) and emit events.
8) 💸 Fees & carryover: allocate 80% to creators; retain 20% in contract as a reward for the next round.

## 💡 Why People Participate (behavioral design, ethical use)
- ⏳ Scarcity & countdown: 2‑week windows nudge timely participation
- 📈 Visible progress: leaderboard odds rise with each ticket, reinforcing engagement
- 👥 Social proof: recent wagers/entries signal activity and safety
- 🧾 Bundle value: simple discounts (5/10 tickets) anchor affordable upsize decisions
- 🧠 Skill expression: puzzle proof offers non‑financial path to improve odds
- 🛡️ Fairness trust: verifiable randomness and on‑chain records reduce skepticism
- ⚡ Fast feedback: micro‑interactions and immediate leaderboard updates reward action

## 📊 Success Metrics (round‑level KPIs)
- Unique connected wallets; conversion rate (connect → bet)
- Average tickets per bettor; share of 5/10 bundles
- Puzzle submission rate; impact on odds and conversions
- Prize distribution SLA after draw; VRF fulfillment time
- Repeat participation across rounds; retention
- Page performance (bundle size, time‑to‑interactive)

## 🚧 Risks & Mitigations (concise)
- 🏛️ Regulatory/compliance: clear disclaimers and basic gating (age/jurisdiction)
- 🎲 Fairness concerns: VRF + public events; reproducible draws
- 🐋 Whale dominance: per‑wallet bet cap per round
- 📦 Supply readiness: prizes preloaded before bets open
- 🛡️ Abuse/spam: denylist enforcement; one proof rule; minimum stake
- 📚 UX confusion: rules page with plain‑language flow and visuals

## 📜 Constraints & Policies
- Ethereum only; no BTC/XCP operations (distribution via Emblem Vault on Ethereum)
- No allowlist; denylist allowed and enforced
- Automatic prize distribution after VRF fulfillment
- Transparent public read endpoints mirror on‑chain state

## 🗳️ Stakeholder Review — Decisions to Confirm
- Brand tone and visual direction for public pages
- Final copy for disclaimers/rules and eligibility language
- Puzzle theme/voice and acceptable proof format
- Public display style for leaderboard (masking, rounding policy)
- Final prize identifiers and round schedule

> 🌈 Outcome: A trustworthy, engaging product that balances skill and chance, increases participation with simple incentives, and ships with transparent, auditable mechanics.
