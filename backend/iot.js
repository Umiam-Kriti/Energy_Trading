const mqtt = require('mqtt');
const Web3 = require('web3');
const schedule = require('node-schedule');

// MQTT broker settings
const BROKER = 'mqtt://test.mosquitto.org';
const TOPIC_PREFIX = 'energy/device/';

// Ethereum settings
const INFURA_URL = 'https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID';
const CONTRACT_ADDRESS = 'YOUR_CONTRACT_ADDRESS';
const PRIVATE_KEY = 'YOUR_PRIVATE_KEY';

// Web3 setup
const web3 = new Web3(new Web3.providers.HttpProvider(INFURA_URL));
const account = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY);
web3.eth.accounts.wallet.add(account);

// Contract ABI (replace with your actual ABI)
const ABI = [/* Your contract ABI here */];
const contract = new web3.eth.Contract(ABI, CONTRACT_ADDRESS);

// MQTT client
const client = mqtt.connect(BROKER);

client.on('connect', () => {
  console.log('Connected to MQTT broker');
});

async function simulateAndPublishData(hour) {
  const registeredUsers = await getRegisteredUsers();

  for (const [address] of Object.entries(registeredUsers)) {
    if (hour >= 18 || hour < 6){
      var generation = 0;
    }
    else if(hour == 6 || hour==17){
      var generation = 5 * Math.floor(Math.random() * (20 - 1 + 1) + 1) ; // here if genereation = 30 it represents  0.3kWh
    }
    else if(hour == 7 || hour==16){
      var generation = 12 * Math.floor(Math.random() * (20 - 1 + 1) + 1) ;

    }
    else if(hour == 8 || hour==15){
      var generation = 24 * Math.floor(Math.random() * (20 - 1 + 1) + 1) ;  // here 24 tells the efficiency of the solar capacity

    }
    else if(hour == 9 || hour==14){
      var generation = 36 * Math.floor(Math.random() * (20 - 1 + 1) + 1);

    }
    else if(hour == 10 || hour==13){
      var generation = 48 * Math.floor(Math.random() * (20 - 1 + 1) + 1);

    }
    else if(hour == 11 || hour==12){
      var  generation = 60 * Math.floor(Math.random() * (20 - 1 + 1) + 1); // here [1,20] is for energy capacity of a panel

    }

    if (hour >= 0 && hour < 6){
      var consumption = 30 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) )  // here [0.5,5] is for the load
    }
    else if(hour >= 6 && hour < 9){
      var consumption = 70 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; // here number 100 represents  1kWh
    }
    else if(hour >= 9 && hour < 12){
      var consumption = 45 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; 
    }
    else if(hour >= 12 && hour < 15){
      var consumption = 75 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; 
    }
    else if(hour >= 15 && hour < 18){
      var consumption = 50 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; 
    }
    else if(hour >= 18 && hour < 21){
      var consumption = 120 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; 
    }
    else if(hour >= 21 && hour < 24){
      var consumption = 90 * Math.round(5 * Math.floor(Math.random() * (5 - 0.5 + 1) + 0.5) ) ; 
    }
    
    
    const topic = `${TOPIC_PREFIX}${address}`;
    const payload = JSON.stringify({ generation, consumption });
    
    client.publish(topic, payload, (err) => {
      if (err) {
        console.error(`Error publishing for ${address}:`, err);
      } else {
        console.log(`Published for ${address}: Generation: ${generation}, Consumption: ${consumption}`);
        updateSmartContract(address, generation, consumption);
      }
    });
  }
}

async function updateSmartContract(address, generation, consumption) {
  try {
    const gasPrice = await web3.eth.getGasPrice();
    const gasEstimate = await contract.methods.updateEnergyData(address, generation, consumption).estimateGas({ from: account.address });
    
    const tx = await contract.methods.updateEnergyData(address, generation, consumption).send({
      from: account.address,
      gas: gasEstimate,
      gasPrice: gasPrice
    });
    
    console.log(`Transaction successful for ${address}. Hash: ${tx.transactionHash}`);
  } catch (error) {
    console.error(`Error updating smart contract for ${address}:`, error);
  }
}

async function getRegisteredUsers() {
  try {
    const users = await contract.methods.getAllRegisteredUsers().call();
    const userGroups = {};
    for (const user of users) {
      const participant = await contract.methods.participants(user).call();
      userGroups[user] = participant.group;
    }
    return userGroups;
  } catch (error) {
    console.error('Error fetching registered users:', error);
    return {};
  }
}

// Schedule the simulation to run at the beginning of every hour
schedule.scheduleJob('0 * * * *', () => {
  console.log('Running hourly simulation...');
  const newHour = new Date().getHours();
  simulateAndPublishData(newHour-1);
});

console.log('IoT simulator started. Waiting for the next hour to begin simulation...');
