"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function Dashboard() {
  const router = useRouter();
  const [userId] = useState("User123");

  const handleLogout = () => {
    router.push("/"); // Redirect to homepage on logout
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Navbar Section */}
      <nav className="bg-white p-4 shadow-md flex justify-between">
        <h1 className="text-xl font-bold">Dashboard</h1>
        <div className="relative">
          <button className="bg-gray-200 px-4 py-2 rounded-lg">Profile</button>
          <div className="absolute right-0 mt-2 w-48 bg-white shadow-lg rounded-lg">
            <p className="px-4 py-2">User ID: {userId}</p>
            <button className="block px-4 py-2 w-full text-left">Trade History</button>
            <button
              className="block px-4 py-2 w-full text-left text-red-600"
              onClick={handleLogout}
            >
              Logout
            </button>
          </div>
        </div>
      </nav>

      {/* Dashboard Sections */}
      <div className="p-6 grid grid-cols-2 gap-4">
        <div className="p-6 bg-white shadow-md rounded-lg">
          <h2 className="text-lg font-bold">Carbon Credit Trading</h2>
        </div>
        <div className="p-6 bg-white shadow-md rounded-lg">
          <h2 className="text-lg font-bold">Energy Trading</h2>
        </div>
      </div>
    </div>
  );
}
