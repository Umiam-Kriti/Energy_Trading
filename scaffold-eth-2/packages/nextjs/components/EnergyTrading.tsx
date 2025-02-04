"use client";

import { useState } from "react";

export default function EnergyTrading() {
  const [orderBook, setOrderBook] = useState([
    { price: 50, amount: 100, type: "buy" },
    { price: 48, amount: 200, type: "sell" },
  ]);
  const [tradePrice, setTradePrice] = useState(50);
  const [tradeAmount, setTradeAmount] = useState(1);

  const handleTrade = (type: string) => {
    alert(`${type} order placed at ${tradePrice} for ${tradeAmount} units!`);
  };

  return (
    <div className="p-6 bg-white shadow-md rounded-lg">
      <h2 className="text-lg font-bold mb-4">Energy Trading</h2>

      {/* Order Book */}
      <div className="mt-4">
        <h3 className="text-md font-bold">Order Book</h3>
        <ul className="mt-2">
          {orderBook.map((order, index) => (
            <li key={index} className={order.type === "buy" ? "text-green-600" : "text-red-600"}>
              {order.type.toUpperCase()} - {order.amount} Units @ {order.price} USD
            </li>
          ))}
        </ul>
      </div>

      {/* Trade Controls */}
      <div className="mt-4">
        <label className="block text-sm font-medium text-gray-700">Set Price:</label>
        <input
          type="number"
          className="border p-2 w-full rounded-md"
          value={tradePrice}
          onChange={(e) => setTradePrice(Number(e.target.value))}
        />
      </div>

      <div className="mt-4">
        <label className="block text-sm font-medium text-gray-700">Set Amount:</label>
        <input
          type="number"
          className="border p-2 w-full rounded-md"
          value={tradeAmount}
          onChange={(e) => setTradeAmount(Number(e.target.value))}
        />
      </div>

      {/* Buy/Sell Buttons */}
      <div className="mt-4 flex space-x-4">
        <button className="bg-green-500 text-white px-4 py-2 rounded-lg" onClick={() => handleTrade("Buy")}>
          Buy
        </button>
        <button className="bg-red-500 text-white px-4 py-2 rounded-lg" onClick={() => handleTrade("Sell")}>
          Sell
        </button>
      </div>
    </div>
  );
}
