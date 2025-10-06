// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/PepedawnRaffle.sol";

contract TestDeployScript is Script {
    function run() external {
        // Use test addresses and values for deployment
        address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625; // Sepolia VRF
        uint64 subscriptionId = 1; // Mock subscription ID
        bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; // Sepolia key hash
        address creatorsAddress = address(0x1234); // Mock creators address
        address emblemVaultAddress = address(0x5678); // Mock vault address
        
        // Use a default private key for testing (you'll need to replace this)
        uint256 deployerPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        
        vm.startBroadcast(deployerPrivateKey);
        
        PepedawnRaffle raffle = new PepedawnRaffle(
            vrfCoordinator,
            subscriptionId,
            keyHash,
            creatorsAddress,
            emblemVaultAddress
        );
        
        vm.stopBroadcast();
        
        console.log("PepedawnRaffle deployed to:", address(raffle));
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("Subscription ID:", subscriptionId);
        console.log("Key Hash:", uint256(keyHash));
    }
}

