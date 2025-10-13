// Contract configuration for PepedawnRaffle deployment
// Last updated: 2025-10-08T06:00:00.000Z
// Deployed on: Sepolia Testnet
// 
// NOTE: This ABI includes Merkle claims system functions.
// If you need to update the ABI, run: cd contracts && forge build
// Then copy from: contracts/out/PepedawnRaffle.sol/PepedawnRaffle.json

export const VERSION = 'v0.5.1';

export const CONTRACT_CONFIG = {
  // Contract address from latest deployment with binary search optimization
  address: "0x5ab6CB57C0806B91e7dCC7043fcAc3196a5eD9B0", // Deployed on 2025-02-06 - Binary search optimization
  
  // Network configuration (automatically updated by update-contract-address.js)
  network: 'sepolia',
  chainId: 11155111,
  
  // Development mode - automatically determined from chainId (no manual update needed!)
  get DEV_MODE() { return this.chainId !== 1; },  // false for mainnet (chainId: 1), true for testnets
  
  // Latest ABI for PepedawnRaffle contract with binary search and enhanced security features
  abi: [
    {
      "type": "constructor",
      "inputs": [
        {
          "name": "_vrfCoordinator",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_subscriptionId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "_keyHash",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "_creatorsAddress",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_emblemVaultAddress",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "fallback",
      "stateMutability": "payable"
    },
    {
      "type": "receive",
      "stateMutability": "payable"
    },
    {
      "type": "function",
      "name": "BUNDLE_10_PRICE",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "BUNDLE_5_PRICE",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "CREATORS_FEE_PCT",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "DEPLOYMENT_TIMESTAMP",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "FAKE_PACK_TIER",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "KEK_PACK_TIER",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "MAX_GAS_PRICE",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "MAX_PARTICIPANTS_PER_ROUND",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "MAX_TOTAL_WAGER_PER_ROUND",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "MIN_TICKETS_FOR_DISTRIBUTION",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "MIN_WAGER",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "NEXT_ROUND_FEE_PCT",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "PEPE_PACK_TIER",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "PROOF_MULTIPLIER",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "ROUND_DURATION",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VERSION",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VRF_MAX_CALLBACK_GAS",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint32",
          "internalType": "uint32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VRF_MIN_CALLBACK_GAS",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint32",
          "internalType": "uint32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VRF_REQUEST_TIMEOUT",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VRF_SAFETY_BUFFER_PCT",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint32",
          "internalType": "uint32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "VRF_VOLATILITY_BUFFER_PCT",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint32",
          "internalType": "uint32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "WALLET_CAP",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "acceptOwnership",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "buyTickets",
      "inputs": [
        {
          "name": "tickets",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "payable"
    },
    {
      "type": "function",
      "name": "claim",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "prizeIndex",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "prizeTier",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "proof",
          "type": "bytes32[]",
          "internalType": "bytes32[]"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "claimCounts",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "claims",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "closeRound",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "commitParticipantsRoot",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "root",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "cid",
          "type": "string",
          "internalType": "string"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "createRound",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "creatorsAddress",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "currentRoundId",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "denylisted",
      "inputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "emblemVault",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract IERC721"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "emblemVaultAddress",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "emergencyPaused",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "emergencyWithdrawETH",
      "inputs": [
        {
          "name": "to",
          "type": "address",
          "internalType": "address payable"
        },
        {
          "name": "amount",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "emergencyWithdrawNFT",
      "inputs": [
        {
          "name": "nftContract",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "tokenId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "estimateVrfCallbackGas",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint32",
          "internalType": "uint32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getClaimStatus",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "prizeIndex",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "outputs": [
        {
          "name": "claimer",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "claimed",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getParticipantsData",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "root",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "cid",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRefundBalance",
      "inputs": [
        {
          "name": "user",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "balance",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRound",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "tuple",
          "internalType": "struct PepedawnRaffle.Round",
          "components": [
            {
              "name": "id",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "startTime",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "endTime",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "status",
              "type": "uint8",
              "internalType": "enum PepedawnRaffle.RoundStatus"
            },
            {
              "name": "totalTickets",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "totalWeight",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "totalWagered",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "vrfRequestId",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "vrfRequestedAt",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "feesDistributed",
              "type": "bool",
              "internalType": "bool"
            },
            {
              "name": "participantCount",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "validProofHash",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "participantsRoot",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "winnersRoot",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "vrfSeed",
              "type": "bytes32",
              "internalType": "bytes32"
            }
          ]
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRoundParticipants",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "address[]",
          "internalType": "address[]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRoundState",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "round",
          "type": "tuple",
          "internalType": "struct PepedawnRaffle.Round",
          "components": [
            {
              "name": "id",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "startTime",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "endTime",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "status",
              "type": "uint8",
              "internalType": "enum PepedawnRaffle.RoundStatus"
            },
            {
              "name": "totalTickets",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "totalWeight",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "totalWagered",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "vrfRequestId",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "vrfRequestedAt",
              "type": "uint64",
              "internalType": "uint64"
            },
            {
              "name": "feesDistributed",
              "type": "bool",
              "internalType": "bool"
            },
            {
              "name": "participantCount",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "validProofHash",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "participantsRoot",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "winnersRoot",
              "type": "bytes32",
              "internalType": "bytes32"
            },
            {
              "name": "vrfSeed",
              "type": "bytes32",
              "internalType": "bytes32"
            }
          ]
        },
        {
          "name": "participantsCount",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "winnersCount",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "prizesClaimed",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "prizeTokenIds",
          "type": "uint256[10]",
          "internalType": "uint256[10]"
        },
        {
          "name": "prizeClaimers",
          "type": "address[10]",
          "internalType": "address[10]"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getRoundWinners",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "tuple[]",
          "internalType": "struct PepedawnRaffle.WinnerAssignment[]",
          "components": [
            {
              "name": "roundId",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "wallet",
              "type": "address",
              "internalType": "address"
            },
            {
              "name": "prizeTier",
              "type": "uint8",
              "internalType": "uint8"
            },
            {
              "name": "vrfRequestId",
              "type": "uint256",
              "internalType": "uint256"
            },
            {
              "name": "blockNumber",
              "type": "uint256",
              "internalType": "uint256"
            }
          ]
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getUserStats",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "user",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "wagered",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "tickets",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "weight",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "hasProof",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getWinnersData",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "root",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "cid",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isParticipant",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isWinner",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "user",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "prizeIndex",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "prizeTier",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "proof",
          "type": "bytes32[]",
          "internalType": "bytes32[]"
        }
      ],
      "outputs": [
        {
          "name": "valid",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "lastVrfRequestTime",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "nextRoundFunds",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "onERC721Received",
      "inputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "bytes",
          "internalType": "bytes"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bytes4",
          "internalType": "bytes4"
        }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "openRound",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "owner",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "participantsCIDs",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "pause",
      "inputs": [
        {
          "name": "reason",
          "type": "string",
          "internalType": "string"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "pauseReason",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "paused",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "prizeNFTs",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "uint8",
          "internalType": "uint8"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "rawFulfillRandomWords",
      "inputs": [
        {
          "name": "requestId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "randomWords",
          "type": "uint256[]",
          "internalType": "uint256[]"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "refunds",
      "inputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "requestVrf",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "roundParticipants",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "roundWinners",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "wallet",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "prizeTier",
          "type": "uint8",
          "internalType": "uint8"
        },
        {
          "name": "vrfRequestId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "blockNumber",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "rounds",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "id",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "startTime",
          "type": "uint64",
          "internalType": "uint64"
        },
        {
          "name": "endTime",
          "type": "uint64",
          "internalType": "uint64"
        },
        {
          "name": "status",
          "type": "uint8",
          "internalType": "enum PepedawnRaffle.RoundStatus"
        },
        {
          "name": "totalTickets",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "totalWeight",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "totalWagered",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "vrfRequestId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "vrfRequestedAt",
          "type": "uint64",
          "internalType": "uint64"
        },
        {
          "name": "feesDistributed",
          "type": "bool",
          "internalType": "bool"
        },
        {
          "name": "participantCount",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "validProofHash",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "participantsRoot",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "winnersRoot",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "vrfSeed",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "s_vrfCoordinator",
      "inputs": [],
      "outputs": [
        {
          "name": "",
          "type": "address",
          "internalType": "contract IVRFCoordinatorV2Plus"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "setCoordinator",
      "inputs": [
        {
          "name": "_vrfCoordinator",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setDenylistStatus",
      "inputs": [
        {
          "name": "wallet",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "isDenylisted",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setEmergencyPause",
      "inputs": [
        {
          "name": "paused",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setPrizesForRound",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "tokenIds",
          "type": "uint256[]",
          "internalType": "uint256[]"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "setValidProof",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "proofHash",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "snapshotRound",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "submitProof",
      "inputs": [
        {
          "name": "proofHash",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "submitWinnersRoot",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "winnersRoot",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "ipfsHash",
          "type": "string",
          "internalType": "string"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "transferOwnership",
      "inputs": [
        {
          "name": "to",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "unpause",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "updateCreatorsAddress",
      "inputs": [
        {
          "name": "_creatorsAddress",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "updateEmblemVaultAddress",
      "inputs": [
        {
          "name": "_emblemVaultAddress",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "updateVrfConfig",
      "inputs": [
        {
          "name": "_coordinator",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "_subscriptionId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "_keyHash",
          "type": "bytes32",
          "internalType": "bytes32"
        }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "userHasProofInRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "bool",
          "internalType": "bool"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "userProofInRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "wallet",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "roundId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "proofHash",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "verified",
          "type": "bool",
          "internalType": "bool"
        },
        {
          "name": "submittedAt",
          "type": "uint64",
          "internalType": "uint64"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "userTicketsInRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "userWageredInRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "userWeightInRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "",
          "type": "address",
          "internalType": "address"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "vrfConfig",
      "inputs": [],
      "outputs": [
        {
          "name": "coordinator",
          "type": "address",
          "internalType": "contract IVRFCoordinatorV2Plus"
        },
        {
          "name": "subscriptionId",
          "type": "uint256",
          "internalType": "uint256"
        },
        {
          "name": "keyHash",
          "type": "bytes32",
          "internalType": "bytes32"
        },
        {
          "name": "callbackGasLimit",
          "type": "uint32",
          "internalType": "uint32"
        },
        {
          "name": "requestConfirmations",
          "type": "uint16",
          "internalType": "uint16"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "vrfRequestToRound",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "winnersCIDs",
      "inputs": [
        {
          "name": "",
          "type": "uint256",
          "internalType": "uint256"
        }
      ],
      "outputs": [
        {
          "name": "",
          "type": "string",
          "internalType": "string"
        }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "withdrawRefund",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "AddressDenylisted",
      "inputs": [
        {
          "name": "wallet",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "denylisted",
          "type": "bool",
          "indexed": false,
          "internalType": "bool"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "CircuitBreakerTriggered",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "reason",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ContractPausedWithReason",
      "inputs": [
        {
          "name": "reason",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        },
        {
          "name": "timestamp",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "CoordinatorSet",
      "inputs": [
        {
          "name": "vrfCoordinator",
          "type": "address",
          "indexed": false,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "DirectETHReceived",
      "inputs": [
        {
          "name": "sender",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "amount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "EmblemVaultPrizeAssigned",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "winner",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "assetId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "timestamp",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "EmergencyPauseToggled",
      "inputs": [
        {
          "name": "paused",
          "type": "bool",
          "indexed": false,
          "internalType": "bool"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "EmergencyWithdrawal",
      "inputs": [
        {
          "name": "to",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "amount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "assetType",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "FeesDistributed",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "creators",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "creatorsAmount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "nextRoundAmount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OwnershipTransferRequested",
      "inputs": [
        {
          "name": "from",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OwnershipTransferred",
      "inputs": [
        {
          "name": "from",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "to",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ParticipantRefunded",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "participant",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "amount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ParticipantsRootCommitted",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "root",
          "type": "bytes32",
          "indexed": false,
          "internalType": "bytes32"
        },
        {
          "name": "cid",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Paused",
      "inputs": [
        {
          "name": "account",
          "type": "address",
          "indexed": false,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "PrizeClaimed",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "winner",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "prizeIndex",
          "type": "uint8",
          "indexed": false,
          "internalType": "uint8"
        },
        {
          "name": "prizeTier",
          "type": "uint8",
          "indexed": false,
          "internalType": "uint8"
        },
        {
          "name": "emblemVaultTokenId",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "PrizeDistributed",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "winner",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "prizeTier",
          "type": "uint8",
          "indexed": false,
          "internalType": "uint8"
        },
        {
          "name": "assetId",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "PrizesSet",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "tokenIds",
          "type": "uint256[]",
          "indexed": false,
          "internalType": "uint256[]"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ProofRejected",
      "inputs": [
        {
          "name": "wallet",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "proofHash",
          "type": "bytes32",
          "indexed": false,
          "internalType": "bytes32"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ProofSubmitted",
      "inputs": [
        {
          "name": "wallet",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "proofHash",
          "type": "bytes32",
          "indexed": false,
          "internalType": "bytes32"
        },
        {
          "name": "newWeight",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RefundWithdrawn",
      "inputs": [
        {
          "name": "user",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "amount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundClosed",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundCreated",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "startTime",
          "type": "uint64",
          "indexed": false,
          "internalType": "uint64"
        },
        {
          "name": "endTime",
          "type": "uint64",
          "indexed": false,
          "internalType": "uint64"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundOpened",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundPrizesDistributed",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "winnerCount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "timestamp",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundRefunded",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "participantCount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "totalRefunded",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "RoundSnapshot",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "totalTickets",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "totalWeight",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "SecurityValidationFailed",
      "inputs": [
        {
          "name": "user",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "reason",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Unpaused",
      "inputs": [
        {
          "name": "account",
          "type": "address",
          "indexed": false,
          "internalType": "address"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "VRFFulfilled",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "requestId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "randomWords",
          "type": "uint256[]",
          "indexed": false,
          "internalType": "uint256[]"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "VRFRequested",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "requestId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "VRFTimeoutDetected",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "requestId",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "ValidProofSet",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "validProofHash",
          "type": "bytes32",
          "indexed": false,
          "internalType": "bytes32"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "WagerPlaced",
      "inputs": [
        {
          "name": "wallet",
          "type": "address",
          "indexed": true,
          "internalType": "address"
        },
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "amount",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "tickets",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        },
        {
          "name": "effectiveWeight",
          "type": "uint256",
          "indexed": false,
          "internalType": "uint256"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "WinnersAssigned",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "winners",
          "type": "address[]",
          "indexed": false,
          "internalType": "address[]"
        },
        {
          "name": "prizeTiers",
          "type": "uint8[]",
          "indexed": false,
          "internalType": "uint8[]"
        }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "WinnersCommitted",
      "inputs": [
        {
          "name": "roundId",
          "type": "uint256",
          "indexed": true,
          "internalType": "uint256"
        },
        {
          "name": "root",
          "type": "bytes32",
          "indexed": false,
          "internalType": "bytes32"
        },
        {
          "name": "cid",
          "type": "string",
          "indexed": false,
          "internalType": "string"
        }
      ],
      "anonymous": false
    },
    {
      "type": "error",
      "name": "EnforcedPause",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ExpectedPause",
      "inputs": []
    },
    {
      "type": "error",
      "name": "OnlyCoordinatorCanFulfill",
      "inputs": [
        {
          "name": "have",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "want",
          "type": "address",
          "internalType": "address"
        }
      ]
    },
    {
      "type": "error",
      "name": "OnlyOwnerOrCoordinator",
      "inputs": [
        {
          "name": "have",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "owner",
          "type": "address",
          "internalType": "address"
        },
        {
          "name": "coordinator",
          "type": "address",
          "internalType": "address"
        }
      ]
    },
    {
      "type": "error",
      "name": "ReentrancyGuardReentrantCall",
      "inputs": []
    },
    {
      "type": "error",
      "name": "ZeroAddress",
      "inputs": []
    }
  ]
};

// VRF Configuration from deployment artifacts
export const VRF_CONFIG = {
  "coordinator": "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
  "subscriptionId": 1,
  "keyHash": "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
  "callbackGasLimit": 500000,
  "requestConfirmations": 5
};

// Network-specific settings
export const NETWORKS = {
  sepolia: {
    name: 'Sepolia Testnet',
    chainId: 11155111,
    rpcUrl: 'https://sepolia.infura.io/v3/',
    blockExplorer: 'https://sepolia.etherscan.io'
  },
  mainnet: {
    name: 'Ethereum Mainnet',
    chainId: 11155111,
    rpcUrl: 'https://mainnet.infura.io/v3/',
    blockExplorer: 'https://etherscan.io'
  }
};

// Security configuration for enhanced contract interaction
export const SECURITY_CONFIG = {
  // Network validation
  NETWORK_NAMES: {
    11155111: 'Sepolia',
    1: 'Ethereum Mainnet'
  },
  
  // Contract interaction limits
  MAX_RETRY_ATTEMPTS: 3,
  REQUEST_TIMEOUT: 30000, // 30 seconds
  
  // Security features
  ENABLE_PAUSE_CHECK: true,
  ENABLE_NETWORK_VALIDATION: true
};

// Helper function to validate contract configuration
export function validateContractConfig() {
  if (CONTRACT_CONFIG.address === "0x0000000000000000000000000000000000000000") {
    console.warn("⚠️ Contract address not set! Please update CONTRACT_CONFIG.address with your deployed contract address.");
    return false;
  }
  
  if (!CONTRACT_CONFIG.address.startsWith('0x') || CONTRACT_CONFIG.address.length !== 42) {
    console.error("❌ Invalid contract address format!");
    return false;
  }
  
  console.log("✅ Contract configuration valid:", CONTRACT_CONFIG.address);
  return true;
}

// Validate network compatibility
export function validateNetwork(chainId) {
  const numericChainId = Number(chainId);
  
  if (!SECURITY_CONFIG.NETWORK_NAMES[numericChainId]) {
    const error = `Unsupported network: ${numericChainId}`;
    console.error("❌", error);
    throw new Error(error);
  }
  
  const networkName = SECURITY_CONFIG.NETWORK_NAMES[numericChainId];
  console.log(`✅ Connected to ${networkName} (${numericChainId})`);
  return true;
}

// Input sanitization for security
export function sanitizeInput(input, type) {
  if (typeof input !== 'string') {
    throw new Error(`Invalid ${type}: must be a string`);
  }
  
  // Remove potentially dangerous characters
  const sanitized = input
    .replace(/[<>'"&]/g, '') // Remove HTML/script injection characters
    .trim() // Remove leading/trailing whitespace
    .substring(0, 1000); // Limit length
  
  if (sanitized.length === 0) {
    throw new Error(`Invalid ${type}: cannot be empty`);
  }
  
  return sanitized;
}

// Rate limiting for user actions
const rateLimitMap = new Map();
export function checkRateLimit(userAddress) {
  const now = Date.now();
  const windowMs = 60000; // 1 minute window
  const maxRequests = 10; // Max requests per window
  
  if (!rateLimitMap.has(userAddress)) {
    rateLimitMap.set(userAddress, []);
  }
  
  const userRequests = rateLimitMap.get(userAddress);
  
  // Remove old requests outside the window
  const validRequests = userRequests.filter(time => now - time < windowMs);
  
  if (validRequests.length >= maxRequests) {
    throw new Error('Rate limit exceeded. Please wait before making another request.');
  }
  
  // Add current request
  validRequests.push(now);
  rateLimitMap.set(userAddress, validRequests);
}

// Validate contract security state
export async function validateSecurityState(contract, userAddress) {
  if (!contract) {
    throw new Error('Contract not available');
  }
  
  try {
  // Check if contract is paused
    const isPaused = await contract.paused();
    if (isPaused) {
      throw new Error('Contract is currently paused');
    }
    
    // Check if emergency pause is active
    const isEmergencyPaused = await contract.emergencyPaused();
    if (isEmergencyPaused) {
      throw new Error('Contract is in emergency pause mode');
    }
    
    // Check if user is denylisted (if function exists)
    try {
      const isDenylisted = await contract.denylisted(userAddress);
      if (isDenylisted) {
        throw new Error('Your address is not allowed to interact with this contract');
      }
  } catch {
      // Function might not exist, ignore this check
      console.log('Denylist check not available');
    }
    
    console.log('✅ Security validation passed');
    return true;
    
  } catch (error) {
    console.error('❌ Security validation failed:', error.message);
    throw error;
  }
}