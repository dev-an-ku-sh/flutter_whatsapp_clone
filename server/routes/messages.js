const express = require('express');
const Message = require('../models/Message');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Get conversations list (unique chats with last message)
router.get('/conversations', protect, async (req, res) => {
  try {
    const userId = req.user._id;

    const conversations = await Message.aggregate([
      {
        $match: {
          $or: [{ sender: userId }, { receiver: userId }],
        },
      },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: '$conversationId',
          lastMessage: { $first: '$$ROOT' },
          unreadCount: {
            $sum: {
              $cond: [
                {
                  $and: [
                    { $eq: ['$receiver', userId] },
                    { $ne: ['$status', 'read'] },
                  ],
                },
                1,
                0,
              ],
            },
          },
        },
      },
      { $sort: { 'lastMessage.createdAt': -1 } },
    ]);

    // Populate sender and receiver
    const populated = await Message.populate(conversations, [
      { path: 'lastMessage.sender', model: 'User', select: 'name email avatar isOnline lastSeen' },
      { path: 'lastMessage.receiver', model: 'User', select: 'name email avatar isOnline lastSeen' },
    ]);

    res.json({ conversations: populated });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get messages for a conversation
router.get('/:userId', protect, async (req, res) => {
  try {
    const conversationId = Message.getConversationId(
      req.user._id.toString(),
      req.params.userId
    );

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const messages = await Message.find({ conversationId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('sender', 'name avatar')
      .populate('receiver', 'name avatar')
      .populate('replyTo', 'content sender messageType');

    const total = await Message.countDocuments({ conversationId });

    res.json({
      messages: messages.reverse(),
      hasMore: skip + limit < total,
      total,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Mark messages as read
router.put('/read/:userId', protect, async (req, res) => {
  try {
    const conversationId = Message.getConversationId(
      req.user._id.toString(),
      req.params.userId
    );

    await Message.updateMany(
      {
        conversationId,
        receiver: req.user._id,
        status: { $ne: 'read' },
      },
      {
        status: 'read',
        readAt: new Date(),
      }
    );

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
