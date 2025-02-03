const mongoose = require('mongoose');

const TradeSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    tradeType: { type: String, enum: ['buy', 'sell'], required: true },
    amount: { type: Number, required: true },
    price: { type: Number, required: true },
    status: { type: String, enum: ['pending', 'matched', 'completed'], default: 'pending' },
    timestamp: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Trade', TradeSchema);
