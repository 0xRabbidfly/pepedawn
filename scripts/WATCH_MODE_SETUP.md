# WATCH MODE SETUP

## Quick Start

```bash
# Test it works
node scripts/automate-round.js WATCH

# Keep running with pm2
npm install -g pm2
pm2 start scripts/automate-round.js --name pepedawn-watcher -- WATCH
pm2 save
pm2 startup  # Follow instructions to start on boot
```

## Commands

```bash
# View logs
pm2 logs pepedawn-watcher

# Stop
pm2 stop pepedawn-watcher

# Restart
pm2 restart pepedawn-watcher

# Remove
pm2 delete pepedawn-watcher
```

## Alternative: Cron (checks every 5 minutes)

```bash
# Edit crontab
crontab -e

# Add this line
*/5 * * * * cd /path/to/pepedawn && node scripts/automate-round.js WATCH >> /tmp/pepedawn-watch.log 2>&1
```

## Alternative: Manual (Terminal Window)

```bash
# Run in terminal, leave open
node scripts/automate-round.js WATCH

# Or background process
nohup node scripts/automate-round.js WATCH > watch.log 2>&1 &

# Kill it later
pkill -f "automate-round.js WATCH"
```

## What It Does

Polls contract every 30 seconds. When round status changes:

- **Closed** → Auto-snapshots
- **Snapshot** → Auto-generates participants, commits Merkle root, requests VRF
- **WinnersReady** → Auto-generates winners, commits Merkle root
- **Distributed** → Done

## Requirements

- `contracts/.env` with `CONTRACT_ADDRESS`, `PRIVATE_KEY`, `SEPOLIA_RPC_URL`
- Node.js installed
- Foundry installed (for `cast` commands)
- Sepolia ETH in wallet for gas

## Troubleshooting

**Script crashes**: Check logs for RPC errors, low ETH balance, or missing .env vars

**Actions not triggering**: Check round status manually:
```bash
cd contracts/scripts/cli
node manage-round.js status 1
```

**pm2 not found**: Install globally with `npm install -g pm2`

**Contract calls fail**: Verify `CONTRACT_ADDRESS` and `PRIVATE_KEY` in `contracts/.env`

