pragma circom 2.0.0;

include "circomlib/comparators.circom";
include "circomlib/poseidon.circom";

template TradeVerification() {
    // Private inputs
    signal input sellerEnergyReading;
    signal input buyerEnergyReading;
    signal input price;
    signal input timestamp;
    signal input sellerMinPrice;
    signal input buyerMaxPrice;
    
    // Public inputs
    signal input marketPrice;
    signal input maxPriceDeviation; // Maximum allowed deviation from market price
    
    // Outputs
    signal output isValid;
    signal output tradeHash;
    
    // Verify energy amounts are positive
    signal validAmount1 <== GreaterEq()([sellerEnergyReading, 0]);
    signal validAmount2 <== GreaterEq()([buyerEnergyReading, 0]);
    
    // Verify price is within acceptable range
    signal priceDeviation <== abs(price - marketPrice);
    signal validPrice <== GreaterEq()([maxPriceDeviation, priceDeviation]);
    
    // Verify price meets seller and buyer constraints
    signal validSeller <== GreaterEq()([price, sellerMinPrice]);
    signal validBuyer <== GreaterEq()([buyerMaxPrice, price]);
    
    // Combine all validations
    isValid <== validAmount1 * validAmount2 * validPrice * validSeller * validBuyer;
    
    // Generate trade hash for on-chain verification
    component hasher = Poseidon(5);
    hasher.inputs[0] <== sellerEnergyReading;
    hasher.inputs[1] <== buyerEnergyReading;
    hasher.inputs[2] <== price;
    hasher.inputs[3] <== timestamp;
    hasher.inputs[4] <== marketPrice;
    tradeHash <== hasher.out;
}

component main = TradeVerification();