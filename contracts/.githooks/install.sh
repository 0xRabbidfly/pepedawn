#!/bin/bash
# Install git hooks for PepedawnRaffle

set -e

echo "📦 Installing git hooks..."

# Navigate to project root
cd "$(dirname "$0")/../.." || exit 1

# Check if .git directory exists
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Copy pre-commit hook
cp contracts/.githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✅ Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will now run automatically before each commit."
echo "It executes the fast test suite (<5 seconds) to catch issues early."
echo ""
echo "To skip the hook temporarily, use: git commit --no-verify"

