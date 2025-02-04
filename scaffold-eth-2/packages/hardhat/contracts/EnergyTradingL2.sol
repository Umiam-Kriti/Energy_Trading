// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract EnergyTradingL2 is Ownable, ReentrancyGuard {

    address public Owner;
    address[] public registeredUserAddresses;

    constructor() Ownable(msg.sender) ReentrancyGuard() {
        Owner=msg.sender;
        initializeDefaultPrices();
        lastBillingCycle = block.timestamp;
    }

    struct Participant {
        bool isProducer;
        bool isRegistered;
        bool isActive;
        bool isStorage;
        uint256 group;
        uint256 energyBalance;
        int256 balance;
        uint256 lastPaymentDate;
        uint256 storedEnergy;
        uint256 criticalLoad; // in 0.01 kW
        uint256[24] sellingPrices;
        uint256[24] buyingPrices;
        uint256[24] generation;
        uint256[24] consumption;
    }

    struct StoredEnergyOrder {
        uint256 id;
        address trader;
        uint256 price;
        uint256 quantity;
        OrderType orderType;
        bool isActive;
        uint256 group;
    }

    enum OrderType { Buy, Sell }

    struct BatchStoreTrade {
        address buyer;
        address seller;
        uint256 price;
        uint256 quantity;
    }

    mapping(address => Participant) public participants;
    mapping(uint256 => address[]) private groupParticipants;
    mapping(uint256 => address[]) public sortedBuyersForDay;
    mapping(uint256 => mapping(uint256 => string)) public groupCIDs; // group => hour => CID
    mapping(uint256 => mapping(uint256 => bytes32)) public merkleRoots; // group => hour => root
    mapping(uint256 => StoredEnergyOrder) public storedEnergyOrders;
    mapping(uint256 => uint256[]) public groupBuyOrders;    // group => orderIds
    mapping(uint256 => uint256[]) public groupSellOrders;   // group => orderIds

    uint256 public nextOrderId = 1;

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
    event BatchEnergyDataUpdated(uint256 indexed group, uint256 indexed hour, uint256 batchSize);
    event GroupGeneration(uint256 indexed group, uint256 indexed hour, uint256 groupgen);
    event GroupConsumption(uint256 indexed group, uint256 indexed hour, uint256 groupcon);
    event CIDStored(uint256 indexed group, uint256 indexed hour, string cid);
    event StoredEnergyTradeSettled(address indexed buyer, address indexed seller, uint256 quantity, uint256 price);
    event StoredEnergyOrderPlaced(uint256 indexed id, address indexed trader, uint256 group, uint256 price, uint256 quantity, OrderType orderType);
    event StoredEnergyOrderMatched(uint256 indexed buyOrderId, uint256 indexed sellOrderId, address buyer, address seller, uint256 matchedPrice, uint256 matchedQuantity);
    event StoredEnergyOrderCancelled(uint256 indexed id);

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
    error NoStorage();

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

    function registerParticipant(uint8 group, bool isProducer, bool loob, uint256 pcLoad) external {
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
        lastPaymentDate: block.timestamp,
        isStorage: loob,
        storedEnergy: 0,
        criticalLoad: pcLoad
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

    function placeStoredEnergyOrder(uint256 price, uint256 quantity, OrderType orderType) external onlyActiveParticipant {
        require(price > 0 && quantity > 0, "Invalid order parameters");
        Participant storage participant = participants[msg.sender];
        uint256 group = participant.group;

        if (orderType == OrderType.Sell) {
            require(participant.storedEnergy >= quantity, "Insufficient stored energy");
            participant.storedEnergy -= quantity;
        } else {
            require(participant.balance >= int256(price * quantity), "Insufficient balance");
            participant.energyBalance += quantity;
        }

        uint256 orderId = nextOrderId++;
        storedEnergyOrders[orderId] = StoredEnergyOrder({
            id: orderId,
            trader: msg.sender,
            price: price,
            quantity: quantity,
            orderType: orderType,
            isActive: true,
            group: group
        });

        if (orderType == OrderType.Buy) {
            matchStoredEnergyBuyOrder(orderId);
            if (storedEnergyOrders[orderId].isActive) {
                groupBuyOrders[group].push(orderId);
            }
        } else {
            matchStoredEnergySellOrder(orderId);
            if (storedEnergyOrders[orderId].isActive) {
                groupSellOrders[group].push(orderId);
            }
        }

        emit StoredEnergyOrderPlaced(orderId, msg.sender, group, price, quantity, orderType);
    }

    function matchStoredEnergyBuyOrder(uint256 buyOrderId) internal {
        StoredEnergyOrder storage buyOrder = storedEnergyOrders[buyOrderId];
        uint256 group = buyOrder.group;
        
        uint256[] storage groupSells = groupSellOrders[group];
        for (uint256 i = 0; i < groupSells.length && buyOrder.isActive; i++) {
            StoredEnergyOrder storage sellOrder = storedEnergyOrders[groupSells[i]];
            
            if(!sellOrder.isActive || buyOrder.price != sellOrder.price) continue;
            
            uint256 matchedQuantity = min(buyOrder.quantity, sellOrder.quantity);
            uint256 matchedPrice = sellOrder.price;
            
            processStoredEnergyMatch(buyOrder, sellOrder, matchedQuantity, matchedPrice);
            
            if (sellOrder.quantity == 0) {
                sellOrder.isActive = false;
                removeOrder(groupSellOrders[group], i);
                i--;
            }
        }
    }

    function matchStoredEnergySellOrder(uint256 sellOrderId) internal {
        StoredEnergyOrder storage sellOrder = storedEnergyOrders[sellOrderId];
        uint256 group = sellOrder.group;
        
        uint256[] storage groupBuys = groupBuyOrders[group];
        for (uint256 i = 0; i < groupBuys.length && sellOrder.isActive; i++) {
            StoredEnergyOrder storage buyOrder = storedEnergyOrders[groupBuys[i]];
            
            if (!buyOrder.isActive || buyOrder.price != sellOrder.price) continue;
            
            uint256 matchedQuantity = min(buyOrder.quantity, sellOrder.quantity);
            uint256 matchedPrice = sellOrder.price;
            
            processStoredEnergyMatch(buyOrder, sellOrder, matchedQuantity, matchedPrice);
            
            if (buyOrder.quantity == 0) {
                buyOrder.isActive = false;
                removeOrder(groupBuyOrders[group], i);
                i--;
            }
        }
    }

    function processStoredEnergyMatch(
        StoredEnergyOrder storage buyOrder,
        StoredEnergyOrder storage sellOrder,
        uint256 matchedQuantity,
        uint256 matchedPrice
    ) internal {
        uint256 totalPrice = matchedQuantity * matchedPrice;
        uint256 commission = totalPrice * SERVICE_RATE ;
        uint256 sellerRevenue = totalPrice - commission;
        
        participants[buyOrder.trader].storedEnergy += matchedQuantity;
        updateBalance(buyOrder.trader, -int256(totalPrice));
        updateBalance(sellOrder.trader, int256(sellerRevenue));
        
        buyOrder.quantity -= matchedQuantity;
        sellOrder.quantity -= matchedQuantity;
        
        emit StoredEnergyOrderMatched(
            buyOrder.id,
            sellOrder.id,
            buyOrder.trader,
            sellOrder.trader,
            matchedPrice,
            matchedQuantity
        );
    }

    function cancelStoredEnergyOrder(uint256 orderId) external {
        StoredEnergyOrder storage order = storedEnergyOrders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order not active");

        order.isActive = false;
        uint256 group = order.group;

        if (order.orderType == OrderType.Buy) {
            removeOrder(groupBuyOrders[group], findOrderIndex(groupBuyOrders[group], orderId));
            participants[msg.sender].energyBalance -= order.quantity;
        } else {
            removeOrder(groupSellOrders[group], findOrderIndex(groupSellOrders[group], orderId));
            participants[msg.sender].storedEnergy += order.quantity;
        }

        emit StoredEnergyOrderCancelled(orderId);
    }
    

    // function to store energy from generation
    function storeEnergy(uint256 amount) external onlyActiveParticipant {
        require(participants[msg.sender].generation[currentHour] >= amount, 
            "Insufficient generation");
        
        participants[msg.sender].generation[currentHour] -= amount;
        participants[msg.sender].storedEnergy += amount;
    }


    function updateHour(uint256 newHour) external onlyOwner {
        if (newHour >= 24) revert InvalidHour();
        if (currentHour == newHour) revert NoUpdate();
        currentHour = newHour;
        emit HourUpdated(newHour);
    }

    function matchOrders(uint256 hour, uint256 group) internal {
        if (hour == 1) {
                address[] memory buyers = groupParticipants[group];
                emit NeedSorting(hour, group, buyers, true);
        }

            address[] memory sellers = groupParticipants[group];
            emit NeedSorting(hour, group, sellers, false);
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
                seller.generation[hour] - (seller.consumption[hour]) : 0;
            
            if (excess == 0) continue;
            
            for (uint256 j = 0; j < sortedBuyers.length && excess > 0; j++) {
                excess = processMatch(sellerAddr, sortedBuyers[j], hour, group, excess, seller.sellingPrices[hour]);
            }
        }
        chargeUnmatched(hour,group);
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
    
        uint256 needed = buyer.consumption[hour] > buyer.energyBalance ? buyer.consumption[hour] - (buyer.energyBalance): 0;
        buyer.energyBalance=buyer.energyBalance > buyer.consumption[hour] ? buyer.energyBalance - (buyer.consumption[hour]): 0;
        uint256 matched = needed > excess ? excess : needed;
    
        if (matched == 0) return excess;
    
        buyer.consumption[hour] = buyer.consumption[hour] - (matched);
        seller.generation[hour] = seller.generation[hour] - (matched);

        if (sellerAddr != buyerAddr) {  // Only process payment if not self-matching
            uint256 totalPrice = matched * (sellingPrice);
            uint256 commission = matched * (SERVICE_RATE);
            uint256 sellerRevenue = totalPrice - (commission);
        
            updateBalance(buyerAddr, -int256(totalPrice));
            updateBalance(sellerAddr, int256(sellerRevenue));
        
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, sellingPrice);
        }else{
            emit TradeExecuted(sellerAddr, buyerAddr, hour, matched, 0);
        }

        return excess - (matched);
    }

    function chargeUnmatched(uint256 hour, uint256 group) internal {
            address[] storage groupParticipantList = groupParticipants[group];
            for (uint256 i = 0; i < groupParticipantList.length; i++) {
                address participantAddr = groupParticipantList[i];
                Participant storage p = participants[participantAddr];
                
                if (!p.isActive) continue;

                if (p.consumption[hour] > 0) {
                    uint256 unmatchedCost = p.consumption[hour] * (unmatchedConsumptionPrice[hour]);
                    updateBalance(participantAddr, -int256(unmatchedCost));
                    emit UnmatchedConsumption(participantAddr, hour, p.consumption[hour], unmatchedConsumptionPrice[hour]);
                } 
                if (p.isProducer && p.generation[hour] > 0) {
                    uint256 reward = p.generation[hour] * (unmatchedGenerationReward[hour]);
                    updateBalance(participantAddr, int256(reward));
                    emit UnmatchedGeneration(participantAddr, hour, p.generation[hour], unmatchedGenerationReward[hour]);
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
        payable(prosumer).transfer(uint256(amount) * (GIGA));
        emit BalanceUpdated(prosumer, amount);
    }

    function storeEnergyCID(
        uint256 _group,
        uint256 _hour,
        string calldata _cid
    ) external onlyOwner {
        require(_group < 6, "Invalid group");
        require(_hour < 24, "Invalid hour");
        require(bytes(_cid).length >= 46, "Invalid CID format");
    
        groupCIDs[_group][_hour] = _cid;
        emit CIDStored(_group, _hour, _cid);
    }

    function getEnergyCID(uint256 _group, uint256 _hour) external view returns (string memory) {
    require(_group < 6, "Invalid group");
    require(_hour < 24, "Invalid hour");
    
    return groupCIDs[_group][_hour];
}

    struct EnergyData {
        address userAddress;
        uint256 generation;
        uint256 consumption;
    }

    function updateEnergyDataBatch(uint256 _group, EnergyData[] calldata _batchData) external onlyOwner {
        require(_group < 6, "Invalid group");
        require(_batchData.length > 0, "Empty batch");
        
        uint256 hour = currentHour > 0 ? currentHour - 1 : 23;

        uint256 gg=0;
        uint256 gc=0;
        
        for (uint256 i = 0; i < _batchData.length; i++) {
            address userAddress = _batchData[i].userAddress;
            require(participants[userAddress].isRegistered, "User not registered");
            require(participants[userAddress].isActive, "User not active");
            require(participants[userAddress].group == _group, "User not in specified group");
            
            participants[userAddress].generation[hour] = _batchData[i].generation;
            participants[userAddress].consumption[hour] = _batchData[i].consumption;

            gg+=_batchData[i].generation;
            gc+=_batchData[i].consumption;
        }
        
        if (currentHour == 0) {
            chargeUnmatched(23,_group);
        } else if (currentHour < 18 && currentHour >= 6) {
            matchOrders(hour,_group);
        } else {
            chargeUnmatched(hour,_group);
        }

        emit BatchEnergyDataUpdated(_group, hour, _batchData.length);
        emit GroupGeneration(_group, hour, gg);
        emit GroupConsumption(_group, hour, gc);
    }

    function findOrderIndex(uint256[] storage orderList, uint256 orderId) internal view returns (uint256) {
        for (uint256 i = 0; i < orderList.length; i++) {
            if (orderList[i] == orderId) return i;
        }
        revert("Order not found");
    }

    function removeOrder(uint256[] storage orderList, uint256 index) internal {
        require(index < orderList.length, "Invalid index");
        orderList[index] = orderList[orderList.length - 1];
        orderList.pop();
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function setMerkleRoot(
        uint256 group, 
        uint256 hour, 
        bytes32 root
    ) external onlyOwner {
        require(group < 6, "Invalid group");
        require(hour < 24, "Invalid hour");
        merkleRoots[group][hour] = root;
    }

    function verifyData(
        uint256 group,
        uint256 hour,
        address user,
        uint256 generation,
        uint256 consumption,
        bytes32[] calldata proof
    ) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, generation, consumption));
        return MerkleProof.verify(proof, merkleRoots[group][hour], leaf);
    }  
}
