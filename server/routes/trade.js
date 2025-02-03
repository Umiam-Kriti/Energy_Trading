const express = require('express');
const Trade = require('../models/Trade');
const { matchOrders } = require('../utils/orderMatcher');
const router = express.Router();

// Submit a trade request
router.post('/submit', async (req, res) => {
    try {
        const { userId, tradeType, amount, price } = req.body;

        // Create trade entry
        const newTrade = new Trade({ userId, tradeType, amount, price });
        await newTrade.save();

        // Match orders
        matchOrders();

        res.json({ message: 'Trade submitted successfully', trade: newTrade });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Server error' });
    }
});

module.exports = router;
