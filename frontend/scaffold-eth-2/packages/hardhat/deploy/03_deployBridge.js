const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("Deploying EnergyTradingBridge contract...");

    // ✅ Wait for `EnergyTradingL2` to be deployed
    const energyTradingL2Deployment = await deployments.get("EnergyTradingL2");
    const energyTradingL2Address = energyTradingL2Deployment.address;

    // ✅ Ensure correct argument passing
    const energyTradingBridge = await deploy("EnergyTradingBridge", {
        from: deployer,
        args: [energyTradingL2Address], // ✅ Pass EnergyTradingL2 address as constructor argument
        log: true,
    });

    console.log(`✅ EnergyTradingBridge deployed at: ${energyTradingBridge.address}`);
};

module.exports.tags = ["EnergyTradingBridge"];
module.exports.dependencies = ["EnergyTradingL2"]; // Ensures it deploys after EnergyTradingL2
