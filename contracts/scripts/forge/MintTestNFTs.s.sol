// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestNFT is ERC1155 {
    uint256 private _nextTokenId = 1;
    
    constructor() ERC1155("https://test.emblem.vault/{id}.json") {}
    
    function mint(address to, uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            _mint(to, _nextTokenId, 1, ""); // mint 1 unit of each token ID
            _nextTokenId++;
        }
    }
}

contract MintTestNFTs is Script {
    function run() external {
        vm.startBroadcast();
        
        // Deploy test NFT contract
        TestNFT nft = new TestNFT();
        console.log("TestNFT deployed to:", address(nft));
        
        // Mint 10 NFTs to deployer
        nft.mint(msg.sender, 10);
        console.log("Minted 10 NFTs (IDs 1-10) to:", msg.sender);
        
        vm.stopBroadcast();
    }
}

