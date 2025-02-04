// OrderBook Component
import React from "react";

interface OrderBookProps {
  market: string;
}
export function OrderBook({ market }: OrderBookProps) {
  return (
    <div className="p-4 border rounded-md bg-white shadow">
      <h3 className="text-lg font-semibold">Order Book - {market}</h3>
      {/* Order book table placeholder */}
      <div className="mt-2">Order Book Data...</div>
    </div>
  );
}

// BuySell Component
interface BuySellProps {
  market: string;
  setPrice: (price: number) => void;
}
export function BuySell({ market, setPrice }: BuySellProps) {
  return (
    <div className="p-4 border rounded-md bg-white shadow mt-4">
      <h3 className="text-lg font-semibold">Buy/Sell - {market}</h3>
      <input type="number" placeholder="Set Price" className="border p-2 w-full mt-2" onChange={(e) => setPrice(Number(e.target.value))} />
      <div className="flex justify-between mt-2">
        <button className="bg-green-500 text-white px-4 py-2 rounded">Buy</button>
        <button className="bg-red-500 text-white px-4 py-2 rounded">Sell</button>
      </div>
    </div>
  );
}

// TradeHistory Component
interface TradeHistoryProps {
  address: string;
}
export function TradeHistory({ address }: TradeHistoryProps) {
  return (
    <div className="p-4 border rounded-md bg-white shadow mt-4">
      <h3 className="text-lg font-semibold">Trade History</h3>
      <p className="text-sm">Showing trades for {address}</p>
      <div className="mt-2">Trade history data...</div>
    </div>
  );
}

// UserProfile Component
interface UserProfileProps {
  address: string;
}
export function UserProfile({ address }: UserProfileProps) {
  return (
    <div className="p-4 border rounded-md bg-white shadow mt-4">
      <h3 className="text-lg font-semibold">User Profile</h3>
      <p className="text-sm">User ID: {address}</p>
      <TradeHistory address={address} />
    </div>
  );
}

// Authentication Modal Component
interface AuthModalProps {
  onClose: () => void;
}
export function AuthModal({ onClose }: AuthModalProps) {
  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50">
      <div className="bg-white p-6 rounded shadow-lg w-96">
        <h2 className="text-xl font-bold mb-4">Login / Sign Up</h2>
        <input type="text" placeholder="Username" className="border p-2 w-full mb-2" />
        <input type="password" placeholder="Password" className="border p-2 w-full mb-2" />
        <div className="flex justify-between mt-2">
          <button className="bg-blue-500 text-white px-4 py-2 rounded">Login</button>
          <button className="bg-gray-500 text-white px-4 py-2 rounded">Sign Up</button>
        </div>
        <button onClick={onClose} className="mt-4 w-full bg-red-500 text-white px-4 py-2 rounded">Close</button>
      </div>
    </div>
  );
}