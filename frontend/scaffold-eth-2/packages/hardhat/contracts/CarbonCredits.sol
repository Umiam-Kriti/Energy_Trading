// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CarbonCreditToken is ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Carbon credit properties
    uint256 public conversionRate = 1000; // 1 credit per 1000 kWh
    uint256 public creditDecayRate = 10; // 10% annual decay
    uint256 public stakingRewardRate = 5; // 5% annual reward

    // Marketplace
    struct Listing {
        address seller;
        uint256 price;
        uint256 amount;
        uint256 listingDate;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCount;
    uint256 public constant FEE_PERCENT = 1; // 1% transaction fee

    // Staking
    struct Stake {
        uint256 amount;
        uint256 stakedSince;
    }

    mapping(address => Stake) public stakes;

    // Tracking
    mapping(address => uint256) public renewableEnergyGenerated;
    mapping(address => uint256) public lastCreditMintDate;
    mapping(address => bool) public blacklisted;

    event CreditsMinted(address indexed producer, uint256 energyAmount, uint256 creditsMinted);
    event CreditsBurned(address indexed burner, uint256 amount);
    event CreditsStaked(address indexed staker, uint256 amount);
    event CreditsUnstaked(address indexed staker, uint256 amount, uint256 rewards);
    event CreditsListed(address indexed seller, uint256 listingId, uint256 amount, uint256 price);
    event CreditsBought(address indexed buyer, address indexed seller, uint256 amount, uint256 price);
    event BlacklistUpdated(address indexed account, bool status);
    event ConversionRateUpdated(uint256 newRate);

    constructor() ERC20("Carbon Credit Token", "CCT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    // Main minting function with verification
    function mintCarbonCredits(
        address producer,
        uint256 energyAmount
        // bytes32[] calldata proof
    ) external onlyRole(MINTER_ROLE) nonReentrant {
        require(!blacklisted[producer], "Blacklisted address");
        require(energyAmount >= conversionRate, "Insufficient energy");
        // require(verifyEnergyProof(producer, energyAmount, proof), "Invalid proof");

        uint256 creditsToMint = energyAmount / conversionRate;
        _mint(producer, creditsToMint);

        renewableEnergyGenerated[producer] += energyAmount;
        lastCreditMintDate[producer] = block.timestamp;

        emit CreditsMinted(producer, energyAmount, creditsToMint);
    }

    // Time-decay adjusted balance
    function effectiveBalanceOf(address account) public view returns (uint256) {
        uint256 rawBalance = balanceOf(account);
        uint256 age = block.timestamp - lastCreditMintDate[account];
        uint256 decayedAmount = rawBalance * (creditDecayRate * age) / (100 * 365 days);
        return rawBalance > decayedAmount ? rawBalance - decayedAmount : 0;
    }

    // Staking functions
    function stakeCredits(uint256 amount) external nonReentrant {
        require(effectiveBalanceOf(msg.sender) >= amount, "Insufficient credits");

        _burn(msg.sender, amount);
        stakes[msg.sender] = Stake({
            amount: stakes[msg.sender].amount + amount,
            stakedSince: block.timestamp
        });

        emit CreditsStaked(msg.sender, amount);
    }

    function unstakeCredits() external nonReentrant {
        Stake storage stake = stakes[msg.sender];
        require(stake.amount > 0, "No staked credits");

        uint256 duration = block.timestamp - stake.stakedSince;
        uint256 rewards = stake.amount * (stakingRewardRate * duration) / (100 * 365 days);

        _mint(msg.sender, stake.amount + rewards);
        delete stakes[msg.sender];

        emit CreditsUnstaked(msg.sender, stake.amount, rewards);
    }

    // Marketplace functions
    function listCredits(uint256 amount, uint256 price) external nonReentrant {
        require(effectiveBalanceOf(msg.sender) >= amount, "Insufficient credits");

        _transfer(msg.sender, address(this), amount);
        listings[++listingCount] = Listing({
            seller: msg.sender,
            price: price,
            amount: amount,
            listingDate: block.timestamp
        });

        emit CreditsListed(msg.sender, listingCount, amount, price);
    }

    function buyCredits(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(msg.value >= listing.price * listing.amount, "Insufficient payment");

        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 payment = msg.value - fee;

        payable(listing.seller).transfer(payment);
        _transfer(address(this), msg.sender, listing.amount);

        delete listings[listingId];
        emit CreditsBought(msg.sender, listing.seller, listing.amount, listing.price);
    }

    // Admin functions
    function updateConversionRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        conversionRate = newRate;
        emit ConversionRateUpdated(newRate);
    }

    function toggleBlacklist(address account, bool status) external onlyRole(VERIFIER_ROLE) {
        blacklisted[account] = status;
        emit BlacklistUpdated(account, status);
    }

    // Proof verification (to be implemented with oracle/zk-SNARKs)
    // function verifyEnergyProof(
    //     address producer,
    //     uint256 energyAmount,
    //     bytes32[] calldata proof
    // ) internal pure returns (bool) {
    //     // Implementation for energy proof verification
    //     // This could be connected to Chainlink oracles or zk-SNARKs
    //     return true; // Simplified for example
    // }

    // // Override transfer with blacklist check
    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal override {
    //     super._beforeTokenTransfer(from, to, amount);
    //     require(!blacklisted[from] && !blacklisted[to], "Blacklisted address");
    // }
}