const Trade = require('../models/Trade');
const { broadcastTrade } = require('./websocket');

const matchOrders = async () => {
    try {
        const buyOrders = await Trade.find({ tradeType: 'buy', status: 'pending' }).sort({ price: -1 });
        const sellOrders = await Trade.find({ tradeType: 'sell', status: 'pending' }).sort({ price: 1 });

        for (let buy of buyOrders) {
            for (let sell of sellOrders) {
                if (buy.price >= sell.price && buy.amount === sell.amount) {
                    // Match found
                    buy.status = sell.status = 'matched';
                    await buy.save();
                    await sell.save();

                    console.log(`Trade Matched: ${buy.userId} bought from ${sell.userId} at ${sell.price}`);

                    // Broadcast trade update
                    broadcastTrade({ buy, sell });
                    return;
                }
            }
        }
    } catch (err) {
        console.error(err);
    }
};

module.exports = { matchOrders };
