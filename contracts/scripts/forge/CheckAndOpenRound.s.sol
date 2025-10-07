// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/PepedawnRaffle.sol";

contract CheckAndOpenRoundScript is Script {
    
    function run() external {
        // Load contract address and private key from environment
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        PepedawnRaffle raffle = PepedawnRaffle(contractAddress);
        
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
        PepedawnRaffle.Round memory round = raffle.getRound(currentRoundId);
        
        console.log("=== Round", currentRoundId, "Status ===");
        console.log("Status:", uint8(round.status)); // 0=Created, 1=Open, 2=Closed, etc.
        console.log("Start Time:", round.startTime);
        console.log("End Time:", round.endTime);
        console.log("Total Tickets:", round.totalTickets);
        console.log("Participants:", round.participantCount);
        
        // If round is Created (status 0), open it
        if (round.status == PepedawnRaffle.RoundStatus.Created) {
            console.log("Round is in Created status. Opening round...");
            
            vm.startBroadcast(deployerPrivateKey);
            raffle.openRound(currentRoundId);
            vm.stopBroadcast();
            
            console.log("Round", currentRoundId, "is now OPEN for betting!");
        } else if (round.status == PepedawnRaffle.RoundStatus.Open) {
            console.log("Round", currentRoundId, "is already OPEN for betting!");
        } else {
            console.log("Round", currentRoundId, "is in status:", uint8(round.status));
            console.log("Status meanings: 0=Created, 1=Open, 2=Closed, 3=Snapshot, 4=VRFRequested, 5=Distributed, 6=Refunded");
        }
        
        console.log("=== Frontend Integration ===");
        console.log("Contract Address for frontend:", contractAddress);
        console.log("Current Round ID:", currentRoundId);
        console.log("Check your frontend is using the correct contract address and network (Sepolia)");
    }
}
