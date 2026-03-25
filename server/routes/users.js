const express = require('express');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Search users
router.get('/search', protect, async (req, res) => {
  try {
    const { q } = req.query;
    if (!q || q.length < 2) {
      return res.json({ users: [] });
    }

    const users = await User.find({
      _id: { $ne: req.user._id },
      $or: [
        { name: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } },
      ],
    }).limit(20);

    res.json({ users });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get all users (for contacts list)
router.get('/', protect, async (req, res) => {
  try {
    const users = await User.find({ _id: { $ne: req.user._id } })
      .sort({ isOnline: -1, name: 1 });
    res.json({ users });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get user by ID
router.get('/:id', protect, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json({ user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Update profile
router.put('/profile', protect, async (req, res) => {
  try {
    const { name, about, avatar } = req.body;
    const user = await User.findByIdAndUpdate(
      req.user._id,
      { name, about, avatar },
      { new: true, runValidators: true }
    );
    res.json({ user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
