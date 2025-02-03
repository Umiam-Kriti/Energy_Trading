const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("🚀 Deploying EnergyTradingL2 contract...");

    // ✅ Since the contract does NOT require constructor arguments, pass an empty `args` array
    const energyTradingL2 = await deploy("EnergyTradingL2", {
        from: deployer,
        args: [], // ✅ No constructor arguments needed
        log: true,
    });

    console.log(`✅ EnergyTradingL2 deployed at: ${energyTradingL2.address}`);
};

module.exports.tags = ["EnergyTradingL2"];  
