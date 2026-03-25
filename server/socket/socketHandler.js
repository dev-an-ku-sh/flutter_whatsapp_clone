const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Message = require('../models/Message');

module.exports = (io) => {
  // Auth middleware for socket
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      if (!token) {
        return next(new Error('Authentication error'));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id);

      if (!user) {
        return next(new Error('User not found'));
      }

      socket.userId = user._id.toString();
      socket.user = user;
      next();
    } catch (error) {
      next(new Error('Authentication error'));
    }
  });

  io.on('connection', async (socket) => {
    console.log(`User connected: ${socket.user.name} (${socket.userId})`);

    // Mark user as online
    await User.findByIdAndUpdate(socket.userId, {
      isOnline: true,
      socketId: socket.id,
    });

    // Broadcast online status
    socket.broadcast.emit('user_online', {
      userId: socket.userId,
      isOnline: true,
    });

    // Join personal room for targeted messages
    socket.join(socket.userId);

    // ---- SEND MESSAGE ----
    socket.on('send_message', async (data) => {
      try {
        const { receiverId, content, messageType = 'text', imageUrl = '', replyToId = null } = data;

        const conversationId = Message.getConversationId(socket.userId, receiverId);

        const message = await Message.create({
          sender: socket.userId,
          receiver: receiverId,
          conversationId,
          content,
          messageType,
          imageUrl,
          replyTo: replyToId,
          status: 'sent',
        });

        const populated = await Message.findById(message._id)
          .populate('sender', 'name avatar')
          .populate('receiver', 'name avatar')
          .populate('replyTo', 'content sender messageType');

        // Send to receiver
        const receiverUser = await User.findById(receiverId);
        if (receiverUser && receiverUser.isOnline) {
          io.to(receiverId).emit('new_message', populated);

          // Auto mark as delivered
          message.status = 'delivered';
          message.deliveredAt = new Date();
          await message.save();

          // Notify sender of delivery
          io.to(socket.userId).emit('message_status_update', {
            messageId: message._id,
            status: 'delivered',
            conversationId,
          });
        }

        // Send back to sender (confirmation)
        socket.emit('message_sent', populated);

        // Notify both about conversation update
        io.to(socket.userId).emit('conversation_update', { conversationId });
        io.to(receiverId).emit('conversation_update', { conversationId });
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    // ---- TYPING INDICATORS ----
    socket.on('typing_start', (data) => {
      io.to(data.receiverId).emit('typing_start', {
        userId: socket.userId,
        name: socket.user.name,
      });
    });

    socket.on('typing_stop', (data) => {
      io.to(data.receiverId).emit('typing_stop', {
        userId: socket.userId,
      });
    });

    // ---- MARK AS READ ----
    socket.on('mark_read', async (data) => {
      try {
        const { senderId } = data;
        const conversationId = Message.getConversationId(socket.userId, senderId);

        const result = await Message.updateMany(
          {
            conversationId,
            sender: senderId,
            receiver: socket.userId,
            status: { $ne: 'read' },
          },
          {
            status: 'read',
            readAt: new Date(),
          }
        );

        if (result.modifiedCount > 0) {
          // Notify the sender that messages were read
          io.to(senderId).emit('messages_read', {
            readBy: socket.userId,
            conversationId,
          });
        }
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    // ---- DISCONNECT ----
    socket.on('disconnect', async () => {
      console.log(`User disconnected: ${socket.user.name}`);

      await User.findByIdAndUpdate(socket.userId, {
        isOnline: false,
        lastSeen: new Date(),
        socketId: '',
      });

      socket.broadcast.emit('user_online', {
        userId: socket.userId,
        isOnline: false,
        lastSeen: new Date(),
      });
    });
  });
};
