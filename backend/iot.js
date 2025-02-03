const mqtt = require('mqtt');
const Web3 = require('web3');
const schedule = require('node-schedule');
const { create } = require('ipfs-http-client');
const ipfs = create({
    host: 'ipfs.infura.io',
    port: 5001,
    protocol: 'https',
    headers: {
      authorization: `Basic ${Buffer.from(`${INFURA_PROJECT_ID}:${INFURA_SECRET}`).toString('base64')}`
    }
  });

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

// Modified function to simulate and publish data by group
async function simulateAndPublishDataByGroup(hour) {
  const registeredUsers = await getRegisteredUsers();
  const groupedData = new Map(); // Map to store data by group
  
  // Process and group the data
  for (const [address, group] of Object.entries(registeredUsers)) {
    let generation = calculateGeneration(hour);
    let consumption = calculateConsumption(hour);
    
    if (!groupedData.has(group)) {
      groupedData.set(group, []);
    }
    
    groupedData.get(group).push({
      userAddress: address,
      generation,
      consumption
    });
    
    // Publish to MQTT
    const topic = `${TOPIC_PREFIX}${address}`;
    const payload = JSON.stringify({ generation, consumption });
    client.publish(topic, payload);
  }
  
  // Update blockchain in batches by group
  for (const [group, data] of groupedData.entries()) {
    await updateSmartContractBatch(parseInt(group), data);
  }
}

// New function to calculate generation based on hour
function calculateGeneration(hour) {
  if (hour >= 18 || hour < 6) return 0;
  
  const efficiencyMap = new Map([
    [[6, 17], 5],
    [[7, 16], 12],
    [[8, 15], 24],
    [[9, 14], 36],
    [[10, 13], 48],
    [[11, 12], 60]
  ]);
  
  for (const [[start, end], efficiency] of efficiencyMap) {
    if (hour === start || hour === end) {
      return efficiency * Math.floor(Math.random() * 20 + 1);
    }
  }
  return 0;
}

// New function to calculate consumption based on hour
function calculateConsumption(hour) {
  const consumptionMap = new Map([
    [[0, 6], 30],
    [[6, 9], 70],
    [[9, 12], 45],
    [[12, 15], 75],
    [[15, 18], 50],
    [[18, 21], 120],
    [[21, 24], 90]
  ]);
  
  for (const [[start, end], factor] of consumptionMap) {
    if (hour >= start && hour < end) {
      return factor * Math.round(5 * Math.floor(Math.random() * 5.5 + 0.5));
    }
  }
  return 0;
}


// New function to update smart contract in batches
async function updateSmartContractBatch(group, batchData) {
    try {
      // Add data to IPFS
      const { cid } = await ipfs.add(JSON.stringify(batchData));
      
      // Store CID on blockchain
      const gasEstimate1 = await contract.methods.storeEnergyCID(group, cid.toString())
        .estimateGas({ from: account.address });
  
      const tx1 = await contract.methods.storeEnergyCID(group, cid.toString())
        .send({
          from: account.address,
          gas: gasEstimate1,
          gasPrice: await web3.eth.getGasPrice()
        });

        const gasEstimate2 = await contract.methods.updateEnergyDataBatch(group, batchData)
        .estimateGas({ from: account.address });
    
        const tx2 = await contract.methods.updateEnergyDataBatch(group, batchData)
        .send({
            from: account.address,
            gas: gasEstimate2,
            gasPrice: await web3.eth.getGasPrice()
        });
  
      console.log(`Group ${group} CID: ${cid.toString()}`);
      console.log(`Batch update successful for group ${group}. Hash: ${tx2.transactionHash}`);
      console.log(`Processed ${batchData.length} records in this batch`);
      return cid;
    } catch (error) {
      console.error(`IPFS/Bchain error: ${error}`);
      throw error;
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
  
// Modified scheduler
schedule.scheduleJob('0 * * * *', () => {
  console.log('Running hourly simulation...');
  const newHour = new Date().getHours();
  simulateAndPublishDataByGroup(newHour-1);
});

console.log('IoT simulator started. Waiting for the next hour to begin simulation...');
