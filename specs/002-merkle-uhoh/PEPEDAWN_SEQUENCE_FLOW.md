sequenceDiagram
    participant User as User/Participant
    participant Frontend as Frontend (pepedawn.art)
    participant Contract as PepedawnRaffle Contract
    participant VRF as Chainlink VRF Coordinator
    participant EmblemVault as Emblem Vault (ERC1155)
    participant IPFS as IPFS (Pinata/Storage)
    participant Owner as Contract Owner
    participant OffChain as Off-Chain Bot

    Note over User, OffChain: Round Lifecycle - 2 Week Period

    %% Round Creation Phase
    Owner->>Contract: createRound()
    Contract->>Contract: Create new Round struct
    Owner->>Contract: setValidProof(roundId, proofHash)
    Owner->>Contract: openRound(roundId)
    Contract->>Contract: Set status = Open, startTime = now, endTime = now + 2 weeks

    %% Participation Phase (2 weeks)
    loop During 2-week window
        User->>Frontend: Connect wallet (MetaMask)
        Frontend->>Contract: buyTickets(tickets) + ETH value
        Contract->>Contract: Validate round is open
        Contract->>Contract: Check wallet cap, participant limits
        Contract->>Contract: Store wager, update round totals
        Contract->>Contract: Emit TicketsPurchased event
        
        User->>Frontend: Submit puzzle proof
        Frontend->>Contract: submitProof(proofHash)
        Contract->>Contract: Validate proof matches validProofHash
        Contract->>Contract: Store proof, apply 40% weight multiplier
        Contract->>Contract: Emit ProofSubmitted event
    end

    %% Round Closure Phase
    Owner->>Contract: closeRound(roundId)
    Contract->>Contract: Set status = Closed
    Owner->>Contract: snapshotRound(roundId)
    Contract->>Contract: Set status = Snapshot, freeze participant data
    Owner->>Contract: commitParticipantsRoot(roundId, merkleRoot, ipfsCid)
    Contract->>Contract: Store participantsRoot and IPFS CID

    %% VRF Request Phase
    Owner->>Contract: requestVrf(roundId)
    Contract->>Contract: Validate round status and participants
    Contract->>Contract: Estimate callback gas (250k + 25% + 15% buffers)
    Contract->>VRF: requestRandomWords(keyHash, subId, confirmations, callbackGasLimit)
    VRF-->>Contract: Return requestId
    Contract->>Contract: Set status = VRFRequested, store requestId
    Contract->>Contract: Emit VRFRequested event

    %% VRF Fulfillment Phase (External)
    VRF->>Contract: rawFulfillRandomWords(requestId, randomWords)
    Contract->>Contract: Validate caller is VRF coordinator
    Contract->>Contract: Find round by requestId
    Contract->>Contract: Store VRF seed for reproducibility
    Contract->>Contract: Set status = WinnersReady
    Contract->>Contract: Emit VRFCompleted event

    %% Off-Chain Winner Computation
    OffChain->>IPFS: Fetch participants data
    IPFS-->>OffChain: Return participants JSON
    OffChain->>OffChain: Compute winners using VRF seed + Merkle tree
    OffChain->>OffChain: Generate winners Merkle tree
    OffChain->>IPFS: Upload winners JSON file
    IPFS-->>OffChain: Return IPFS CID

    %% Winner Submission Phase
    OffChain->>Contract: submitWinnersRoot(roundId, merkleRoot, ipfsCid)
    Contract->>Contract: Validate round status = WinnersReady
    Contract->>Contract: Store winnersRoot and IPFS CID
    Contract->>Contract: Set status = Distributed
    Contract->>Contract: Emit WinnersReady event

    %% Prize Distribution Phase
    Owner->>EmblemVault: safeTransferFrom(owner, contract, tokenId, amount)
    EmblemVault-->>Contract: Transfer ERC1155 NFTs to contract
    Contract->>Contract: Store prize inventory

    %% Prize Claiming Phase
    User->>Frontend: Check if winner
    Frontend->>Contract: isWinner(roundId, user, prizeIndex, tier, proof)
    Contract->>Contract: Verify Merkle proof against winnersRoot
    Contract-->>Frontend: Return true/false
    
    alt User is winner
        User->>Frontend: Claim prize
        Frontend->>Contract: claimPrize(roundId, prizeIndex, tier, proof)
        Contract->>Contract: Verify Merkle proof again
        Contract->>Contract: Check prize not already claimed
        Contract->>EmblemVault: safeTransferFrom(contract, user, tokenId, 1)
        EmblemVault-->>User: Transfer ERC1155 NFT to winner
        Contract->>Contract: Mark prize as claimed
        Contract->>Contract: Emit PrizeClaimed event
    end

    %% Fee Distribution (Internal)
    Contract->>Contract: Calculate 80% to creators, 20% to next round
    Contract->>Contract: Transfer ETH to creatorsAddress
    Contract->>Contract: Store next round fees

    %% Refund Phase (if insufficient participants)
    alt Round has < 10 tickets
        User->>Frontend: Request refund
        Frontend->>Contract: withdrawRefund()
        Contract->>Contract: Check refund balance
        Contract->>User: Transfer refund ETH
        Contract->>Contract: Reset refund balance
    end

    Note over User, OffChain: Round Complete - Ready for Next Round