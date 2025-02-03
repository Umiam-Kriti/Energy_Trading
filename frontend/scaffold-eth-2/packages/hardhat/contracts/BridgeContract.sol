// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/access/Ownable.sol";

interface IEnergyTradingL2 {
    function executeTrades(address[] calldata buyers, address[] calldata sellers, uint256[] calldata energyAmounts, uint256[] calldata pricePerUnits) external;
}

contract EnergyTradingBridge is Ownable {
    struct Trade {
        uint256 tradeId;
        address buyer;
        address seller;
        uint256 energyAmount;
        uint256 pricePerUnit;
        uint256 timestamp;
    }

    mapping(uint256 => Trade) public trades;
    uint256 public nextTradeId = 1;
    address public energyTradingL2Address;
    bool private isProcessing;

    event TradeSettled(uint256 indexed tradeId, address indexed buyer, address indexed seller, uint256 energyAmount, uint256 pricePerUnit);

    modifier nonReentrant() {
        require(!isProcessing, "Reentrancy detected");
        isProcessing = true;
        _;
        isProcessing = false;
    }

    constructor(address _energyTradingL2Address) Ownable(msg.sender) { // ✅ Fix: Set owner
        require(_energyTradingL2Address != address(0), "Invalid contract address");
        energyTradingL2Address = _energyTradingL2Address;
    }

    function updateEnergyTradingL2Address(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid contract address");
        energyTradingL2Address = _newAddress;
    }
}
