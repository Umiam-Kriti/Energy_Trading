"use client";

import { useState } from "react";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS, LineElement, CategoryScale, LinearScale, PointElement } from "chart.js";

ChartJS.register(LineElement, CategoryScale, LinearScale, PointElement);

export default function CarbonCreditTrading() {
  const [orderBook, setOrderBook] = useState([
    { price: 1.2, amount: 100, type: "buy" },
    { price: 1.15, amount: 200, type: "sell" },
  ]);

  const data = {
    labels: ["10 AM", "11 AM", "12 PM", "1 PM", "2 PM"],
    datasets: [
      {
        label: "CCT/USDT Price",
        data: [1.1, 1.15, 1.2, 1.18, 1.22],
        borderColor: "#3b82f6",
        borderWidth: 2,
        fill: false,
      },
    ],
  };

  const handleTrade = (type: string) => {
    alert(`${type} order placed!`);
  };

  return (
    <div className="p-6 bg-white shadow-md rounded-lg">
      <h2 className="text-lg font-bold mb-4">Carbon Credit Trading</h2>
      
      {/* Graph */}
      <Line data={data} />
      
      {/* Order Book */}
      <div className="mt-4">
        <h3 className="text-md font-bold">Order Book</h3>
        <ul className="mt-2">
          {orderBook.map((order, index) => (
            <li key={index} className={order.type === "buy" ? "text-green-600" : "text-red-600"}>
              {order.type.toUpperCase()} - {order.amount} CCT @ {order.price} USDT
            </li>
          ))}
        </ul>
      </div>

      {/* Buy/Sell Buttons */}
      <div className="mt-4 flex space-x-4">
        <button className="bg-green-500 text-white px-4 py-2 rounded-lg" onClick={() => handleTrade("Buy")}>Buy</button>
        <button className="bg-red-500 text-white px-4 py-2 rounded-lg" onClick={() => handleTrade("Sell")}>Sell</button>
      </div>
    </div>
  );
}
