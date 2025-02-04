const snarkjs = require("snarkjs");
const fs = require("fs-extra");
const path = require("path");
const chalk = require("chalk");

class ProofGenerator {
    constructor() {
        this.buildPath = path.join(__dirname, "../circuits/build");
    }

    async generateProof(circuitName, inputData) {
        console.log(chalk.blue(`Generating proof for ${circuitName}...`));

        const circuitPath = path.join(this.buildPath, circuitName);
        const wasmPath = path.join(circuitPath, `${circuitName}_js/${circuitName}.wasm`);
        const zkeyPath = path.join(circuitPath, `${circuitName}.zkey`);

        if (!fs.existsSync(wasmPath) || !fs.existsSync(zkeyPath)) {
            throw new Error("Circuit files are missing! Run setup first.");
        }

        try {
            // Generate proof
            const { proof, publicSignals } = await snarkjs.groth16.fullProve(
                inputData,
                wasmPath,
                zkeyPath
            );

            // Format proof for smart contract
            const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
            const argv = calldata.replace(/["[\]\s]/g, "").split(",");
            
            const a = [argv[0], argv[1]];
            const b = [
                [argv[2], argv[3]],
                [argv[4], argv[5]]
            ];
            const c = [argv[6], argv[7]];
            const inputs = argv.slice(8);

            return {
                proof,
                publicSignals,
                solidityProof: {
                    a,
                    b,
                    c,
                    inputs
                }
            };
        } catch (error) {
            console.error(chalk.red("Error generating proof:"), error);
            throw error;
        }
    }

    // Helper method to prepare input data for specific circuits
    prepareEnergyValidityInput(data) {
        return {
            deviceId: data.deviceId,
            timestamp: Math.floor(Date.now() / 1000),
            energyReading: data.energyReading,
            previousReading: data.previousReading,
            deviceSecret: data.deviceSecret,
            maxPossibleChange: data.maxPossibleChange || 1000,
            minPossibleReading: data.minPossibleReading || 0,
            maxPossibleReading: data.maxPossibleReading || 10000,
            expectedDeviceHash: data.expectedDeviceHash
        };
    }

    prepareTradeVerificationInput(data) {
        return {
            sellerEnergyReading: data.sellerEnergy,
            buyerEnergyReading: data.buyerEnergy,
            price: data.price,
            timestamp: Math.floor(Date.now() / 1000),
            sellerMinPrice: data.sellerMinPrice,
            buyerMaxPrice: data.buyerMaxPrice,
            marketPrice: data.marketPrice,
            maxPriceDeviation: data.maxPriceDeviation || 100
        };
    }

    prepareCarbonCreditInput(data) {
        return {
            totalGreenEnergy: data.greenEnergy,
            consumedEnergy: data.consumedEnergy,
            timestamp: Math.floor(Date.now() / 1000),
            userIdentifier: data.userId,
            minimumGreenRatio: data.minGreenRatio || 0.5,
            creditMultiplier: data.multiplier || 1,
            maximumCreditsPerPeriod: data.maxCredits || 1000
        };
    }
}

module.exports = new ProofGenerator();