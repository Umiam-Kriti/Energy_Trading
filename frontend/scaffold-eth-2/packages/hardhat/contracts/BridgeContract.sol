// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IEnergyTradingL2 {
    struct BatchStoredTrade {
        address buyer;
        address seller;
        uint256 price;
        uint256 quantity;
    }

    function settleStoredEnergyTrades(BatchStoredTrade[] calldata trades) external;
}

contract EnergyTradingBridge is Ownable, ReentrancyGuard {
    struct BridgeTrade {
        address buyer;
        address seller;
        uint256 quantity;
        uint256 price;
        uint256 timestamp;
        bool isProcessed;
        bytes32 tradeHash;
    }

    mapping(uint256 => BridgeTrade) public trades;
    mapping(bytes32 => bool) public processedTradeHashes;
    
    uint256 public nextTradeId = 1;
    address public energyTradingL2Address;
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public validationTimelock = 1 hours;
    
    event TradeRegistered(
        uint256 indexed tradeId,
        address indexed buyer,
        address indexed seller,
        uint256 quantity,
        uint256 price,
        bytes32 tradeHash
    );
    event TradeBatchSettled(uint256[] tradeIds);
    event TradeCancelled(uint256 indexed tradeId);
    event ValidationTimelockUpdated(uint256 newTimelock);
    event L2ContractUpdated(address newAddress);

    error InvalidAddress();
    error InvalidTradeParameters();
    error TradeAlreadyProcessed();
    error TimelockNotExpired();
    error BatchSizeExceeded();
    error TradeNotFound();
    error UnauthorizedCancellation();

    constructor(address _energyTradingL2Address) Ownable(msg.sender) {
        if (_energyTradingL2Address == address(0)) revert InvalidAddress();
        energyTradingL2Address = _energyTradingL2Address;
    }

    function registerTrade(
        address buyer,
        address seller,
        uint256 quantity,
        uint256 price
    ) external nonReentrant returns (uint256) {
        require(buyer != address(0) && seller != address(0), "Invalid addresses");
        require(quantity > 0 && price > 0, "Invalid trade values");

        bytes32 tradeHash = keccak256(abi.encodePacked(
            buyer, seller, quantity, price, block.timestamp
        ));

        if (processedTradeHashes[tradeHash]) revert TradeAlreadyProcessed();

        uint256 tradeId = nextTradeId++;
        trades[tradeId] = BridgeTrade({
            buyer: buyer,
            seller: seller,
            quantity: quantity,
            price: price,
            timestamp: block.timestamp,
            isProcessed: false,
            tradeHash: tradeHash
        });

        emit TradeRegistered(tradeId, buyer, seller, quantity, price, tradeHash);
        return tradeId;
    }

    function settleTrades(uint256[] calldata tradeIds) external nonReentrant onlyOwner {
        if (tradeIds.length > MAX_BATCH_SIZE) revert BatchSizeExceeded();

        IEnergyTradingL2.BatchStoredTrade[] memory batchTrades = 
            new IEnergyTradingL2.BatchStoredTrade[](tradeIds.length);

        for (uint256 i = 0; i < tradeIds.length; i++) {
            BridgeTrade storage trade = trades[tradeIds[i]];
            
            if (trade.buyer == address(0)) revert TradeNotFound();
            if (trade.isProcessed) revert TradeAlreadyProcessed();
            if (block.timestamp < trade.timestamp + validationTimelock) 
                revert TimelockNotExpired();

            batchTrades[i] = IEnergyTradingL2.BatchStoredTrade({
                buyer: trade.buyer,
                seller: trade.seller,
                price: trade.price,
                quantity: trade.quantity
            });

            trade.isProcessed = true;
            processedTradeHashes[trade.tradeHash] = true;
        }

        IEnergyTradingL2(energyTradingL2Address).settleStoredEnergyTrades(batchTrades);
        emit TradeBatchSettled(tradeIds);
    }

    function cancelTrade(uint256 tradeId) external {
        BridgeTrade storage trade = trades[tradeId];
        if (trade.buyer == address(0)) revert TradeNotFound();
        if (trade.isProcessed) revert TradeAlreadyProcessed();
        
        if (msg.sender != trade.buyer && 
            msg.sender != trade.seller && 
            msg.sender != owner()) {
            revert UnauthorizedCancellation();
        }

        delete trades[tradeId];
        emit TradeCancelled(tradeId);
    }

    function updateValidationTimelock(uint256 _newTimelock) external onlyOwner {
        validationTimelock = _newTimelock;
        emit ValidationTimelockUpdated(_newTimelock);
    }

    function updateEnergyTradingL2Address(address _newAddress) external onlyOwner {
        if (_newAddress == address(0)) revert InvalidAddress();
        energyTradingL2Address = _newAddress;
        emit L2ContractUpdated(_newAddress);
    }

    function getTradeDetails(uint256 tradeId) external view returns (
        address buyer,
        address seller,
        uint256 quantity,
        uint256 price,
        uint256 timestamp,
        bool isProcessed,
        bytes32 tradeHash
    ) {
        BridgeTrade storage trade = trades[tradeId];
        require(trade.buyer != address(0), "Trade not found");
        
        return (
            trade.buyer,
            trade.seller,
            trade.quantity,
            trade.price,
            trade.timestamp,
            trade.isProcessed,
            trade.tradeHash
        );
    }
}