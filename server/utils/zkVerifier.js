const { groth16 } = require('snarkjs');
const path = require('path');

// Path to the verification key
const verificationKeyPath = path.join(__dirname, '../../snark_data/verification_key.json');
const verificationKey = require(verificationKeyPath);

const verifyZKProof = async (proof, publicSignals) => {
  try {
    const isValid = await groth16.verify(verificationKey, publicSignals, proof);
    return isValid;
  } catch (error) {
    console.error('ZKSnarks verification error:', error);
    return false;
  }
};

module.exports = verifyZKProof;
