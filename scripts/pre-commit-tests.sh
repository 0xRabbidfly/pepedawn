#!/bin/bash

echo "🔍 Running pre-commit checks..."

# Run smart contract tests
echo "🧪 Running smart contract tests..."
cd contracts

# Test files to run (matching GitHub Actions)
TEST_FILES=(
    "test/BasicDeployment.t.sol"
    "test/AccessControl.t.sol"
    "test/InputValidation.t.sol"
    "test/Wager.t.sol"
    "test/WinnerSelection.t.sol"
    "test/Distribution.t.sol"
    "test/EmergencyControls.t.sol"
    "test/Governance.t.sol"
    "test/Round.t.sol"
    "test/Security.t.sol"
    "test/ScenarioFullRound.t.sol"
)

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
    echo "Running $test_file..."
    forge test --match-path "$test_file"
    if [ $? -ne 0 ]; then
        echo "❌ Test failed: $test_file"
        exit 1
    fi
done

echo "✅ All smart contract tests passed!"

# Run frontend linting
echo "🔍 Running frontend linting..."
cd ../frontend
npm run lint
if [ $? -ne 0 ]; then
    echo "❌ Frontend linting failed!"
    exit 1
fi

echo "✅ All pre-commit checks passed!"
