// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PepedawnRaffle.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract CheckRoundStateScript is Script {
    PepedawnRaffle public raffle;
    
    function run() external {
        // Load the deployed contract address from environment
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        raffle = PepedawnRaffle(contractAddress);
        
        console.log("=== PEPEDAWN RAFFLE STATE CHECK ===");
        console.log("Contract Address:", contractAddress);
        
        // Check current round ID
        uint256 currentRoundId = raffle.currentRoundId();
        console.log("Current Round ID:", currentRoundId);
        
        if (currentRoundId == 0) {
            console.log("No rounds created yet.");
            console.log("Solution: Call createRound() to create the first round.");
            return;
        }
        
        // Get round details
        PepedawnRaffle.Round memory round = raffle.getRound(currentRoundId);
        
        console.log("\n=== ROUND", currentRoundId, "DETAILS ===");
        console.log("Status:", getStatusName(uint8(round.status)));
        console.log("Start Time:", round.startTime);
        console.log("End Time:", round.endTime);
        console.log("Total Tickets:", round.totalTickets);
        console.log("Total Weight:", round.totalWeight);
        console.log("Total Wagered:", round.totalWagered, "wei");
        console.log("Participant Count:", round.participantCount);
        console.log("VRF Request ID:", round.vrfRequestId);
        console.log("VRF Requested At:", round.vrfRequestedAt);
        console.log("Fees Distributed:", round.feesDistributed);
        
        // Check VRF configuration
        console.log("\n=== VRF CONFIGURATION ===");
        (IVRFCoordinatorV2Plus coordinator, uint256 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations) = raffle.vrfConfig();
        console.log("VRF Coordinator:", address(coordinator));
        console.log("Subscription ID:", subscriptionId);
        console.log("Key Hash: 0x%x", uint256(keyHash));
        console.log("Callback Gas Limit:", callbackGasLimit);
        console.log("Request Confirmations:", requestConfirmations);
        
        // Check contract security state
        console.log("\n=== SECURITY STATE ===");
        console.log("Paused:", raffle.paused());
        console.log("Emergency Paused:", raffle.emergencyPaused());
        
        // Provide next steps based on status
        console.log("\n=== NEXT STEPS ===");
        uint8 status = uint8(round.status);
        if (status == 0) { // Created
            console.log("Round is created but not open. Call openRound(", currentRoundId, ") to open it.");
        } else if (status == 1) { // Open
            console.log("Round is open for betting. You can:");
            console.log("- Place bets with placeBet()");
            console.log("- Close the round with closeRound(", currentRoundId, ")");
        } else if (status == 2) { // Closed
            console.log("Round is closed. Next step: snapshotRound(", currentRoundId, ")");
        } else if (status == 3) { // Snapshot
            console.log("Round snapshot taken. Next step: requestVRF(", currentRoundId, ")");
        } else if (status == 4) { // VRF Requested
            console.log("VRF requested. Waiting for Chainlink VRF response.");
            console.log("If stuck, you may need to manually fulfill VRF or wait for timeout.");
        } else if (status == 5) { // Distributed
            console.log("Round completed! You can now create a new round with createRound()");
        }
    }
    
    function getStatusName(uint8 status) internal pure returns (string memory) {
        if (status == 0) return "Created";
        if (status == 1) return "Open";
        if (status == 2) return "Closed";
        if (status == 3) return "Snapshot";
        if (status == 4) return "VRF Requested";
        if (status == 5) return "Distributed";
        return "Unknown";
    }
}
