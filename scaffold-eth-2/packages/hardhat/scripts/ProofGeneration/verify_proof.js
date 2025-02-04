const snarkjs = require("snarkjs");
const fs = require("fs-extra");
const path = require("path");
const chalk = require("chalk");

class ProofVerifier {
    constructor() {
        this.buildPath = path.join(__dirname, "../circuits/build");
    }

    async verifyProof(circuitName, proof, publicSignals) {
        console.log(chalk.blue(`Verifying proof for ${circuitName}...`));

        const vkeyPath = path.join(
            this.buildPath,
            circuitName,
            `${circuitName}_verification_key.json`
        );

        if (!fs.existsSync(vkeyPath)) {
            throw new Error("Verification key is missing! Run setup first.");
        }

        try {
            const vkey = await fs.readJSON(vkeyPath);
            const isValid = await snarkjs.groth16.verify(vkey, publicSignals, proof);

            if (isValid) {
                console.log(chalk.green("Proof is valid! ✓"));
            } else {
                console.log(chalk.red("Proof is invalid! ✗"));
            }

            return isValid;
        } catch (error) {
            console.error(chalk.red("Error verifying proof:"), error);
            throw error;
        }
    }

    // Helper method to verify proof directly from solidityProof format
    async verifySolidityProof(circuitName, solidityProof) {
        const { a, b, c, inputs } = solidityProof;
        const proof = {
            pi_a: a,
            pi_b: b,
            pi_c: c
        };
        return this.verifyProof(circuitName, proof, inputs);
    }
}

module.exports = new ProofVerifier();