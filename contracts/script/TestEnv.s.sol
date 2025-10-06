// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

contract TestEnvScript is Script {
    function run() external {
        try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
            console.log("PRIVATE_KEY found, length:", privateKey);
        } catch {
            console.log("PRIVATE_KEY not found");
        }
        
        try vm.envAddress("VRF_COORDINATOR") returns (address vrfCoord) {
            console.log("VRF_COORDINATOR found:", vrfCoord);
        } catch {
            console.log("VRF_COORDINATOR not found");
        }
        
        try vm.envUint("VRF_SUBSCRIPTION_ID") returns (uint256 subId) {
            console.log("VRF_SUBSCRIPTION_ID found:", subId);
        } catch {
            console.log("VRF_SUBSCRIPTION_ID not found");
        }
    }
}

