// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PepedawnRaffle.sol";

contract CheckAndOpenRoundScript is Script {
    address constant SEPOLIA_CONTRACT = 0xBa8E7795682A6d0A05F805aD45258E3d4641BFFc;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        PepedawnRaffle raffle = PepedawnRaffle(SEPOLIA_CONTRACT);
        
        console.log("=== Contract State Check ===");
        console.log("Contract Address:", address(raffle));
        console.log("Current Round ID:", raffle.currentRoundId());
        
        uint256 currentRoundId = raffle.currentRoundId();
        
        if (currentRoundId == 0) {
            console.log("No rounds exist. Creating first round...");
            
            vm.startBroadcast(deployerPrivateKey);
            raffle.createRound();
            vm.stopBroadcast();
            
            currentRoundId = 1;
            console.log("Round 1 created!");
        }
        
        // Check current round status
        (
            uint256 id,
            uint64 startTime,
            uint64 endTime,
            PepedawnRaffle.RoundStatus status,
            uint256 totalTickets,
            uint256 totalWeight,
            uint256 totalWagered,
            uint256 vrfRequestId,
            uint64 vrfRequestedAt,
            bool feesDistributed,
            uint256 participantCount
        ) = raffle.rounds(currentRoundId);
        
        console.log("=== Round", currentRoundId, "Status ===");
        console.log("Status:", uint8(status)); // 0=Created, 1=Open, 2=Closed, etc.
        console.log("Start Time:", startTime);
        console.log("End Time:", endTime);
        console.log("Total Tickets:", totalTickets);
        console.log("Participants:", participantCount);
        
        // If round is Created (status 0), open it
        if (status == PepedawnRaffle.RoundStatus.Created) {
            console.log("Round is in Created status. Opening round...");
            
            vm.startBroadcast(deployerPrivateKey);
            raffle.openRound(currentRoundId);
            vm.stopBroadcast();
            
            console.log("Round", currentRoundId, "is now OPEN for betting!");
        } else if (status == PepedawnRaffle.RoundStatus.Open) {
            console.log("Round", currentRoundId, "is already OPEN for betting!");
        } else {
            console.log("Round", currentRoundId, "is in status:", uint8(status));
            console.log("Status meanings: 0=Created, 1=Open, 2=Closed, 3=Snapshot, 4=VRFRequested, 5=Distributed");
        }
        
        console.log("=== Frontend Integration ===");
        console.log("Contract Address for frontend:", SEPOLIA_CONTRACT);
        console.log("Current Round ID:", currentRoundId);
        console.log("Check your frontend is using the correct contract address and network (Sepolia)");
    }
}
