// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract P2PEnergyTrading {
    struct Participant {
        bool isProducer;
        uint256 energyBalance;
        uint256 balance;
        bool isRegistered;
    }

    struct Trade {
        address buyer;
        address seller;
        uint256 energyAmount;
        uint256 price;
    }

    enum OrderType { Buy, Sell }
    
    struct Order {
        uint id;
        address trader;
        uint price;
        uint quantity;
        OrderType orderType;
        bool isActive;
    }

    uint public nextOrderId = 1;
    mapping(uint => Order) public orders;
    uint[] public buyOrders;
    uint[] public sellOrders;

    event OrderPlaced(uint indexed id, address indexed trader, uint price, uint quantity, OrderType orderType);
    event OrderMatched(uint buyOrderId, uint sellOrderId, address indexed buyer, address indexed seller, uint matchedPrice, uint matchedQuantity);
    event OrderCancelled(uint indexed id);

    mapping(address => Participant) public participants;
    Trade[] public trades;

    event EnergyProduced(address indexed producer, uint256 amount);
    event EnergyConsumed(address indexed consumer, uint256 amount);

    // Register a participant as a producer or consumer
    function registerParticipant(bool _isProducer) external {
        require(!participants[msg.sender].isRegistered, "Participant already registered");
        participants[msg.sender] = Participant({
            isProducer: _isProducer,
            energyBalance: 0,
            balance: 0,
            isRegistered: true
        });
    }

    // Producers generate energy
    function produceEnergy(uint256 _amount) external {
        require(participants[msg.sender].isProducer, "Only producers can generate energy");
        participants[msg.sender].energyBalance += _amount;
        emit EnergyProduced(msg.sender, _amount);
    }

    // Create an order

    function placeOrder(address _trader, uint price, uint quantity, OrderType orderType) external {
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");

        uint orderId = nextOrderId++;
        orders[orderId] = Order({
            id: orderId,
            trader: msg.sender,
            price: price,
            quantity: quantity,
            orderType: orderType,
            isActive: true
        });

        if (orderType == OrderType.Buy) {
            require(participants[_trader].balance >= price, "Insufficient balance for trade");
            uint256 a=matchBuyOrders(orderId);
            if (a==0){
                buyOrders.push(orderId);
            }
        } else {
            require(participants[_trader].isProducer, "Seller must be a producer");
            require(participants[_trader].energyBalance >= quantity, "Seller does not have enough energy");
            uint256 b=matchSellOrders(orderId);
            if (b==0){
                sellOrders.push(orderId);
            }
        }

        emit OrderPlaced(orderId, msg.sender, price, quantity, orderType);
        
    }


    function matchBuyOrders(uint ID) internal returns(uint256 n){
            Order storage buyOrder = orders[ID];

            for (uint j = 0; j < sellOrders.length; j++) {
                Order storage sellOrder = orders[sellOrders[j]];
                if (!sellOrder.isActive) continue;

                if (buyOrder.price >= sellOrder.price) {
                    uint matchedQuantity = min(buyOrder.quantity, sellOrder.quantity);
                    uint matchedPrice = sellOrder.price;

                    buyOrder.quantity -= matchedQuantity;
                    sellOrder.quantity -= matchedQuantity;

                    participants[sellOrder.trader].energyBalance -= matchedQuantity;
                    participants[buyOrder.trader].energyBalance += matchedQuantity;

                    if (buyOrder.quantity == 0) {
                        buyOrder.isActive = false;
                        return 1;
                    }

                    if (sellOrder.quantity == 0) {
                        sellOrder.isActive = false;
                        removeOrder(sellOrders, j);
                        j--;
                    }

                    trades.push(Trade({
                        buyer : buyOrder.trader,
                        seller: sellOrder.trader,
                        energyAmount: matchedQuantity,
                        price: matchedPrice
                    }));

                    emit OrderMatched(buyOrder.id, sellOrder.id, buyOrder.trader, sellOrder.trader, matchedPrice, matchedQuantity);
                    break;
                }
            }
            return 0;
        }
    

    function matchSellOrders(uint ID) internal returns(uint256 n){
            Order storage sellOrder = orders[ID];

            for (uint i = 0; i < buyOrders.length; i++) {
            Order storage buyOrder = orders[buyOrders[i]];
            if (!buyOrder.isActive) continue;

                if (buyOrder.price >= sellOrder.price) {
                    uint matchedQuantity = min(buyOrder.quantity, sellOrder.quantity);
                    uint matchedPrice = sellOrder.price;

                    buyOrder.quantity -= matchedQuantity;
                    sellOrder.quantity -= matchedQuantity;

                    participants[sellOrder.trader].energyBalance -= matchedQuantity;
                    participants[buyOrder.trader].energyBalance += matchedQuantity;

                    if (buyOrder.quantity == 0) {
                        buyOrder.isActive = false;
                        removeOrder(buyOrders, i);
                        i--;
                    }

                    if (sellOrder.quantity == 0) {
                        sellOrder.isActive = false;
                        return 1;
                    }

                    trades.push(Trade({
                        buyer : buyOrder.trader,
                        seller: sellOrder.trader,
                        energyAmount: matchedQuantity,
                        price: matchedPrice
                    }));

                    emit OrderMatched(buyOrder.id, sellOrder.id, buyOrder.trader, sellOrder.trader, matchedPrice, matchedQuantity);
                    break;
                }
            }
            return 0;
        }
    

    function cancelOrder(uint orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Only the trader can cancel this order");
        require(order.isActive, "Order is not active");

        order.isActive = false;

        if (order.orderType == OrderType.Buy) {
            removeOrder(buyOrders, findOrderIndex(buyOrders, orderId));
        } else {
            removeOrder(sellOrders, findOrderIndex(sellOrders, orderId));
        }

        emit OrderCancelled(orderId);
    }

    function findOrderIndex(uint[] storage orderList, uint orderId) internal view returns (uint) {
        for (uint i = 0; i < orderList.length; i++) {
            if (orderList[i] == orderId) {
                return i;
            }
        }
        revert("Order not found");
    }

    function removeOrder(uint[] storage orderList, uint index) internal {
        require(index < orderList.length, "Invalid index");
        orderList[index] = orderList[orderList.length - 1];
        orderList.pop();
    }

    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    

    // Consumers consume energy
    function consumeEnergy(uint256 _amount) external {
        require(participants[msg.sender].energyBalance >= _amount, "Insufficient energy balance");
        participants[msg.sender].energyBalance -= _amount;
        emit EnergyConsumed(msg.sender, _amount);
    }

    // Get details of a trade
    function getTrade(uint256 _tradeId) external view returns (Trade memory) {
        return trades[_tradeId];
    }

    // Get details of a participant
    function getParticipant(address _participant) external view returns (Participant memory) {
        return participants[_participant];
    }
}
