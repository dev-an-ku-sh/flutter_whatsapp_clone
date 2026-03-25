require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const server = http.createServer(app);

app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'], credentials: true }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// In-memory image store (base64)
const imageStore = {};
let nextImageId = 1;

// ========== IN-MEMORY STORE ==========
const users = [];
const messages = [];
const groups = [];
let nextUserId = 1;
let nextMsgId = 1;
let nextGroupId = 1;

const JWT_SECRET = process.env.JWT_SECRET || 'chatapp_secret_2026';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

function generateToken(id) {
  return jwt.sign({ id }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function findUserById(id) {
  return users.find(u => u._id === id);
}

function findUserByEmail(email) {
  return users.find(u => u.email === email.toLowerCase());
}

function sanitizeUser(u) {
  if (!u) return null;
  const { password, ...safe } = u;
  return safe;
}

function getConversationId(id1, id2) {
  return [id1, id2].sort().join('_');
}

// ========== AUTH MIDDLEWARE ==========
function protect(req, res, next) {
  try {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith('Bearer')) {
      return res.status(401).json({ message: 'Not authorized' });
    }
    const token = auth.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = findUserById(decoded.id);
    if (!user) return res.status(401).json({ message: 'User not found' });
    req.user = user;
    next();
  } catch (e) {
    return res.status(401).json({ message: 'Token failed' });
  }
}

// ========== AUTH ROUTES ==========
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (findUserByEmail(email)) {
      return res.status(400).json({ message: 'User already exists' });
    }
    const hashed = await bcrypt.hash(password, 12);
    const user = {
      _id: String(nextUserId++),
      name,
      email: email.toLowerCase(),
      password: hashed,
      avatar: '',
      about: 'Hey there! I am using ChatApp',
      isOnline: false,
      lastSeen: new Date().toISOString(),
      socketId: '',
      createdAt: new Date().toISOString(),
    };
    users.push(user);
    const token = generateToken(user._id);
    res.status(201).json({ token, user: sanitizeUser(user) });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = findUserByEmail(email);
    if (!user) return res.status(401).json({ message: 'Invalid email or password' });
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ message: 'Invalid email or password' });
    const token = generateToken(user._id);
    res.json({ token, user: sanitizeUser(user) });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

app.get('/api/auth/me', protect, (req, res) => {
  res.json({ user: sanitizeUser(req.user) });
});

// ========== USER ROUTES ==========
app.get('/api/users/search', protect, (req, res) => {
  const q = (req.query.q || '').toLowerCase();
  if (q.length < 2) return res.json({ users: [] });
  const results = users
    .filter(u => u._id !== req.user._id)
    .filter(u => u.name.toLowerCase().includes(q) || u.email.includes(q))
    .slice(0, 20)
    .map(sanitizeUser);
  res.json({ users: results });
});

app.get('/api/users', protect, (req, res) => {
  const result = users
    .filter(u => u._id !== req.user._id)
    .map(sanitizeUser);
  res.json({ users: result });
});

app.get('/api/users/:id', protect, (req, res) => {
  const user = findUserById(req.params.id);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json({ user: sanitizeUser(user) });
});

// Update profile
app.put('/api/users/profile', protect, (req, res) => {
  const { name, about, avatar } = req.body;
  if (name) req.user.name = name;
  if (about !== undefined) req.user.about = about;
  if (avatar !== undefined) req.user.avatar = avatar;
  res.json({ user: sanitizeUser(req.user) });
});

// ========== IMAGE UPLOAD ==========
app.post('/api/upload', protect, (req, res) => {
  try {
    const { base64, filename } = req.body;
    if (!base64) return res.status(400).json({ message: 'No image data' });
    const imageId = String(nextImageId++);
    imageStore[imageId] = base64;
    const url = `/api/images/${imageId}`;
    res.json({ url, imageId });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Serve images
app.get('/api/images/:id', (req, res) => {
  const data = imageStore[req.params.id];
  if (!data) return res.status(404).json({ message: 'Image not found' });
  // data is like "data:image/png;base64,xxxx"
  const matches = data.match(/^data:(.+);base64,(.+)$/);
  if (matches) {
    const mime = matches[1];
    const buffer = Buffer.from(matches[2], 'base64');
    res.set('Content-Type', mime);
    res.send(buffer);
  } else {
    const buffer = Buffer.from(data, 'base64');
    res.set('Content-Type', 'image/png');
    res.send(buffer);
  }
});

// ========== DELETE MESSAGE ==========
app.delete('/api/messages/:messageId', protect, (req, res) => {
  const idx = messages.findIndex(m => m._id === req.params.messageId && m.sender === req.user._id);
  if (idx === -1) return res.status(404).json({ message: 'Message not found' });
  messages.splice(idx, 1);
  res.json({ success: true });
});

// ========== SEARCH MESSAGES ==========
app.get('/api/messages/search/:userId', protect, (req, res) => {
  const q = (req.query.q || '').toLowerCase();
  if (q.length < 2) return res.json({ messages: [] });
  const cid = getConversationId(req.user._id, req.params.userId);
  const results = messages
    .filter(m => m.conversationId === cid && m.content.toLowerCase().includes(q))
    .slice(-20)
    .map(m => ({
      ...m,
      sender: sanitizeUser(findUserById(m.sender)) || { _id: m.sender },
      receiver: sanitizeUser(findUserById(m.receiver)) || { _id: m.receiver },
    }));
  res.json({ messages: results });
});

// ========== MESSAGE ROUTES ==========
app.get('/api/messages/conversations', protect, (req, res) => {
  const userId = req.user._id;
  const convMap = {};

  // Get all messages involving this user
  for (const msg of messages) {
    if (msg.sender !== userId && msg.receiver !== userId) continue;
    const cid = msg.conversationId;
    if (!convMap[cid]) {
      convMap[cid] = { lastMessage: msg, unreadCount: 0 };
    }
    // Update to latest message
    if (new Date(msg.createdAt) > new Date(convMap[cid].lastMessage.createdAt)) {
      convMap[cid].lastMessage = msg;
    }
    // Count unread
    if (msg.receiver === userId && msg.status !== 'read') {
      convMap[cid].unreadCount++;
    }
  }

  const conversations = Object.entries(convMap).map(([cid, data]) => {
    const lm = data.lastMessage;
    const senderUser = findUserById(lm.sender);
    const receiverUser = findUserById(lm.receiver);
    return {
      _id: cid,
      lastMessage: {
        ...lm,
        sender: sanitizeUser(senderUser) || { _id: lm.sender },
        receiver: sanitizeUser(receiverUser) || { _id: lm.receiver },
      },
      unreadCount: data.unreadCount,
    };
  });

  conversations.sort((a, b) =>
    new Date(b.lastMessage.createdAt) - new Date(a.lastMessage.createdAt)
  );

  res.json({ conversations });
});

app.get('/api/messages/:userId', protect, (req, res) => {
  const cid = getConversationId(req.user._id, req.params.userId);
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 50;

  const convMessages = messages
    .filter(m => m.conversationId === cid)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));

  const total = convMessages.length;
  const start = Math.max(0, total - page * limit);
  const end = total - (page - 1) * limit;
  const pageMessages = convMessages.slice(start, end);

  const populated = pageMessages.map(m => {
    const result = {
      ...m,
      sender: sanitizeUser(findUserById(m.sender)) || { _id: m.sender },
      receiver: sanitizeUser(findUserById(m.receiver)) || { _id: m.receiver },
    };
    if (m.replyTo) {
      const replyMsg = messages.find(r => r._id === m.replyTo);
      if (replyMsg) {
        result.replyTo = { _id: replyMsg._id, content: replyMsg.content };
      }
    }
    return result;
  });

  res.json({ messages: populated, hasMore: start > 0, total });
});

app.put('/api/messages/read/:userId', protect, (req, res) => {
  const cid = getConversationId(req.user._id, req.params.userId);
  for (const msg of messages) {
    if (msg.conversationId === cid && msg.receiver === req.user._id && msg.status !== 'read') {
      msg.status = 'read';
      msg.readAt = new Date().toISOString();
    }
  }
  res.json({ success: true });
});

// ========== GROUP ROUTES ==========
app.post('/api/groups', protect, (req, res) => {
  const { name, description, memberIds } = req.body;
  if (!name || !memberIds || memberIds.length < 1) {
    return res.status(400).json({ message: 'Name and at least 1 member required' });
  }
  const allMembers = [...new Set([req.user._id, ...memberIds])];
  const group = {
    _id: `group_${nextGroupId++}`,
    name,
    description: description || '',
    avatar: '',
    createdBy: req.user._id,
    memberIds: allMembers,
    createdAt: new Date().toISOString(),
  };
  groups.push(group);
  const populated = {
    ...group,
    members: allMembers.map(id => sanitizeUser(findUserById(id))).filter(Boolean),
  };
  // Notify all members
  allMembers.forEach(id => {
    io.to(id).emit('group_created', populated);
  });
  res.status(201).json({ group: populated });
});

app.get('/api/groups', protect, (req, res) => {
  const userGroups = groups
    .filter(g => g.memberIds.includes(req.user._id))
    .map(g => {
      const lastMsg = messages
        .filter(m => m.conversationId === g._id)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];
      return {
        ...g,
        members: g.memberIds.map(id => sanitizeUser(findUserById(id))).filter(Boolean),
        lastMessage: lastMsg ? {
          ...lastMsg,
          sender: sanitizeUser(findUserById(lastMsg.sender)) || { _id: lastMsg.sender },
        } : null,
        unreadCount: messages.filter(m =>
          m.conversationId === g._id && m.sender !== req.user._id && m.status !== 'read'
        ).length,
      };
    });
  res.json({ groups: userGroups });
});

app.get('/api/groups/:groupId/messages', protect, (req, res) => {
  const groupId = req.params.groupId;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 50;
  const groupMessages = messages
    .filter(m => m.conversationId === groupId)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
  const total = groupMessages.length;
  const start = Math.max(0, total - page * limit);
  const end = total - (page - 1) * limit;
  const pageMessages = groupMessages.slice(start, end).map(m => ({
    ...m,
    sender: sanitizeUser(findUserById(m.sender)) || { _id: m.sender },
  }));
  res.json({ messages: pageMessages, hasMore: start > 0, total });
});

// ========== HEALTH ==========
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', users: users.length, messages: messages.length });
});

// ========== SOCKET.IO ==========
const io = new Server(server, { cors: { origin: '*', methods: ['GET', 'POST'] } });

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Auth error'));
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = findUserById(decoded.id);
    if (!user) return next(new Error('User not found'));
    socket.userId = user._id;
    socket.user = user;
    next();
  } catch (e) {
    next(new Error('Auth error'));
  }
});

io.on('connection', (socket) => {
  console.log(`✅ ${socket.user.name} connected`);

  // Mark online
  socket.user.isOnline = true;
  socket.user.socketId = socket.id;
  socket.broadcast.emit('user_online', { userId: socket.userId, isOnline: true });
  socket.join(socket.userId);

  // SEND MESSAGE
  socket.on('send_message', (data) => {
    const { receiverId, content, messageType = 'text', imageUrl = '', replyToId = null } = data;
    const cid = getConversationId(socket.userId, receiverId);

    const msg = {
      _id: String(nextMsgId++),
      sender: socket.userId,
      receiver: receiverId,
      conversationId: cid,
      content,
      messageType,
      imageUrl,
      replyTo: replyToId,
      status: 'sent',
      createdAt: new Date().toISOString(),
      readAt: null,
      deliveredAt: null,
    };
    messages.push(msg);

    const populated = {
      ...msg,
      sender: sanitizeUser(findUserById(socket.userId)),
      receiver: sanitizeUser(findUserById(receiverId)),
    };

    // Populate replyTo content if replying
    if (replyToId) {
      const replyMsg = messages.find(m => m._id === replyToId);
      if (replyMsg) {
        populated.replyTo = { _id: replyMsg._id, content: replyMsg.content };
      }
    }

    // Send to receiver if online
    const receiverUser = findUserById(receiverId);
    if (receiverUser && receiverUser.isOnline) {
      io.to(receiverId).emit('new_message', populated);
      msg.status = 'delivered';
      msg.deliveredAt = new Date().toISOString();
      io.to(socket.userId).emit('message_status_update', {
        messageId: msg._id, status: 'delivered', conversationId: cid,
      });
    }

    // Confirm to sender
    socket.emit('message_sent', { ...populated, status: msg.status });
    io.to(socket.userId).emit('conversation_update', { conversationId: cid });
    io.to(receiverId).emit('conversation_update', { conversationId: cid });
  });

  // TYPING
  socket.on('typing_start', (data) => {
    io.to(data.receiverId).emit('typing_start', {
      userId: socket.userId, name: socket.user.name,
    });
  });
  socket.on('typing_stop', (data) => {
    io.to(data.receiverId).emit('typing_stop', { userId: socket.userId });
  });

  // MARK READ
  socket.on('mark_read', (data) => {
    const { senderId } = data;
    const cid = getConversationId(socket.userId, senderId);
    let modified = 0;
    for (const msg of messages) {
      if (msg.conversationId === cid && msg.sender === senderId &&
          msg.receiver === socket.userId && msg.status !== 'read') {
        msg.status = 'read';
        msg.readAt = new Date().toISOString();
        modified++;
      }
    }
    if (modified > 0) {
      io.to(senderId).emit('messages_read', {
        readBy: socket.userId, conversationId: cid,
      });
    }
  });

  // DELETE MESSAGE (real-time)
  socket.on('delete_message', (data) => {
    const { messageId } = data;
    const idx = messages.findIndex(m => m._id === messageId && m.sender === socket.userId);
    if (idx !== -1) {
      const msg = messages[idx];
      messages.splice(idx, 1);
      // Notify the other user
      const otherId = msg.receiver === socket.userId ? msg.sender : msg.receiver;
      io.to(otherId).emit('message_deleted', { messageId, conversationId: msg.conversationId });
      socket.emit('message_deleted', { messageId, conversationId: msg.conversationId });
    }
  });

  // GROUP MESSAGE
  socket.on('send_group_message', (data) => {
    const { groupId, content, messageType = 'text', imageUrl = '' } = data;
    const group = groups.find(g => g._id === groupId);
    if (!group || !group.memberIds.includes(socket.userId)) return;

    const msg = {
      _id: String(nextMsgId++),
      sender: socket.userId,
      receiver: null,
      conversationId: groupId,
      content,
      messageType,
      imageUrl,
      replyTo: null,
      status: 'sent',
      createdAt: new Date().toISOString(),
      readAt: null,
      deliveredAt: null,
      isGroup: true,
    };
    messages.push(msg);

    const populated = {
      ...msg,
      sender: sanitizeUser(findUserById(socket.userId)),
    };

    // Send to all online group members (except sender)
    group.memberIds.forEach(memberId => {
      if (memberId !== socket.userId) {
        io.to(memberId).emit('new_message', populated);
      }
    });
    // Confirm to sender
    socket.emit('message_sent', populated);
  });

  // Auto-join group rooms
  groups.filter(g => g.memberIds.includes(socket.userId)).forEach(g => {
    socket.join(g._id);
  });

  // DISCONNECT
  socket.on('disconnect', () => {
    console.log(`❌ ${socket.user.name} disconnected`);
    socket.user.isOnline = false;
    socket.user.lastSeen = new Date().toISOString();
    socket.user.socketId = '';
    socket.broadcast.emit('user_online', {
      userId: socket.userId, isOnline: false, lastSeen: socket.user.lastSeen,
    });
  });
});

// ========== START ==========
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT} (in-memory mode)`);

  // Create demo users
  (async () => {
    const hash = await bcrypt.hash('password123', 12);
    const demoUsers = [
      { name: 'Alice Johnson', email: 'alice@test.com' },
      { name: 'Bob Smith', email: 'bob@test.com' },
      { name: 'Charlie Brown', email: 'charlie@test.com' },
      { name: 'Diana Prince', email: 'diana@test.com' },
      { name: 'Eve Williams', email: 'eve@test.com' },
    ];
    for (const du of demoUsers) {
      users.push({
        _id: String(nextUserId++),
        name: du.name,
        email: du.email,
        password: hash,
        avatar: '',
        about: 'Hey there! I am using ChatApp',
        isOnline: false,
        lastSeen: new Date().toISOString(),
        socketId: '',
        createdAt: new Date().toISOString(),
      });
    }
    console.log(`👥 Created ${demoUsers.length} demo users (password: password123)`);
  })();
});
