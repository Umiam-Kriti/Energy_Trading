const WebSocket = require('ws');

let wss;

const initWebSocket = (server) => {
    wss = new WebSocket.Server({ server });

    wss.on('connection', (ws) => {
        console.log('New WebSocket connection');

        ws.on('close', () => {
            console.log('WebSocket connection closed');
        });
    });
};

const broadcastTrade = (trade) => {
    if (wss) {
        wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify(trade));
            }
        });
    }
};

module.exports = { initWebSocket, broadcastTrade };
