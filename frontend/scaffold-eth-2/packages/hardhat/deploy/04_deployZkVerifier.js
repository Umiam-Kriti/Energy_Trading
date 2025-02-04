const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy ZkSnarkVerifier contract
    const ZkSnarkVerifier = await ethers.getContractFactory("ZkSnarkVerifier");
    const verifier = await ZkSnarkVerifier.deploy();
    await verifier.deployed();

    console.log("ZkSnarkVerifier deployed to:", verifier.address);

    // Deploy individual zk-SNARK verifiers
    const proofTypes = ["ENERGY_VALIDITY", "TRADE_VERIFICATION", "CARBON_CREDIT"];
    for (const proofType of proofTypes) {
        const ProofVerifier = await ethers.getContractFactory("IVerifier");
        const proofVerifier = await ProofVerifier.deploy();
        await proofVerifier.deployed();

        console.log(`${proofType} Verifier deployed to:`, proofVerifier.address);

        // Link each verifier with ZkSnarkVerifier contract
        await verifier.setVerifier(ethers.utils.keccak256(ethers.utils.toUtf8Bytes(proofType)), proofVerifier.address);
        console.log(`Linked ${proofType} verifier in ZkSnarkVerifier.`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
