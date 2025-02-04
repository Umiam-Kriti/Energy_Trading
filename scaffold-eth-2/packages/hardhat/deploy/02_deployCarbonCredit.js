const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("🚀 Deploying CarbonCreditToken contract...");

    // Deploying the contract
    const carbonCreditToken = await deploy("CarbonCreditToken", {
        from: deployer,
        args: [],
        log: true,
    });

    console.log(`✅ CarbonCreditToken deployed at: ${carbonCreditToken.address}`);
};

module.exports.tags = ["CarbonCreditToken"];  
