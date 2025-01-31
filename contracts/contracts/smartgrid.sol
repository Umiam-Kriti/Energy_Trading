// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OptimizedP2PEnergyTrading is Ownable, ReentrancyGuard {

    address public Owner;
    address[] public registeredUserAddresses;

    constructor() Ownable(msg.sender) ReentrancyGuard() {
        Owner=msg.sender;
        initializeDefaultPrices();
        lastBillingCycle = block.timestamp;
    }

    using SafeMath for uint256;

    struct Participant {
        bool isProducer;
        bool isRegistered;
        bool isActive;
        uint256 group;
        uint256 energyBalance;
        int256 balance;
        uint256 lastPaymentDate;
        uint256[24] sellingPrices;
        uint256[24] buyingPrices;
        uint256[24] generation;
        uint256[24] consumption;
    }

    mapping(address => Participant) public participants;
    mapping(uint256 => address[]) private groupParticipants;
    mapping(uint256 => address[]) public sortedBuyersForDay;

    uint256 public currentHour;
    uint256[24] public unmatchedConsumptionPrice;
    uint256[24] public unmatchedGenerationReward;
    uint256 public constant SERVICE_RATE = 56;
    uint256 public lastBillingCycle;
    uint256 public constant GIGA = 1e9;

    event ParticipantRegistered(address indexed participant, uint256 group, bool isProducer);
    event TradeExecuted(address indexed seller, address indexed buyer, uint256 hour, uint256 amount, uint256 price);
    event UnmatchedConsumption(address indexed consumer, uint256 hour, uint256 amount, uint256 price);
    event UnmatchedGeneration(address indexed prosumer, uint256 hour, uint256 amount, uint256 price);
    event HourUpdated(uint256 newHour);
    event BalanceUpdated(address indexed participant, int256 change);
    event BillingCycleReset();
    event ParticipantDeactivated(address indexed participant);
    event ParticipantDataUpdated(address indexed participant);
    event NeedSorting(uint256 hour, uint256 group, address[] people, bool isBuyer);
    event BuyersSorted(uint256 group, address[] sortedBuyers);
    event MQTTDataReceived(address indexed participant, uint256 hour, uint256 generation, uint256 consumption);

    error NotAuthorized();
    error ParticipantNotActive();
    error InvalidEditHours();
    error AlreadyRegistered();
    error InvalidGroup();
    error InvalidHour();
    error NoUpdate();
    error InvalidPrice();
    error InsufficientPayment();
    error NoProsumerBalance();

    modifier onlyActiveParticipant() {
        if (!participants[msg.sender].isActive) revert ParticipantNotActive();
        _;
    }

    modifier onlyEditHours() {
        if (currentHour < 22 && currentHour >= 6) revert InvalidEditHours();
        _;
    }

    function initializeDefaultPrices() private {
        for (uint8 i = 0; i < 18; i++) {
            unmatchedGenerationReward[i] = 111; // Price in GWei per 0.01 units
        }
        unmatchedGenerationReward[18] = 117;
        unmatchedGenerationReward[19] = 122;
        unmatchedGenerationReward[20] = 126;
        unmatchedGenerationReward[21] = 126;
        unmatchedGenerationReward[22] = 122;
        unmatchedGenerationReward[23] = 117;

        unmatchedConsumptionPrice = [263,259,259,259,259,259,
        263,255,248,241,233,226,226,
        233,241,248,255,263,276,289,
        300,300,289,276];
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
    
    groupParticipants[group].push(msg.sender);
    registeredUserAddresses.push(msg.sender);
    emit ParticipantRegistered(msg.sender, group, isProducer);
    }

    function getAllRegisteredUsers() public view returns (address[] memory) {
        return registeredUserAddresses;
    }

    function updateParticipantData(uint256[24] calldata _sellingPrices, uint256[24] calldata _buyingPrices) external onlyActiveParticipant onlyEditHours {
        Participant storage participant = participants[msg.sender];
        participant.sellingPrices = _sellingPrices;
        participant.buyingPrices = _buyingPrices;
        emit ParticipantDataUpdated(msg.sender);
    }

    function updateHour(uint256 newHour) external onlyOwner {
        if (newHour >= 24) revert InvalidHour();
        if (currentHour == newHour) revert NoUpdate();
        currentHour = newHour;
        emit HourUpdated(newHour);
        
        if (currentHour == 0) {
            matchOrders(23);
        } else if (currentHour <= 1 || currentHour >= 6) {
            matchOrders(currentHour.sub(1));
        } else {
            chargeUnmatched(currentHour.sub(1));
        }
    }

    function matchOrders(uint256 hour) internal {
        if (hour == 1) {
            for (uint256 group = 0; group < 6; group++) {
                address[] memory buyers = groupParticipants[group];
                emit NeedSorting(hour, group, buyers, true);
            }
        }

        if (hour >= 18 || hour < 6) revert InvalidHour();

        for (uint256 group = 0; group < 6; group++) {
            address[] memory sellers = groupParticipants[group];
            emit NeedSorting(hour, group, sellers, false);
        }
    }

    function submitSortedAddresses(
        uint256 hour,
        uint256 group,
        address[] calldata sortedParticipants,
        bool isBuyerSorting
    ) external onlyOwner {
        if (hour >= 24) revert InvalidHour();
        if (group >= 6) revert InvalidGroup();

        if (isBuyerSorting) {
            sortedBuyersForDay[group] = sortedParticipants;
            emit BuyersSorted(group, sortedParticipants);
        } else {
            address[] storage sortedBuyers = sortedBuyersForDay[group];
            require(sortedBuyers.length > 0, "Buyers not sorted for this group yet");
            matchOrdersInGroup(hour, group, sortedParticipants, sortedBuyers);
        }
    }

    function matchOrdersInGroup(uint256 hour, uint256 group, address[] memory sortedSellers, address[] memory sortedBuyers) internal {
        for (uint256 i = 0; i < sortedSellers.length; i++) {
            address sellerAddr = sortedSellers[i];
            Participant storage seller = participants[sellerAddr];
            
            if (!seller.isActive) continue;
            
            uint256 excess = seller.generation[hour] > seller.consumption[hour] ?
                seller.generation[hour].sub(seller.consumption[hour]) : 0;
            
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
        uint256 hour,
        uint256 group,
        uint256 excess,
        uint256 sellingPrice
    ) internal returns (uint256) {
        if (sellerAddr == buyerAddr) {
            return excess;
        }

        Participant storage buyer = participants[buyerAddr];
        Participant storage seller = participants[sellerAddr];
    
        if (!buyer.isActive || buyer.group != group || buyer.consumption[hour] == 0 || buyer.buyingPrices[hour] < sellingPrice) {
            return excess;
        }
    
        uint256 needed = buyer.consumption[hour];
        uint256 matched = needed > excess ? excess : needed;
    
        if (matched == 0) return excess;
    
        buyer.consumption[hour] = buyer.consumption[hour].sub(matched);
        seller.generation[hour] = seller.generation[hour].sub(matched);

        if (sellerAddr != buyerAddr) {  // Only process payment if not self-matching
            uint256 totalPrice = matched.mul(sellingPrice);
            uint256 commission = matched.mul(SERVICE_RATE);
            uint256 sellerRevenue = totalPrice.sub(commission);
        
            updateBalance(buyerAddr, -int256(totalPrice));
            updateBalance(sellerAddr, int256(sellerRevenue));
        
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, sellingPrice);
        }else{
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, 0);
        }

        return excess.sub(matched);
    }

    function chargeUnmatched(uint256 hour) internal {
        for (uint256 group = 0; group < 6; group++) {
            address[] storage groupParticipantList = groupParticipants[group];
            for (uint256 i = 0; i < groupParticipantList.length; i++) {
                address participantAddr = groupParticipantList[i];
                Participant storage p = participants[participantAddr];
                
                if (!p.isActive) continue;

                if (p.consumption[hour] > 0) {
                    uint256 unmatchedCost = p.consumption[hour].mul(unmatchedConsumptionPrice[hour]);
                    updateBalance(participantAddr, -int256(unmatchedCost));
                    emit UnmatchedConsumption(participantAddr, hour, p.consumption[hour], unmatchedConsumptionPrice[hour]);
                } 
                if (p.isProducer && p.generation[hour] > 0) {
                    uint256 reward = p.generation[hour].mul(unmatchedGenerationReward[hour]);
                    updateBalance(participantAddr, int256(reward));
                    emit UnmatchedGeneration(participantAddr, hour, p.generation[hour], unmatchedGenerationReward[hour]);
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

    function resetBillingCycle() external onlyOwner {
        require(block.timestamp >= lastBillingCycle + 30 days, "Billing cycle not complete");
    
        for (uint8 group = 0; group < 6; group++) {
            for (uint8 hour = 0; hour < 24; hour++) {
                address[] storage participantsInGroup = groupParticipants[group];
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
        require(msg.value > uint256(participant.balance) * 80/100 * GIGA, "Payment amount must be greater than 80%");
    }
        
        uint256 paymentAmount = msg.value/GIGA;
        participant.balance -= int256(paymentAmount);
        participant.lastPaymentDate = block.timestamp;

        participant.isActive = true;
        
        emit BalanceUpdated(msg.sender, -int256(paymentAmount));
    }

    function withdrawProsumerBalance(address prosumer) external onlyOwner nonReentrant {
        Participant storage participant = participants[prosumer];
        if (!participant.isActive || !participant.isProducer || participant.balance >= 0) revert NoProsumerBalance();
        
        int256 amount = -participant.balance;
        participant.balance = 0;
        payable(prosumer).transfer(uint256(amount).mul(GIGA));
        emit BalanceUpdated(prosumer, amount);
    }

    function updateEnergyData(address _userAddress, uint256 _generation, uint256 _consumption) external onlyOwner {
    require(participants[_userAddress].isRegistered, "User not registered");
    require(participants[_userAddress].isActive, "User not active");

    uint256 hour = currentHour-1;
    participants[_userAddress].generation[hour] = _generation;
    participants[_userAddress].consumption[hour] = _consumption;

    emit MQTTDataReceived(_userAddress, hour, _generation, _consumption);
}
}


