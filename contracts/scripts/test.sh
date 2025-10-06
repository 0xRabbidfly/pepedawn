#!/bin/bash

# Test Script for PepedawnRaffle Contract
# Usage: ./scripts/test.sh [profile]

set -e

# Default profile
PROFILE=${1:-ci}

echo "🧪 Running tests with profile: $PROFILE"

# Load environment variables if .env exists
if [ -f .env ]; then
    echo "📋 Loading environment variables..."
    export $(grep -v '^#' .env | xargs)
fi

# Run tests based on profile
case $PROFILE in
    "unit")
        echo "🔬 Running unit tests (mocked dependencies)..."
        forge test --profile unit
        ;;
    "integration")
        echo "🔗 Running integration tests (workflow with mocks)..."
        forge test --profile integration
        ;;
    "deployed")
        echo "🌐 Running deployed contract tests..."
        if [ -z "$SEPOLIA_RPC_URL" ]; then
            echo "❌ SEPOLIA_RPC_URL not set. Please set it in .env file"
            exit 1
        fi
        forge test --profile deployed
        ;;
    "vrf")
        echo "🎲 Running VRF tests (requires funded subscription)..."
        if [ -z "$SEPOLIA_RPC_URL" ]; then
            echo "❌ SEPOLIA_RPC_URL not set. Please set it in .env file"
            exit 1
        fi
        forge test --profile vrf
        ;;
    "security")
        echo "🔒 Running security tests..."
        forge test --profile security
        ;;
    "all")
        echo "🎯 Running all tests (excluding VRF)..."
        forge test --profile all
        ;;
    "ci")
        echo "🚀 Running CI tests (fast, reliable)..."
        forge test --profile ci
        ;;
    *)
        echo "❌ Unknown profile: $PROFILE"
        echo "Available profiles: unit, integration, deployed, vrf, security, all, ci"
        exit 1
        ;;
esac

echo "✅ Tests completed successfully!"
