const hre = require("hardhat");

async function main() {
    const [owner] = await hre.ethers.getSigners();

    // Deploy the contract
    const EnergyTrading = await hre.ethers.getContractFactory("EnergyTradingL2");
    const energyTrading = await EnergyTrading.deploy();
    await energyTrading.deployed();
    console.log("Contract deployed to:", energyTrading.address);

    // Pre-register dummy users
    await energyTrading.preRegisterUsers();
    console.log("Dummy users registered");

    // Set energy data for dummy users
    const generation = [0, 0, 0, 0, 0, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180];
    const consumption = [50, 50, 50, 50, 50, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230];
    const users = await contract.methods.getAllRegisteredUsers().call();
    for (const user of users){
        await energyTrading.setDummyEnergyData(user, generation, consumption);
    }
    console.log("Energy data set for dummy users");

    // Simulate trades
    await energyTrading.updateHour(10);
    await energyTrading.matchOrders(10, 0);
    console.log("Trades simulated for hour 10");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });