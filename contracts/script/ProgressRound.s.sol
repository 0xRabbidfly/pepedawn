// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PepedawnRaffle.sol";

contract ProgressRoundScript is Script {
    PepedawnRaffle public raffle;
    
    function run() external {
        // Load contract address from environment
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        raffle = PepedawnRaffle(contractAddress);
        
        console.log("=== PROGRESSING ROUND TO COMPLETION ===");
        
        uint256 currentRoundId = raffle.currentRoundId();
        console.log("Current Round ID:", currentRoundId);
        
        if (currentRoundId == 0) {
            console.log("No round exists. Creating new round...");
            raffle.createRound();
            console.log("Round created successfully!");
            vm.stopBroadcast();
            return;
        }
        
        // Get current round status
        PepedawnRaffle.Round memory round = raffle.getRound(currentRoundId);
        uint8 status = uint8(round.status);
        console.log("Current Status:", getStatusName(status));
        
        if (status == 2) { // Closed - need to snapshot
            console.log("Taking snapshot...");
            raffle.snapshotRound(currentRoundId);
            console.log("Snapshot taken successfully!");
            
            // Update status for next check
            round = raffle.getRound(currentRoundId);
            status = uint8(round.status);
        }
        
        if (status == 3) { // Snapshot - need VRF request
            console.log("Requesting VRF...");
            raffle.requestVRF(currentRoundId);
            console.log("VRF requested successfully!");
            console.log("Waiting for Chainlink VRF response...");
        }
        
        if (status == 4) { // VRF Requested
            console.log("Round is waiting for VRF response from Chainlink.");
            console.log("This may take a few minutes. Once VRF responds, prizes will be distributed automatically.");
        }
        
        if (status == 5) { // Distributed
            console.log("Round completed! Creating new round...");
            raffle.createRound();
            
            uint256 newRoundId = raffle.currentRoundId();
            console.log("New round created! Round ID:", newRoundId);
            
            console.log("Opening new round...");
            raffle.openRound(newRoundId);
            console.log("Round", newRoundId, "is now open for betting!");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== SUMMARY ===");
        console.log("Contract should now be in a good state.");
        console.log("Refresh your frontend to see the updated state.");
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
