// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/PepedawnRaffle.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Sepolia VRF Configuration
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        address creatorsAddress = vm.envAddress("CREATORS_ADDRESS");
        address emblemVaultAddress = vm.envAddress("EMBLEM_VAULT_ADDRESS");
        
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
    }
}
