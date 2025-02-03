const express = require('express');
const { generateProof, verifyProof } = require('../zkSnarks');
const User = require('../models/User');
const { loginWithZK } = require('../controllers/authController');

const router = express.Router();

// Register user
router.post('/zk-login', loginWithZK);
router.post('/register', async (req, res) => {
    const { userId, publicKey, input, circuitPath } = req.body;

    try {
        // Generate proof
        const { proof, publicSignals } = await generateProof(input, circuitPath);

        // Store user in the database
        const user = new User({
            userId,
            publicKey,
            proof: JSON.stringify(proof),
        });
        await user.save();

        res.status(200).json({ message: "User registered successfully", proof });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Authenticate user
router.post('/authenticate', async (req, res) => {
    const { userId, input, circuitPath, verificationKeyPath } = req.body;

    try {
        // Fetch user from the database
        const user = await User.findOne({ userId });
        if (!user) return res.status(404).json({ message: "User not found" });

        // Generate proof for validation
        const { proof, publicSignals } = await generateProof(input, circuitPath);

        // Verify proof
        const isValid = await verifyProof(
            proof,
            publicSignals,
            verificationKeyPath
        );

        if (isValid) {
            res.status(200).json({ message: "Authentication successful" });
        } else {
            res.status(401).json({ message: "Authentication failed" });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
