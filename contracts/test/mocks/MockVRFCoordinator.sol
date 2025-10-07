// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title MockVRFCoordinator
 * @notice Mock VRF Coordinator for testing purposes
 * @dev Simulates Chainlink VRF behavior without requiring network connection
 */
contract MockVRFCoordinator is VRFCoordinatorV2Interface {
    uint256 private _requestIdCounter = 1;
    mapping(uint256 => address) private _requestIdToConsumer;
    
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint64 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        address indexed sender
    );
    
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);

    function getRequestConfig()
        external
        pure
        override
        returns (
            uint16,
            uint32,
            bytes32[] memory
        )
    {
        bytes32[] memory keyHashes = new bytes32[](1);
        keyHashes[0] = keccak256("test");
        return (3, 2000000, keyHashes);
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external override returns (uint256 requestId) {
        requestId = _requestIdCounter++;
        _requestIdToConsumer[requestId] = msg.sender;
        
        emit RandomWordsRequested(
            keyHash,
            requestId,
            0, // preSeed
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords,
            msg.sender
        );
        
        return requestId;
    }

    function createSubscription() external override returns (uint64 subId) {
        return 1; // Mock subscription ID
    }

    function getSubscription(uint64)
        external
        pure
        override
        returns (
            uint96 balance,
            uint64 reqCount,
            address owner,
            address[] memory consumers
        )
    {
        address[] memory mockConsumers = new address[](0);
        return (1000 * 10**18, 0, address(0), mockConsumers); // Mock 1000 LINK balance
    }

    function requestSubscriptionOwnerTransfer(uint64, address) external pure override {
        // Mock implementation - do nothing
    }

    function acceptSubscriptionOwnerTransfer(uint64) external pure override {
        // Mock implementation - do nothing
    }

    function addConsumer(uint64, address) external pure override {
        // Mock implementation - do nothing
    }

    function removeConsumer(uint64, address) external pure override {
        // Mock implementation - do nothing
    }

    function cancelSubscription(uint64, address) external pure override {
        // Mock implementation - do nothing
    }

    function pendingRequestExists(uint64) external pure override returns (bool) {
        return false; // No pending requests in mock
    }

    /**
     * @notice Manually fulfill a VRF request for testing
     * @param requestId The request ID to fulfill
     * @param randomWords Array of random words to return
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        address consumer = _requestIdToConsumer[requestId];
        require(consumer != address(0), "Invalid request ID");
        
        // Call the consumer's fulfillRandomWords function
        (bool success,) = consumer.call(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        
        emit RandomWordsFulfilled(requestId, randomWords[0], 0, success);
    }
}
