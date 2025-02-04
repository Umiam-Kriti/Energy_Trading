"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import dynamic from "next/dynamic";

const CarbonCreditTrading = dynamic(() => import("../components/CarbonCreditTrading"), { ssr: false });
const EnergyTrading = dynamic(() => import("../components/EnergyTrading"), { ssr: false });

export default function Home() {
  const router = useRouter();
  const [isDashboard, setIsDashboard] = useState(false);
  const [activeSection, setActiveSection] = useState<string | null>(null);
  const [showProfileMenu, setShowProfileMenu] = useState(false);

  const handleLogin = () => {
    setIsDashboard(true);
  };

  if (isDashboard) {
    return (
      <div className="min-h-screen bg-gray-100">
        <nav className="bg-white p-4 shadow-md flex justify-between">
          <h1 className="text-xl font-bold">Energy Chain Dashboard</h1>
          <div className="relative">
            <button
              className="bg-gray-200 px-4 py-2 rounded-lg"
              onClick={() => setShowProfileMenu(!showProfileMenu)}
            >
              User Profile
            </button>
            {showProfileMenu && (
              <div className="absolute right-0 mt-2 w-48 bg-white shadow-lg rounded-lg">
                <p className="px-4 py-2">User ID: User123</p>
                <button className="block px-4 py-2 w-full text-left">Trade History</button>
                <button
                  className="block px-4 py-2 w-full text-left text-red-600"
                  onClick={() => setIsDashboard(false)}
                >
                  Logout
                </button>
              </div>
            )}
          </div>
        </nav>

        <div className="p-6 grid grid-cols-2 gap-4">
          <div
            className="p-6 bg-white shadow-md rounded-lg cursor-pointer"
            onClick={() => setActiveSection("carbon-credit")}
          >
            <h2 className="text-lg font-bold">Carbon Credit Trading</h2>
          </div>
          <div
            className="p-6 bg-white shadow-md rounded-lg cursor-pointer"
            onClick={() => setActiveSection("energy-trading")}
          >
            <h2 className="text-lg font-bold">Energy Trading</h2>
          </div>
        </div>

        {activeSection === "carbon-credit" && <CarbonCreditTrading />}
        {activeSection === "energy-trading" && <EnergyTrading />}
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center h-screen bg-gray-100">
      <div className="p-6 bg-white shadow-md rounded-lg text-center">
        <h1 className="text-xl font-bold mb-4">Welcome to Energy Chain</h1>
        <button
          className="bg-blue-500 text-white px-4 py-2 rounded-lg"
          onClick={handleLogin}
        >
          Login / Sign Up
        </button>
      </div>
    </div>
  );
}
