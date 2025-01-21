//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CarbonCredits.sol";

contract EnergyTrading is ReentrancyGuard, Ownable {
    // Structs
    struct Order {
        address trader;
        uint256 energyAmount;
        uint256 pricePerUnit;
        bool isSellOrder;
        bool isActive;
        bool isRenewable;
    }

    struct Trade {
        address seller;
        address buyer;
        uint256 energyAmount;
        uint256 totalPrice;
        bool isRenewable;
        uint256 timestamp;
    }

    // State variables
    CarbonCredits public carbonCredits;
    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;
    Trade[] public trades;
    
    mapping(address => uint256) public energyBalance;
    mapping(address => bool) public verifiedRenewableProducers;
    
    // Events
    event OrderPlaced(
        uint256 indexed orderId, 
        address indexed trader, 
        uint256 energyAmount, 
        uint256 pricePerUnit, 
        bool isSellOrder,
        bool isRenewable
    );
    event OrderCancelled(uint256 indexed orderId);
    event TradeExecuted(
        uint256 indexed orderId,
        address indexed buyer,
        address indexed seller,
        uint256 energyAmount,
        uint256 totalPrice,
        bool isRenewable
    );
    event ProducerVerified(address indexed producer);
    event EnergyDeposited(address indexed producer, uint256 amount, bool isRenewable);

    constructor(address _carbonCreditsContract) Ownable(msg.sender) {
        carbonCredits = CarbonCredits(_carbonCreditsContract);
    }

    // Verify a renewable energy producer
    function verifyRenewableProducer(address producer) external onlyOwner {
        verifiedRenewableProducers[producer] = true;
        emit ProducerVerified(producer);
    }

    // Place a new energy order
    function placeOrder(
        uint256 energyAmount, 
        uint256 pricePerUnit, 
        bool isSellOrder
    ) external payable nonReentrant returns (uint256) {
        require(energyAmount > 0, "Energy amount must be positive");
        require(pricePerUnit > 0, "Price must be positive");
        
        if (isSellOrder) {
            require(energyBalance[msg.sender] >= energyAmount, "Insufficient energy balance");
        } else {
            require(msg.value >= energyAmount * pricePerUnit, "Insufficient funds sent");
        }

        bool isRenewable = verifiedRenewableProducers[msg.sender];

        uint256 orderId = nextOrderId++;
        orders[orderId] = Order({
            trader: msg.sender,
            energyAmount: energyAmount,
            pricePerUnit: pricePerUnit,
            isSellOrder: isSellOrder,
            isActive: true,
            isRenewable: isRenewable
        });

        emit OrderPlaced(orderId, msg.sender, energyAmount, pricePerUnit, isSellOrder, isRenewable);
        return orderId;
    }

    // Execute an existing order
    function executeOrder(uint256 orderId) external payable nonReentrant {
        Order storage order = orders[orderId];
        require(order.isActive, "Order is not active");
        require(msg.sender != order.trader, "Cannot execute own order");

        if (order.isSellOrder) {
            require(msg.value >= order.energyAmount * order.pricePerUnit, "Insufficient payment");
            _executeTrade(order.trader, msg.sender, order.energyAmount, order.pricePerUnit, order.isRenewable);
        } else {
            require(energyBalance[msg.sender] >= order.energyAmount, "Insufficient energy balance");
            _executeTrade(msg.sender, order.trader, order.energyAmount, order.pricePerUnit, verifiedRenewableProducers[msg.sender]);
        }

        order.isActive = false;
    }

    // Internal function to execute trades
    function _executeTrade(
        address seller, 
        address buyer, 
        uint256 energyAmount, 
        uint256 pricePerUnit,
        bool isRenewable
    ) internal {
        uint256 totalPrice = energyAmount * pricePerUnit;
        
        // Update energy balances
        energyBalance[seller] -= energyAmount;
        energyBalance[buyer] += energyAmount;

        // Transfer payment
        (bool sent, ) = seller.call{value: totalPrice}("");
        require(sent, "Failed to send Ether");

        // Mint carbon credits for renewable energy trades
        if (isRenewable) {
            try carbonCredits.mintCredits(seller, energyAmount) {
                // Credits minted successfully
            } catch {
                // Handle minting failure silently - trade still valid
            }
        }

        // Record trade
        trades.push(Trade({
            seller: seller,
            buyer: buyer,
            energyAmount: energyAmount,
            totalPrice: totalPrice,
            isRenewable: isRenewable,
            timestamp: block.timestamp
        }));

        emit TradeExecuted(nextOrderId - 1, buyer, seller, energyAmount, totalPrice, isRenewable);
    }

    // Cancel an active order
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        require(order.isActive, "Order is not active");
        require(msg.sender == order.trader, "Not order owner");
        
        order.isActive = false;
        
        if (!order.isSellOrder) {
            // Refund buyer's locked payment
            (bool sent, ) = msg.sender.call{value: order.energyAmount * order.pricePerUnit}("");
            require(sent, "Failed to send Ether");
        }
        
        emit OrderCancelled(orderId);
    }

    // Deposit energy (called by IoT devices or verified sources)
    function depositEnergy(address producer, uint256 amount, bool isRenewable) external onlyOwner {
        require(producer != address(0), "Invalid producer address");
        require(amount > 0, "Amount must be positive");
        
        if (isRenewable) {
            require(verifiedRenewableProducers[producer], "Producer not verified as renewable");
        }
        
        energyBalance[producer] += amount;
        emit EnergyDeposited(producer, amount, isRenewable);
    }

    // View functions
    function getActiveOrders() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive) {
                count++;
            }
        }

        uint256[] memory activeOrders = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive) {
                activeOrders[index] = i;
                index++;
            }
        }

        return activeOrders;
    }

    function getTrade(uint256 index) external view returns (Trade memory) {
        require(index < trades.length, "Trade index out of bounds");
        return trades[index];
    }

    function getTradesCount() external view returns (uint256) {
        return trades.length;
    }

    receive() external payable {}
}