const express = require('express');
const bodyParser = require('body-parser');
const connectDB = require('./db');
const authRoutes = require('./routes/auth');
const dotenv = require('dotenv');
const tradeRoutes = require('./routes/trade');
const { initWebSocket } = require('./utils/websocket');

dotenv.config();
const app = express();

// Middleware
app.use(bodyParser.json());
app.use('/auth', authRoutes);
app.use('/trade', tradeRoutes);

// Connect database
connectDB();

// Start server
const PORT = process.env.PORT || 6000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

initWebSocket(server);