const { ethers } = require("hardhat");
const energyTradingL2Address = require("../frontend/constants/energyTradingL2-address.json").EnergyTradingL2;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying EnergyTradingBridge with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const EnergyTradingBridge = await ethers.getContractFactory("EnergyTradingBridge");
  const energyTradingBridge = await EnergyTradingBridge.deploy(energyTradingL2Address); 
  await energyTradingBridge.deployed();

  console.log("EnergyTradingBridge deployed to:", energyTradingBridge.address);

  // Export the contract address for other scripts
  const fs = require("fs");
  const contractsDir = __dirname + "/../frontend/constants/";
  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    contractsDir + "energyTradingBridge-address.json",
    JSON.stringify({ EnergyTradingBridge: energyTradingBridge.address }, undefined, 2)
  );

  // Set up roles and permissions
  console.log("Setting up roles and permissions...");

  // Grant MINTER_ROLE to EnergyTradingBridge in CarbonCreditToken
  const carbonCreditTokenAddress = require("../frontend/constants/carbonCreditToken-address.json").CarbonCreditToken;
  const CarbonCreditToken = await ethers.getContractFactory("CarbonCreditToken");
  const carbonCreditToken = await CarbonCreditToken.attach(carbonCreditTokenAddress);

  const MINTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));
  await carbonCreditToken.grantRole(MINTER_ROLE, energyTradingBridge.address);
  console.log("Granted MINTER_ROLE to EnergyTradingBridge");

  // Transfer ownership of EnergyTradingL2 to EnergyTradingBridge
  const EnergyTradingL2 = await ethers.getContractFactory("EnergyTradingL2");
  const energyTradingL2 = await EnergyTradingL2.attach(energyTradingL2Address);
  await energyTradingL2.transferOwnership(energyTradingBridge.address);
  console.log("Transferred EnergyTradingL2 ownership to EnergyTradingBridge");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });