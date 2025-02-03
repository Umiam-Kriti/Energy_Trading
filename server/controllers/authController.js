const jwt = require('jsonwebtoken');
const User = require('../models/User');
const verifyZKProof = require('../utils/zkVerifier');

const loginWithZK = async (req, res) => {
  const { email, proof, publicSignals } = req.body;

  try {
    // Verify ZK proof
    const isValid = await verifyZKProof(proof, publicSignals);
    if (!isValid) {
      return res.status(401).json({ message: 'Invalid ZK proof.' });
    }

    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    // Validate ZK proof matches user's hashed data
    if (publicSignals[0] !== user.hashedData) {
      return res.status(401).json({ message: 'Proof does not match user data.' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user._id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    res.json({ token, message: 'Login successful' });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = { loginWithZK };
