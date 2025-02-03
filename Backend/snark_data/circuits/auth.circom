include "node_modules/circomlib/circuits/poseidon.circom";

template Auth() {
    // Public input (hash stored on the server)
    signal input expectedHash; 
    // Private input (user's password)
    signal private input password; 

    // Hash the password using Poseidon
    component hasher = Poseidon(1);
    hasher.inputs[0] <== password;
    signal computedHash <== hasher.out;

    // Verify the computed hash matches the expected hash
    computedHash === expectedHash;
}

// Declare the main component correctly
component main = Auth();
