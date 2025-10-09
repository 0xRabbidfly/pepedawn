// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    uint256 private _nextTokenId = 1;
    
    constructor() ERC721("TestPrizePack", "TEST") {}
    
    function mint(address to, uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            _safeMint(to, _nextTokenId);
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

