// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract P2PEnergyTrading {
    struct Participant {
        uint128[24] sellingPrices;
        uint128[24] buyingPrices;
        uint128[24] generation;
        uint128[24] consumption;
        uint8 group;
        bool isProsumer;
        bool exists;
    }

    struct MatchParams {
        uint8 hour;
        uint8 group;
        uint128 excess;
        uint128 sellingPrice;
    }

    mapping(address => Participant) public participants;
    address[] public participantAddresses;
    
    uint8 public currentHour;
    uint128[24] public unmatchedConsumptionPrice;
    uint128[24] public unmatchedGenerationReward;
    address public owner;

    event NeedSorting(uint256 hour, uint8 group);
    event ParticipantRegistered(address indexed participant, uint8 group, bool isProsumer);
    event TradeExecuted(address indexed seller, address indexed buyer, uint8 hour, uint128 amount, uint128 price);
    event UnmatchedConsumption(address indexed consumer, uint8 hour, uint128 amount, uint128 price);
    event UnmatchedGeneration(address indexed prosumer, uint8 hour, uint256 amount, uint256 price);

    event HourUpdated(uint8 newHour);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier onlyEditHours() {
        require(currentHour >= 22 || currentHour <= 5, "Can edit prices only from 10 PM to 6 AM");
        _;
    }

    constructor() {
        owner = msg.sender;
        initializeDefaultPrices();
    }

    function initializeDefaultPrices() private {
        for (uint8 i = 0; i < 18; i++) {
            unmatchedGenerationReward[i] = 11100000000000;
        }
        unmatchedGenerationReward[18] = 11700000000000;
        unmatchedGenerationReward[19] = 12200000000000;
        unmatchedGenerationReward[20] = 12600000000000;
        unmatchedGenerationReward[21] = 12600000000000;
        unmatchedGenerationReward[22] = 12200000000000;
        unmatchedGenerationReward[23] = 11700000000000;

        unmatchedConsumptionPrice = [26300000000000,25900000000000,25900000000000,25900000000000,25900000000000,25900000000000,
        26300000000000,25500000000000,24800000000000,24100000000000,23300000000000,22600000000000,22600000000000,
        23300000000000,24100000000000,24800000000000,25500000000000,26300000000000,27600000000000,28900000000000,
        30000000000000,30000000000000,28900000000000,27600000000000];
    }

    function registerParticipant(uint8 group, bool isProsumer) external {
        require(!participants[msg.sender].exists, "Already registered");
        require(group >= 1 && group <= 6, "Invalid group");
        
        Participant storage newParticipant = participants[msg.sender];
        newParticipant.group = group;
        newParticipant.isProsumer = isProsumer;
        newParticipant.exists = true;
        
        participantAddresses.push(msg.sender);
        emit ParticipantRegistered(msg.sender, group, isProsumer);
    }

    function updateParticipantData(uint128[24] calldata _sellingPrices, uint128[24] calldata _buyingPrices) external onlyEditHours {
        Participant storage participant = participants[msg.sender];
        require(participant.exists, "Participant not registered");
        
        for (uint8 i = 0; i < 24; i++) {
            if (participant.sellingPrices[i] != _sellingPrices[i]) {
                participant.sellingPrices[i] = _sellingPrices[i];
            }
            if (participant.buyingPrices[i] != _buyingPrices[i]) {
                participant.buyingPrices[i] = _buyingPrices[i];
            }
        }
    }

    function updateHour(uint8 newHour) external onlyOwner {
        require(newHour < 24, "Invalid hour");
        currentHour = newHour;
        emit HourUpdated(newHour);
        
        if (currentHour >= 6 || currentHour == 0) {
            matchOrders(currentHour);
            chargeUnmatched(currentHour);
        }
    }
    
    function matchOrders(uint8 hour) internal {
        require(hour < 24, "Invalid hour");

        for (uint8 group = 1; group <= 6; group++) {
            emit NeedSorting(hour, group);
        }
    }

    function submitSortedAddresses(
        uint256 hour,
        uint8 group,
        address[] calldata sortedSellers,
        address[] calldata sortedBuyers
    ) external onlyOwner {
        require(hour < 24, "Invalid hour");
        require(group >= 1 && group <= 6, "Invalid group");

        matchOrdersWithSortedAddresses(uint8(hour), group, sortedSellers, sortedBuyers);
    }

    function matchOrdersWithSortedAddresses(
        uint8 hour,
        uint8 group,
        address[] memory sortedSellers,
        address[] memory sortedBuyers
    ) internal {
        for (uint256 i = 0; i < sortedSellers.length; i++) {
            address sellerAddr = sortedSellers[i];
            Participant storage seller = participants[sellerAddr];
            
            if (seller.group != group) continue;
            
            uint128 excess = 0;
            if (seller.generation[hour] > seller.consumption[hour]) {
                excess = seller.generation[hour] - seller.consumption[hour];
            }
            
            if (excess == 0) continue;
            
            for (uint256 j = 0; j < sortedBuyers.length && excess > 0; j++) {
                excess = processMatch(
                    sellerAddr,
                    sortedBuyers[j],
                    hour,
                    group,
                    excess,
                    seller.sellingPrices[hour]
                );
            }
        }
    }

    function processMatch(
        address sellerAddr,
        address buyerAddr,
        uint8 hour,
        uint8 group,
        uint128 excess,
        uint128 sellingPrice
    ) internal returns (uint128) {
        Participant storage buyer = participants[buyerAddr];
        
        if (buyer.group != group || buyer.consumption[hour] == 0 || buyer.buyingPrices[hour] < sellingPrice) {
            return excess;
        }
        
        uint128 needed = buyer.consumption[hour];
        uint128 matched = needed > excess ? excess : needed;
        
        if (matched == 0) return excess;
        
        buyer.consumption[hour] -= matched;
        
        emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, sellingPrice);
        
        return excess - matched;
    }

    function chargeUnmatched(uint8 hour) internal {
    for (uint256 i = 0; i < participantAddresses.length; i++) {
        address participantAddr = participantAddresses[i];
        Participant storage p = participants[participantAddr];
        
        if (!p.isProsumer && p.consumption[hour] > 0) {
            emit UnmatchedConsumption(participantAddr, hour, p.consumption[hour], unmatchedConsumptionPrice[hour]);
        } else if (p.isProsumer) {
            uint256 unmatchedGeneration = 0;
            if (p.generation[hour] > p.consumption[hour]) {
                unmatchedGeneration = p.generation[hour] - p.consumption[hour];
            }
            
            if (unmatchedGeneration > 0) {
                emit UnmatchedGeneration(participantAddr, hour, unmatchedGeneration, unmatchedGenerationReward[hour]);
            }
        }
    }
}

    function setUnmatchedPrices(uint128[24] calldata _consumptionPrices, uint128[24] calldata _generationRewards) external onlyOwner {
        unmatchedConsumptionPrice = _consumptionPrices;
        unmatchedGenerationReward = _generationRewards;
    }

    function getParticipantCount() external view returns (uint256) {
        return participantAddresses.length;
    }
}
