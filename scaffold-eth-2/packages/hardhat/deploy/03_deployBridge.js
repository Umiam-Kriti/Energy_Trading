const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("🚀 Deploying EnergyTradingBridge contract...");

    // ✅ Fetch the deployed EnergyTradingL2 contract dynamically
    const energyTradingL2Deployment = await deployments.get("EnergyTradingL2");
    const energyTradingL2Address = energyTradingL2Deployment.address;

    // ✅ Deploy the bridge contract with the correct EnergyTradingL2 address
    const energyTradingBridge = await deploy("EnergyTradingBridge", {
        from: deployer,
        args: [energyTradingL2Address], // Pass the correct L2 contract address
        log: true,
    });

    console.log(`✅ EnergyTradingBridge deployed at: ${energyTradingBridge.address}`);
};

module.exports.tags = ["EnergyTradingBridge"];
module.exports.dependencies = ["EnergyTradingL2"];
