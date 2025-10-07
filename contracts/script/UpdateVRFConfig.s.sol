// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PepedawnRaffle.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract UpdateVRFConfigScript is Script {
    function run() external {
        // Deprecated: manual gas updates removed in favor of dynamic estimation.
        console.log("No-op: Gas config is now dynamic. This script is kept for reference.");
    }
}
