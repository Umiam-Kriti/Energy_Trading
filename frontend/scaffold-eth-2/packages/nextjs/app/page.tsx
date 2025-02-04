"use client";

import { useState } from "react";
import dynamic from "next/dynamic";

const CarbonCreditTrading = dynamic(() => import("../components/CarbonCreditTrading"), { ssr: false });
const EnergyTrading = dynamic(() => import("../components/EnergyTrading").then(mod => mod.default), { ssr: false });


export default function Dashboard() {
  const [activeSection, setActiveSection] = useState<string | null>(null);

  return (
    <div className="min-h-screen bg-gray-100">
      <nav className="bg-white p-4 shadow-md flex justify-between">
        <h1 className="text-xl font-bold">Dashboard</h1>
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
