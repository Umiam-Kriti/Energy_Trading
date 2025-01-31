// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CombinedP2PEnergyTrading {
    struct Participant {
    bool isProducer;
    bool isRegistered;
    bool isActive;
    uint8 group;
    uint256 energyBalance;
    int256 balance;
    uint256 lastPaymentDate;
    uint256[24] sellingPrices;
    uint256[24] buyingPrices;
    uint256[24] generation;
    uint256[24] consumption;
}

    mapping(address => Participant) public participants;
    mapping(uint8 => mapping(uint8 => address[])) private groupParticipants;

    // State variable to store sorted buyers for the day
    mapping(uint8 => address[]) public sortedBuyersForDay;

    // Event to signal that buyers have been sorted for the day
    event BuyersSorted(uint8 group, address[] sortedBuyers);

    // Function to set sorted buyers for the day (called by off-chain service)
    function setSortedBuyersForDay(uint8 group, address[] calldata sortedBuyers) external onlyOwner {
        sortedBuyersForDay[group] = sortedBuyers;
        emit BuyersSorted(group, sortedBuyers);
    }

    uint8 public currentHour;
    uint256[24] public unmatchedConsumptionPrice;
    uint256[24] public unmatchedGenerationReward;
    address public owner;
    uint256 public constant service_rate = 5550;
    uint256 public lastBillingCycle;
    uint256 public constant giga = 1000000000;

    event ParticipantRegistered(address indexed participant, uint8 group, bool isProducer);
    event TradeExecuted(address indexed seller, address indexed buyer, uint8 hour, uint256 amount, uint256 price);
    event UnmatchedConsumption(address indexed consumer, uint8 hour, uint256 amount, uint256 price);
    event UnmatchedGeneration(address indexed prosumer, uint8 hour, uint256 amount, uint256 price);
    event HourUpdated(uint8 newHour);
    event BalanceUpdated(address indexed participant, int256 change);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BillingCycleReset();
    event ParticipantDeactivated(address indexed participant);
    event ParticipantDataUpdated(address indexed participant);
    event NeedSorting(uint256 hour, uint8 group, address[] people, bool); // Updated event to include seller/buyer lists

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveParticipant() {
        require(participants[msg.sender].isActive, "Participant is not active");
        _;
    }

    modifier onlyEditHours() {
        require(currentHour >= 22 || currentHour < 6, "Can edit prices only from 10 PM to 6 AM");
        _;
    }

    constructor() {
        owner = msg.sender;
        initializeDefaultPrices();
        lastBillingCycle = block.timestamp;
    }

    function initializeDefaultPrices() private {
        for (uint8 i = 0; i < 18; i++) {
            unmatchedGenerationReward[i] = 11100; // Price in GWei
        }
        unmatchedGenerationReward[18] = 11700;
        unmatchedGenerationReward[19] = 12200;
        unmatchedGenerationReward[20] = 12600;
        unmatchedGenerationReward[21] = 12600;
        unmatchedGenerationReward[22] = 12200;
        unmatchedGenerationReward[23] = 11700;

        unmatchedConsumptionPrice = [26300,25900,25900,25900,25900,25900,
        26300,25500,24800,24100,23300,22600,22600,
        23300,24100,24800,25500,26300,27600,28900,
        30000,30000,28900,27600];
    }

    function registerParticipant(uint8 group, bool isProducer) external {
        require(!participants[msg.sender].isRegistered, "Already registered");
        require(group >= 0 && group < 6, "Invalid group");
        
        uint256[24] memory zeroArray;
        participants[msg.sender] = Participant({
            isProducer: isProducer,
            isRegistered: true,
            energyBalance: 0,
            balance: 0,
            sellingPrices: zeroArray,
            buyingPrices: zeroArray,
            generation: zeroArray,
            consumption: zeroArray,
            group: group,
            isActive: true,
            lastPaymentDate: block.timestamp
        });
        
        groupParticipants[group][currentHour].push(msg.sender);
        emit ParticipantRegistered(msg.sender, group, isProducer);
    }

    function updateParticipantData(uint256[24] calldata _sellingPrices, uint256[24] calldata _buyingPrices) external onlyActiveParticipant onlyEditHours{
        Participant storage participant = participants[msg.sender];
        participant.sellingPrices = _sellingPrices;
        participant.buyingPrices = _buyingPrices;
        emit ParticipantDataUpdated(msg.sender);
    }

    function updateHour(uint8 newHour) external onlyOwner {
        require(newHour < 24, "Invalid hour");
        require(currentHour != newHour, "No update");
        currentHour = newHour;
        emit HourUpdated(newHour);
        
        if (currentHour == 0) {
            matchOrders(23);
        } else if (!((currentHour - 1) >= 1 && (currentHour - 1) < 6)) {
            matchOrders(currentHour - 1);
        } else {
            chargeUnmatched(currentHour - 1);
        }
    }

    function matchOrders(uint8 hour) internal {

    // Check if it's  a new day
    if (hour == 1) {
        // Emit NeedSorting event for buyers (only once per day)
        for (uint8 group = 0; group < 6; group++) {
            address[] memory buyers = groupParticipants[group][hour];
            emit NeedSorting(hour, group, buyers, true); // true indicates buyer sorting
        }
    }

    require(!(hour >= 18 || hour < 6), "No trading from 6PM to 6AM");

    // Emit NeedSorting event for sellers (every hour)
    for (uint8 group = 0; group < 6; group++) {
        address[] memory sellers = groupParticipants[group][hour];
        emit NeedSorting(hour, group, sellers, false); // false indicates seller sorting
    }
}

    function submitSortedAddresses(
        uint8 hour,
        uint8 group,
        address[] calldata sortedParticipants, // Can be sellers or buyers
        bool isBuyerSorting // Indicates whether this is for buyer sorting
    ) external onlyOwner {
        require(hour < 24, "Invalid hour");
        require(group >= 0 && group <= 5, "Invalid group");

        if (isBuyerSorting) {
            // Store sorted buyers for the day
            sortedBuyersForDay[group] = sortedParticipants;
            emit BuyersSorted(group, sortedParticipants); // Emit event for logging
        } else {
            // Use pre-sorted buyers for the day and match orders with sorted sellers
            address[] storage sortedBuyers = sortedBuyersForDay[group];
            require(sortedBuyers.length > 0, "Buyers not sorted for this group yet");
            matchOrdersInGroup(hour, group, sortedParticipants, sortedBuyers);
        }
    }

    function matchOrdersInGroup(uint8 hour, uint8 group, address[] memory sortedSellers, address[] memory sortedBuyers) internal {
        for (uint256 i = 0; i < sortedSellers.length; i++) {
            address sellerAddr = sortedSellers[i];
            Participant storage seller = participants[sellerAddr];
            
            if (!seller.isActive) continue;
            
            uint256 excess = seller.generation[hour] > seller.consumption[hour] ?
                seller.generation[hour] - seller.consumption[hour] : 0;
            
            if (excess == 0) continue;
            
            for (uint256 j = 0; j < sortedBuyers.length && excess > 0; j++) {
                excess = processMatch(sellerAddr, sortedBuyers[j], hour, group, excess, seller.sellingPrices[hour]);
            }
        }
        chargeUnmatched(hour);
    }

    function processMatch(
        address sellerAddr,
        address buyerAddr,
        uint8 hour,
        uint8 group,
        uint256 excess,
        uint256 sellingPrice
    ) internal returns (uint256) {
        Participant storage buyer = participants[buyerAddr];
        Participant storage seller = participants[sellerAddr];
    
        if (!buyer.isActive || buyer.group != group || buyer.consumption[hour] == 0 || buyer.buyingPrices[hour] < sellingPrice) {
            return excess;
        }
    
        uint256 needed = buyer.consumption[hour];
        uint256 matched = needed > excess ? excess : needed;
    
        if (matched == 0) return excess;
    
        buyer.consumption[hour] -= matched;
        seller.generation[hour] -= matched;

        if (sellerAddr != buyerAddr) {  // Only process payment if not self-matching
            uint256 totalPrice = matched * sellingPrice;
            uint256 commission = matched * service_rate;
            uint256 sellerRevenue = totalPrice - commission;
        
            updateBalance(buyerAddr, -int256(totalPrice));
            updateBalance(sellerAddr, int256(sellerRevenue));
        
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, sellingPrice);
        }else{
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, 0);
        }
    
        return excess - matched;
    }

    function chargeUnmatched(uint8 hour) internal {
        for (uint8 group = 1; group <= 6; group++) {
            address[] storage groupParticipantList = groupParticipants[group][hour];
            for (uint256 i = 0; i < groupParticipantList.length; i++) {
                address participantAddr = groupParticipantList[i];
                Participant storage p = participants[participantAddr];
                
                if (!p.isActive) continue;

                if (p.consumption[hour] > 0) {
                    uint256 unmatchedCost = p.consumption[hour] * unmatchedConsumptionPrice[hour];
                    updateBalance(participantAddr, -int256(unmatchedCost));
                    emit UnmatchedConsumption(participantAddr, hour, p.consumption[hour], unmatchedConsumptionPrice[hour]);
                } 
                if (p.isProducer&&p.generation[hour] > 0) {
                        uint256 reward = p.generation[hour] * unmatchedGenerationReward[hour];
                        updateBalance(participantAddr, int256(reward));
                        emit UnmatchedGeneration(participantAddr, hour,p.generation[hour], unmatchedGenerationReward[hour]);
                    
                }
            }
        }
    }

    function updateBalance(address participant, int256 change) internal {
        if (change > 0) {
            participants[participant].balance -= int256(change);
        } 
        emit BalanceUpdated(participant, change);
    }

    function setUnmatchedPrices(uint256[24] calldata _consumptionPrices, uint256[24] calldata _generationRewards) external onlyOwner {
        unmatchedConsumptionPrice = _consumptionPrices;
        unmatchedGenerationReward = _generationRewards;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function resetBillingCycle() external onlyOwner {
        require(block.timestamp >= lastBillingCycle + 30 days, "Billing cycle not complete");
    
        for (uint8 group = 0; group < 6; group++) {
            for (uint8 hour = 0; hour < 24; hour++) {
                address[] storage participantsInGroup = groupParticipants[group][hour];
                for (uint256 i = 0; i < participantsInGroup.length; i++) {
                    address participantAddr = participantsInGroup[i];
                    Participant storage p = participants[participantAddr];
                
                    if (p.balance>0) {
                        if (block.timestamp >= p.lastPaymentDate + 14 days) {
                            p.balance = p.balance * 120 / 100; // 20% penalty for late payment
                            p.isActive = false;
                            emit ParticipantDeactivated(participantAddr);
                        }
                    }
                }
            }
        }
    
        lastBillingCycle = block.timestamp;
        emit BillingCycleReset();
    }

    function payBill() external payable {
        Participant storage participant = participants[msg.sender];
        if (participant.balance >0){
        require(msg.value > uint256(participant.balance) * 80/100 * giga, "Payment amount must be greater than 80%");
    }
        
        uint256 paymentAmount = msg.value/giga;
        participant.balance -= int256(paymentAmount);
        participant.lastPaymentDate = block.timestamp;

        participant.isActive = true;
        
        emit BalanceUpdated(msg.sender, -int256(paymentAmount));
    }

    function withdrawProsumerBalance(address prosumer) external onlyOwner {
        Participant storage participant = participants[prosumer];
        require(participant.isActive && participant.isProducer, "Invalid prosumer");
        require(participant.balance < 0, "No balance to withdraw");
        
        int256 amount = -1*(participant.balance);
        participant.balance = 0;
        payable(prosumer).transfer(uint256(amount)*giga);
        emit BalanceUpdated(prosumer, int256(amount));
    }
}
