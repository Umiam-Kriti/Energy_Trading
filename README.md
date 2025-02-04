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

## 📂 Folder Structure

```plaintext
scaffold-eth-2/
├── packages/
│   ├── hardhat/
│   │   ├── contracts/
│   │   │   ├── EnergyTradingL2.sol
│   │   │   ├── CarbonCredits.sol
│   │   │   ├── BridgeContract.sol
│   │   ├── deploy/
│   │   │   ├── 01_deployEnergyTrading.js
│   │   │   ├── 02_deployCarbonCredit.js
│   │   │   ├── 03_deployBridge.js
│   │   ├── test/
│   │   ├── README.md
│   ├── nextjs/
│   │   ├── app/ # Next.js App Router
│   │   │   ├── page.tsx # Homepage
│   │   │   ├── trading/page.tsx # Trading Page
│   │   │   ├── api/energy-trading.ts
│   │   ├── components/
│   │   │   ├── EnergyTrading.tsx
│   │   │   ├── CarbonCreditTrading.tsx
│   │   │   ├── AnalyticsDashboard.tsx
│   │   ├── hooks/useEnergyTrading.ts
│   │   ├── public/
│   ├── backend/
│   │   ├── iot/ # IoT Data Integration
│   │   ├── server.js
│   ├── final/
│   ├── README.md
│   ├── package.json
│   ├── yarn.lock
# README

## 🔧 Smart Contracts

| Contract                | Purpose                                                    |
|-------------------------|------------------------------------------------------------|
| `EnergyTradingL2.sol`   | Handles P2P energy trading, order matching, settlements. to reduce the gas fee this is deployed on L2 and in batches updated to the main chain using the bridging contract    |
| `CarbonCredits.sol`     | Automates carbon credit trading and prevents fraud.         |
| `BridgeContract.sol`    | Facilitates L2 energy trading and ensures security.         |

---

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

```

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




## 🛡 Privacy & Security
- **End-to-End Security:** Transactions are secured using blockchain.
- **Fraud Prevention:** Real-time monitoring of energy trading activities.
- **Privacy-Preserving Transactions:** ZK-SNARKs enable anonymous yet verifiable transactions.
---

## 📜 License
This project is licensed under the **MIT License**.

## 🔮 Future Enhancements
- **AI-Powered Demand Forecasting:** Implement machine learning models to predict energy demand and optimize trading.
- **Cross-Chain Interoperability:** Enable energy trading across multiple blockchain networks.
- **DeFi Integration:** Introduce decentralized finance mechanisms like staking and yield farming for energy tokens.
- **Dynamic Pricing Mechanism:** Develop an adaptive pricing algorithm based on real-time supply and demand.
- **Enhanced Scalability:** Implement rollups or sidechains to support large-scale transactions efficiently.
- **Advanced Privacy Solutions:** Explore zk-rollups and homomorphic encryption for even better data security.
- **Regulatory Compliance Features:** Integrate mechanisms for automated regulatory compliance and reporting.


