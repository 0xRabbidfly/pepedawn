#!/bin/bash

# Sepolia Contract Interaction Script
CONTRACT_ADDRESS="0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PepedawnRaffle Sepolia Interaction ===${NC}"
echo "Contract: $CONTRACT_ADDRESS"
echo ""

# Check if environment variables are set
if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo -e "${RED}Error: SEPOLIA_RPC_URL not set${NC}"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}Warning: PRIVATE_KEY not set (read-only mode)${NC}"
fi

# Function to check contract state
check_state() {
    echo -e "${BLUE}=== Contract State ===${NC}"
    
    echo -n "Current Round ID: "
    cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $SEPOLIA_RPC_URL
    
    echo -n "Emergency Paused: "
    cast call $CONTRACT_ADDRESS "emergencyPaused()" --rpc-url $SEPOLIA_RPC_URL
    
    echo -n "Contract Paused: "
    cast call $CONTRACT_ADDRESS "paused()" --rpc-url $SEPOLIA_RPC_URL
    
    echo -n "Owner: "
    cast call $CONTRACT_ADDRESS "owner()" --rpc-url $SEPOLIA_RPC_URL
    
    # Get current round details if exists
    CURRENT_ROUND=$(cast call $CONTRACT_ADDRESS "currentRoundId()" --rpc-url $SEPOLIA_RPC_URL)
    if [ "$CURRENT_ROUND" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
        echo -e "${BLUE}=== Round $CURRENT_ROUND Details ===${NC}"
        cast call $CONTRACT_ADDRESS "rounds(uint256)" $CURRENT_ROUND --rpc-url $SEPOLIA_RPC_URL
    else
        echo -e "${YELLOW}No rounds created yet${NC}"
    fi
}

# Function to create round
create_round() {
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY required for transactions${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Creating new round...${NC}"
    cast send $CONTRACT_ADDRESS "createRound()" --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
}

# Function to open round
open_round() {
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY required for transactions${NC}"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Round ID required${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Opening round $1...${NC}"
    cast send $CONTRACT_ADDRESS "openRound(uint256)" $1 --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
}

# Function to place bet
place_bet() {
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY required for transactions${NC}"
        return 1
    fi
    
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}Error: Usage: place_bet <tickets> <eth_amount>${NC}"
        echo "Example: place_bet 1 0.01"
        return 1
    fi
    
    echo -e "${GREEN}Placing bet: $1 tickets for $2 ETH...${NC}"
    cast send $CONTRACT_ADDRESS "placeBet(uint256)" $1 --value $(cast --to-wei $2 ether) --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
}

# Main menu
case "$1" in
    "check"|"status"|"")
        check_state
        ;;
    "create")
        create_round
        ;;
    "open")
        open_round $2
        ;;
    "bet")
        place_bet $2 $3
        ;;
    "quick-start")
        echo -e "${GREEN}=== Quick Start: Creating and Opening Round ===${NC}"
        check_state
        echo ""
        create_round
        echo ""
        sleep 2
        open_round 1
        echo ""
        check_state
        ;;
    *)
        echo "Usage: $0 [command] [args]"
        echo ""
        echo "Commands:"
        echo "  check, status     - Check contract state"
        echo "  create           - Create new round"
        echo "  open <roundId>   - Open round for betting"
        echo "  bet <tickets> <eth> - Place bet (e.g., bet 1 0.01)"
        echo "  quick-start      - Create and open round in one go"
        echo ""
        echo "Examples:"
        echo "  $0 check"
        echo "  $0 create"
        echo "  $0 open 1"
        echo "  $0 bet 1 0.01"
        echo "  $0 quick-start"
        ;;
esac
