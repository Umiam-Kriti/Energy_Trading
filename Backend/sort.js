const Web3 = require("web3");
const contractABI = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'Energy_Trading\scaffold-eth-2\packages\hardhat\artifacts\contracts\EnergyTradingL2.sol\EnergyTradingL2.json')));

// Connect to Ethereum node (e.g., Infura)
const web3 = new Web3("http://localhost:3000");
const contractAddress = "0xYourContractAddress";
const contract = new web3.eth.Contract(contractABI, contractAddress);

// Owner's private key (for signing transactions)
const ownerPrivateKey = "YOUR_OWNER_PRIVATE_KEY";

function updateHour() {
    const currentHour = new Date().getHours();
    
    contract.methods.updateHour(currentHour).send({ from: 'YOUR_ACCOUNT_ADDRESS' })
      .then(receipt => {
        console.log(`Hour updated to ${currentHour}. Transaction hash: ${receipt.transactionHash}`);
      })
      .catch(error => {
        console.error('Error updating hour:', error);
      });
  }
  
  function scheduleHourlyUpdate() {
    const now = new Date();
    const msUntilNextHour = 3600000 - (now.getMinutes() * 60000 + now.getSeconds() * 1000 + now.getMilliseconds());
    
    setTimeout(() => {
      updateHour();
      setInterval(updateHour, 3600000); // Call every hour (3600000 ms)
    }, msUntilNextHour);
  }
  
  // Start the scheduling
  scheduleHourlyUpdate();
  
// Store sorted buyers for the day (to avoid redundant sorting)
let sortedBuyersForDay = {};

// Listen for NeedSorting event
contract.events.NeedSorting({}, async (error, event) => {
    if (error) {
        console.error("Error in event:", error);
        return;
    }

    const { hour, group, participants, isBuyerSorting } = event.returnValues;

    console.log(`NeedSorting event detected for hour ${hour}, group ${group}`);

    if (isBuyerSorting) {
        // Sort buyers once per day
        console.log("Sorting buyers for the day...");
        sortedBuyersForDay[group] = await sortBuyers(participants);
        console.log("Sorted Buyers:", sortedBuyersForDay[group]);

        // Submit sorted buyers to the contract
        await submitSortedAddresses(hour, group, sortedBuyersForDay[group], true);
    } else {
        // Sort sellers every hour
        console.log("Sorting sellers for the current hour...");
        const sortedSellers = await sortSellers(participants, hour);
        console.log("Sorted Sellers:", sortedSellers);

        // Submit sorted sellers to the contract
        await submitSortedAddresses(hour, group, sortedSellers, false);
    }
});

// Function to sort sellers by selling price (ascending)
async function sortSellers(sellers, hour) {
    const sellerData = await Promise.all(
        sellers.map(async (seller) => {
            const sellingPrice = await contract.methods
                .participants(seller)
                .call()
                .then((p) => p.sellingPrices[hour]);
            return { address: seller, sellingPrice };
        })
    );

    // Sort sellers by selling price (ascending)
    return sellerData
        .sort((a, b) => a.sellingPrice - b.sellingPrice)
        .map((s) => s.address);
}

// Function to sort buyers by previous day's consumption (ascending)
async function sortBuyers(buyers) {
    const buyerData = await Promise.all(
        buyers.map(async (buyer) => {
            const consumption = await getPreviousDayConsumption(buyer, 19, 22); // 7 PM to 10 PM
            return { address: buyer, consumption };
        })
    );

    // Sort buyers by consumption (ascending)
    return buyerData
        .sort((a, b) => a.consumption - b.consumption)
        .map((b) => b.address);
}

// Function to calculate total consumption for a participant between two hours
async function getPreviousDayConsumption(participantAddress, startHour, endHour) {
    let totalConsumption = 0;
    for (let hour = startHour; hour <= endHour; hour++) {
        const consumption = await contract.methods
            .participants(participantAddress)
            .call()
            .then((p) => p.consumption[hour]);
        totalConsumption += parseInt(consumption);
    }
    return totalConsumption;
}

// Function to submit sorted addresses to the contract
async function submitSortedAddresses(hour, group, sortedParticipants, isBuyerSorting) {
    // Create transaction to call submitSortedAddresses
    const txData = contract.methods
        .submitSortedAddresses(hour, group, sortedParticipants, isBuyerSorting)
        .encodeABI();

    const tx = {
        to: contractAddress,
        data: txData,
        gas: 2000000, // Adjust gas limit as needed
        gasPrice: web3.utils.toWei("20", "gwei"), // Adjust gas price as needed
    };

    // Sign and send the transaction
    const signedTx = await web3.eth.accounts.signTransaction(tx, ownerPrivateKey);
    const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);

    console.log("Transaction receipt:", receipt);
}

// Start the service
console.log("Off-chain sorting service started. Listening for events...");
