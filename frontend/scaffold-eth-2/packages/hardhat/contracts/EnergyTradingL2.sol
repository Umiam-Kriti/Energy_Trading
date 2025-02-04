// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./EnergyProofVerifier.sol"; // zk-SNARK verifier
import "./PriceFeed.sol"; // Dynamic pricing oracle

contract EnergyTradingL2 is ReentrancyGuard, Ownable {
    address public Owner;
    address[] public registeredUserAddresses;

    // zk-SNARK verifier contract
    EnergyProofVerifier public energyProofVerifier;

    // Dynamic pricing oracle
    PriceFeed public priceFeed;

    constructor(address _energyProofVerifier, address _priceFeed) Ownable(msg.sender) {
        energyProofVerifier = EnergyProofVerifier(_energyProofVerifier);
        priceFeed = PriceFeed(_priceFeed);
        initializeDefaultPrices();
        lastBillingCycle = block.timestamp;
    }

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
        uint256 storedEnergy;
        uint256 criticalLoad; // in 0.01 kW
    }

    struct BatchStoredTrade {
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
    event ZkProofVerified(address indexed user, uint256 group, uint256 hour);

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
    error InvalidZkProof();

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

    // Register a participant with zk-SNARK proof
    function registerParticipant(
        uint8 group,
        bool isProducer,
        uint256 pcLoad,
        bytes calldata zkProof
    ) external {
        require(!participants[msg.sender].isRegistered, "Already registered");
        require(group < 6, "Invalid group");

        // Verify zk-SNARK proof
        bool isValid = energyProofVerifier.verifyProof(
            zkProof,
            abi.encodePacked(msg.sender, group, isProducer, pcLoad)
        );
        if (!isValid) revert InvalidZkProof();

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
            storedEnergy: 0,
            criticalLoad: pcLoad
        });

        groupParticipants[group].push(msg.sender);
        registeredUserAddresses.push(msg.sender);
        emit ParticipantRegistered(msg.sender, group, isProducer);
    }

    // Update energy data with zk-SNARK proof
    function updateEnergyDataBatch(
        uint256 _group,
        EnergyData[] calldata _batchData,
        bytes calldata zkProof
    ) external onlyOwner {
        require(_group < 6, "Invalid group");
        require(_batchData.length > 0, "Empty batch");

        // Verify zk-SNARK proof
        bool isValid = energyProofVerifier.verifyProof(
            zkProof,
            abi.encodePacked(_group, _batchData)
        );
        if (!isValid) revert InvalidZkProof();

        uint256 hour = currentHour > 0 ? currentHour - 1 : 23;
        uint256 gg = 0;
        uint256 gc = 0;

        for (uint256 i = 0; i < _batchData.length; i++) {
            address userAddress = _batchData[i].userAddress;
            require(participants[userAddress].isRegistered, "User not registered");
            require(participants[userAddress].isActive, "User not active");
            require(participants[userAddress].group == _group, "User not in specified group");

            participants[userAddress].generation[hour] = _batchData[i].generation;
            participants[userAddress].consumption[hour] = _batchData[i].consumption;

            gg += _batchData[i].generation;
            gc += _batchData[i].consumption;
        }

        if (currentHour == 0) {
            chargeUnmatched(23, _group);
        } else if (currentHour < 18 && currentHour >= 6) {
            matchOrders(hour, _group);
        } else {
            chargeUnmatched(hour, _group);
        }

        emit BatchEnergyDataUpdated(_group, hour, _batchData.length);
        emit GroupGeneration(_group, hour, gg);
        emit GroupConsumption(_group, hour, gc);
    }

    // Verify zk-SNARK proof for energy data
    function verifyEnergyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[3] memory input
    ) public view returns (bool) {
        return energyProofVerifier.verifyProof(a, b, c, input);
    }

    // Update prices using oracle
    function updatePricesFromOracle() external onlyOwner {
        uint256[24] memory newPrices = priceFeed.getLatestPrices();
        unmatchedConsumptionPrice = newPrices;
        emit PricesUpdated(newPrices);
    }

    // Additional helper functions (unchanged from original contract)
    // ...
}