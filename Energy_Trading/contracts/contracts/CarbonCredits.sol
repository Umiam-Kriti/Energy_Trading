// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CarbonCredits is ERC20, Ownable {
    // Addresses authorized to mint credits (energy trading contracts)
    mapping(address => bool) public authorizedMinters;
    
    // Rate of credit generation (10 kWh = 1 CC)
    uint256 public constant ENERGY_TO_CREDIT_RATE = 10;
    
    // Events
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event CreditsMinted(address indexed to, uint256 amount, uint256 energyAmount);

    constructor() ERC20("CarbonCredits", "CC") Ownable(msg.sender) {}

    // Add a contract that can mint credits
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    // Remove a contract's minting privileges
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    // Mint carbon credits based on energy amount
    function mintCredits(address to, uint256 energyAmount) external {
        require(authorizedMinters[msg.sender], "Not authorized to mint");
        require(energyAmount >= ENERGY_TO_CREDIT_RATE, "Energy amount too low");
        
        uint256 creditsToMint = energyAmount / ENERGY_TO_CREDIT_RATE;
        _mint(to, creditsToMint);
        
        emit CreditsMinted(to, creditsToMint, energyAmount);
    }

    // Allow owner to adjust token metadata if needed
    function updateTokenMetadata(string memory newName, string memory newSymbol) external onlyOwner {
        _updateTokenData(newName, newSymbol);
    }

    // Internal function to update token data
    function _updateTokenData(string memory newName, string memory newSymbol) internal {
        _setName(newName);
        _setSymbol(newSymbol);
    }
}