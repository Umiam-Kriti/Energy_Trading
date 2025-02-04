pragma circom 2.0.0;

include "circomlib/comparators.circom";
include "circomlib/poseidon.circom";

template CarbonCreditVerification() {
    // Private inputs
    signal input totalGreenEnergy;
    signal input consumedEnergy;
    signal input timestamp;
    signal input userIdentifier;
    
    // Public inputs
    signal input minimumGreenRatio;
    signal input creditMultiplier;
    signal input maximumCreditsPerPeriod;
    
    // Outputs
    signal output eligibleCredits;
    signal output verificationHash;
    
    // Calculate green energy ratio
    signal greenRatio;
    greenRatio <== totalGreenEnergy / (totalGreenEnergy + consumedEnergy);
    
    // Verify green ratio meets minimum requirement
    signal meetsMinimum <== GreaterEq()([greenRatio, minimumGreenRatio]);
    
    // Calculate eligible credits
    signal rawCredits <== totalGreenEnergy * creditMultiplier;
    
    // Apply maximum cap
    component limitCheck = LessEq();
    limitCheck.in[0] <== rawCredits;
    limitCheck.in[1] <== maximumCreditsPerPeriod;
    
    eligibleCredits <== meetsMinimum * (
        limitCheck.out * rawCredits + 
        (1 - limitCheck.out) * maximumCreditsPerPeriod
    );
    
    // Generate verification hash
    component hasher = Poseidon(4);
    hasher.inputs[0] <== totalGreenEnergy;
    hasher.inputs[1] <== consumedEnergy;
    hasher.inputs[2] <== timestamp;
    hasher.inputs[3] <== userIdentifier;
    verificationHash <== hasher.out;
}

component main = CarbonCreditVerification();