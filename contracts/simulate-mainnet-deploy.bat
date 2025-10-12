@echo off
REM Simulate PepedawnRaffle deployment on local mainnet fork
REM This gives exact gas costs without deploying to real mainnet

echo.
echo ==================================================
echo   PepedawnRaffle Mainnet Deployment Simulator
echo ==================================================
echo.
echo This will:
echo   1. Fork Ethereum mainnet locally using Anvil
echo   2. Let you deploy and get EXACT gas costs
echo   3. No actual mainnet deployment or cost
echo.
echo Choose a mainnet RPC endpoint:
echo   [1] ethereum.publicnode.com (free, reliable)
echo   [2] eth.llamarpc.com (free, reliable)
echo   [3] Custom (your own Alchemy/Infura key)
echo.
set /p choice="Enter choice (1-3): "

if "%choice%"=="1" (
    set RPC_URL=https://ethereum.publicnode.com
) else if "%choice%"=="2" (
    set RPC_URL=https://eth.llamarpc.com
) else if "%choice%"=="3" (
    set /p RPC_URL="Enter your RPC URL: "
) else (
    echo Invalid choice
    exit /b 1
)

echo.
echo Using RPC: %RPC_URL%
echo.
echo Starting Anvil fork...
echo.
echo ===============================================
echo   IMPORTANT: After Anvil starts...
echo ===============================================
echo.
echo Open a NEW terminal and run:
echo   cd contracts
echo   forge script scripts/forge/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
echo.
echo Look for "Gas Used:" in the output!
echo.
echo Press Ctrl+C here to stop Anvil when done.
echo ===============================================
echo.

anvil --fork-url %RPC_URL%

