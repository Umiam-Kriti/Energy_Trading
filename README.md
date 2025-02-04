# EnergyChain Challenge - Decentralized P2P Energy Trading

## ⚡ Solution Overview
The **EnergyChain Challenge** is a decentralized, blockchain-powered platform designed to revolutionize the energy sector by enabling **peer-to-peer (P2P) energy trading**. Our solution ensures **energy security, equity, and environmental sustainability** by leveraging **smart contracts, IoT devices, and ZK-SNARKs** to create a **secure, transparent, and efficient** energy trading system.

### 🚀 Key Features:
- **Decentralized P2P Energy Trading:** Enables prosumers (energy producers and consumers) to trade energy directly.
- **Automated Carbon Credit System:** Real-time verification and issuance of carbon credits for renewable energy producers.
- **IoT & Smart Meter Integration:** Ensures accurate tracking of energy production and consumption.
- **ZK-SNARKs for Privacy:** Maintains confidentiality of transactions while ensuring verifiability.
- **Optimized Order Matching:** Smart contracts facilitate efficient and automated trading settlements.
- **Secure & Scalable L2 Architecture:** Utilizes an L2 scaling solution for fast and cost-effective transactions.

---

## 🛠 System Architecture

### 🔗 Blockchain Layer
- **Smart Contracts:** Handle energy trading, settlements, and carbon credit issuance.
- **Consensus Mechanism:** Ensures secure and immutable transactions.
- **Privacy Layer:** Uses **ZK-SNARKs** for privacy-preserving transactions.

### ⚡ Energy Trading Mechanism
1. **Prosumers list available energy** for sale.
2. **Buyers place orders** via smart contracts.
3. **Smart contracts match orders** and execute transactions in real-time.
4. **Fallback system:** Unsold energy is transferred to the grid operator.

### 📜 Carbon Credit Verification
- **Automatic Minting:** Renewable energy producers receive carbon credits based on their contribution.
- **Double-Spend Prevention:** Ensures legitimacy using blockchain verification.

### 📡 IoT & Smart Meter Integration
- IoT devices monitor energy production & consumption.
- Data is recorded **on-chain** for transparency and fraud prevention.

---

## ⚙️ How to Run the Project

### 1️⃣ Install Dependencies
Ensure you have **Node.js** and **Yarn** installed. Then, run:
```bash
yarn install
```

### 2️⃣ Compile Smart Contracts
```bash
yarn hardhat chain`
```

### 3️⃣ Deploy Contracts to Local Network
```bash
yarn hardhat deploy 
```

### 4️⃣ Start the Frontend
```bash
yarn start
```
This will start the **Next.js** frontend at `http://localhost:3000`.

### 5️⃣ Run IoT Backend Server
```bash
node packages/backend/server.js
```
This will connect to **IoT devices and smart meters** for real-time data collection.

---

## 🛡 Privacy & Security
- **End-to-End Security:** Transactions are secured using blockchain.
- **Fraud Prevention:** Real-time monitoring of energy trading activities.
- **Privacy-Preserving Transactions:** ZK-SNARKs enable anonymous yet verifiable transactions.

---

## 📜 License
This project is licensed under the **MIT License**.
