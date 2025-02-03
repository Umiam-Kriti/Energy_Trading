const snarkjs = require('snarkjs');
const fs = require('fs');

// Generate a proof
const generateProof = async (input, circuitPath) => {
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        input,
        `${circuitPath}/circuit.wasm`,
        `${circuitPath}/circuit_final.zkey`
    );
    return { proof, publicSignals };
};

// Verify a proof
const verifyProof = async (proof, publicSignals, verificationKeyPath) => {
    const vKey = JSON.parse(fs.readFileSync(verificationKeyPath));
    return await snarkjs.groth16.verify(vKey, publicSignals, proof);
};

module.exports = { generateProof, verifyProof };
