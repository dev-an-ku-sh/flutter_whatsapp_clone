const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  receiver: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  conversationId: {
    type: String,
    required: true,
    index: true,
  },
  content: {
    type: String,
    default: '',
  },
  messageType: {
    type: String,
    enum: ['text', 'image', 'emoji'],
    default: 'text',
  },
  imageUrl: {
    type: String,
    default: '',
  },
  replyTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
  },
  status: {
    type: String,
    enum: ['sent', 'delivered', 'read'],
    default: 'sent',
  },
  readAt: {
    type: Date,
    default: null,
  },
  deliveredAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

// Generate a consistent conversation ID from two user IDs
messageSchema.statics.getConversationId = function(userId1, userId2) {
  return [userId1, userId2].sort().join('_');
};

module.exports = mongoose.model('Message', messageSchema);
