// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title MockVRFCoordinatorV2Plus
 * @notice Mock VRF Coordinator v2.5 for testing purposes
 * @dev Simulates Chainlink VRF v2.5 behavior without requiring network connection
 */
contract MockVRFCoordinatorV2Plus is IVRFCoordinatorV2Plus {
    uint256 private _requestIdCounter = 1;
    mapping(uint256 => address) private _requestIdToConsumer;
    mapping(uint256 => VRFV2PlusClient.RandomWordsRequest) private _requests;
    
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );
    
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint256 subId,
        uint96 payment,
        bool nativePayment,
        bool success
    );

    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata req
    ) external override returns (uint256 requestId) {
        requestId = _requestIdCounter++;
        _requestIdToConsumer[requestId] = msg.sender;
        _requests[requestId] = req;
        
        emit RandomWordsRequested(
            req.keyHash,
            requestId,
            0, // preSeed
            req.subId,
            req.requestConfirmations,
            req.callbackGasLimit,
            req.numWords,
            req.extraArgs,
            msg.sender
        );
        
        return requestId;
    }

    /**
     * @notice Manually fulfill a VRF request (for testing)
     * @param requestId The request ID to fulfill
     * @param randomWords The random words to return
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        address consumer = _requestIdToConsumer[requestId];
        require(consumer != address(0), "Request not found");
        
        // Call the consumer's fulfillRandomWords function
        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );
        
        emit RandomWordsFulfilled(
            requestId,
            randomWords[0],
            _requests[requestId].subId,
            0, // payment
            false, // nativePayment
            success
        );
    }

    /**
     * @notice Create a subscription (mock implementation)
     */
    function createSubscription() external override returns (uint256 subId) {
        return uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp)));
    }

    /**
     * @notice Get subscription details (mock implementation)
     */
    function getSubscription(uint256) 
        external 
        pure 
        override 
        returns (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address subOwner,
            address[] memory consumers
        ) 
    {
        balance = 1000 ether;
        nativeBalance = 0;
        reqCount = 0;
        subOwner = address(0);
        consumers = new address[](0);
    }

    /**
     * @notice Accept subscription ownership transfer (mock implementation)
     */
    function acceptSubscriptionOwnerTransfer(uint256) external pure override {
        // Mock implementation
    }

    /**
     * @notice Remove consumer from subscription (mock implementation)
     */
    function removeConsumer(uint256, address) external pure override {
        // Mock implementation
    }

    /**
     * @notice Cancel subscription (mock implementation)
     */
    function cancelSubscription(uint256, address) external pure override {
        // Mock implementation
    }

    /**
     * @notice Add consumer to subscription (mock implementation)
     */
    function addConsumer(uint256, address) external pure override {
        // Mock implementation
    }

    /**
     * @notice Fund subscription with native tokens (mock implementation)
     */
    function fundSubscriptionWithNative(uint256) external payable override {
        // Mock implementation
    }

    /**
     * @notice Request subscription ownership transfer (mock implementation)
     */
    function requestSubscriptionOwnerTransfer(uint256, address) external pure override {
        // Mock implementation
    }

    /**
     * @notice Get pending subscription owner (mock implementation)
     */
    function pendingRequestExists(uint256) external pure override returns (bool) {
        return false;
    }

    /**
     * @notice Get request commitment (mock implementation)  
     */
    function s_requestCommitments(uint256) external pure returns (bytes32) {
        return bytes32(0);
    }

    /**
     * @notice Get active subscription IDs (mock implementation)
     */
    function getActiveSubscriptionIds(uint256, uint256) 
        external 
        pure 
        override 
        returns (uint256[] memory) 
    {
        return new uint256[](0);
    }
}

