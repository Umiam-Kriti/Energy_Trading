pragma circom 2.0.0;

include "circomlib/comparators.circom";
include "circomlib/poseidon.circom";

template EnergyValidityCheck() {
    // Private inputs
    signal input deviceId;
    signal input timestamp;
    signal input energyReading;
    signal input previousReading;
    signal input deviceSecret; // Secret key known only to the device
    
    // Public inputs
    signal input maxPossibleChange;
    signal input minPossibleReading;
    signal input maxPossibleReading;
    signal input expectedDeviceHash;
    
    // Outputs
    signal output isValid;
    signal output readingHash;
    
    // Verify device authenticity
    component hasher = Poseidon(2);
    hasher.inputs[0] <== deviceId;
    hasher.inputs[1] <== deviceSecret;
    signal deviceAuth <== IsEqual()([hasher.out, expectedDeviceHash]);
    
    // Validate reading range
    signal rangeCheck1 <== GreaterEq()([energyReading, minPossibleReading]);
    signal rangeCheck2 <== GreaterEq()([maxPossibleReading, energyReading]);
    
    // Validate rate of change
    signal change <== abs(energyReading - previousReading);
    signal changeCheck <== GreaterEq()([maxPossibleChange, change]);
    
    // Combine all checks
    isValid <== deviceAuth * rangeCheck1 * rangeCheck2 * changeCheck;
    
    // Generate hash of the reading for on-chain storage
    component readingHasher = Poseidon(3);
    readingHasher.inputs[0] <== deviceId;
    readingHasher.inputs[1] <== timestamp;
    readingHasher.inputs[2] <== energyReading;
    readingHash <== readingHasher.out;
}

component main = EnergyValidityCheck();