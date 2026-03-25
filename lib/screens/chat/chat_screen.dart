import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'image_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final UserModel user;
  final bool isEmbedded;

  const ChatScreen({super.key, required this.user, this.isEmbedded = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  String? _replyToId;
  String? _replyToContent;
  bool _showEmojiPicker = false;
  bool _isUploadingImage = false;
  bool _showSearchBar = false;
  bool _showScrollFab = false;
  final FocusNode _focusNode = FocusNode();
  final _searchController = TextEditingController();
  List<MessageModel> _searchResults = [];

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200;
      if (atBottom != !_showScrollFab) setState(() => _showScrollFab = !atBottom);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    context.read<ChatBloc>().add(ChatSendMessage(
      receiverId: widget.user.id,
      content: content,
      replyToId: _replyToId,
    ));
    _messageController.clear();
    setState(() { _replyToId = null; _replyToContent = null; });
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 75);
    if (image == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await image.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final api = context.read<ApiService>();
      final resp = await api.post('/upload', {'base64': base64Str, 'filename': image.name});
      final imageUrl = '${AppConstants.baseUrl}${resp['url']}';

      if (mounted) {
        context.read<ChatBloc>().add(ChatSendMessage(
          receiverId: widget.user.id,
          content: '📷 Photo',
          messageType: 'image',
          imageUrl: imageUrl,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _onTypingChanged(String text) {
    final chatBloc = context.read<ChatBloc>();
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      chatBloc.socketService.sendTypingStart(widget.user.id);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      chatBloc.socketService.sendTypingStop(widget.user.id);
    });
  }

  void _setReply(MessageModel msg) {
    setState(() { _replyToId = msg.id; _replyToContent = msg.content; });
    _focusNode.requestFocus();
  }

  Future<void> _searchMessages(String query) async {
    if (query.length < 2) { setState(() => _searchResults = []); return; }
    try {
      final api = context.read<ApiService>();
      final resp = await api.get('/messages/search/${widget.user.id}?q=$query');
      final results = (resp['messages'] as List).map((m) => MessageModel.fromJson(m)).toList();
      setState(() => _searchResults = results);
    } catch (_) {}
  }

  void _showContactInfo(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final user = widget.user;
        final chatState = context.read<ChatBloc>().state;
        final isOnline = chatState.onlineUsers[user.id] ?? user.isOnline;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkIcon : AppTheme.lightDivider,
                    borderRadius: BorderRadius.circular(2)))),
                Center(child: _buildUserAvatar(user, 100)),
                const SizedBox(height: 16),
                Center(child: Text(user.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
                const SizedBox(height: 4),
                Center(child: Text(
                  isOnline ? '🟢 Online' : 'Last seen ${_formatLastSeen(user.lastSeen)}',
                  style: TextStyle(fontSize: 14,
                    color: isOnline ? AppTheme.whatsappGreen
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)))),
                const SizedBox(height: 24),
                _infoTile(Icons.email_outlined, 'Email', user.email, isDark),
                _infoTile(Icons.info_outline, 'About', user.about, isDark),
                const SizedBox(height: 16),
                Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _actionButton(Icons.message, 'Message', AppTheme.whatsappGreen, () => Navigator.pop(ctx)),
                  _actionButton(Icons.call, 'Audio', Colors.blue, () {}),
                  _actionButton(Icons.videocam, 'Video', Colors.purple, () {}),
                  _actionButton(Icons.search, 'Search', Colors.orange, () {
                    Navigator.pop(ctx);
                    setState(() => _showSearchBar = true);
                  }),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.lock, size: 18, color: AppTheme.whatsappGreen),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'Messages are end-to-end encrypted. No one outside of this chat can read them.',
                      style: TextStyle(fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
                  ]),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          Text(value, style: TextStyle(fontSize: 15,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
        ]),
      ]),
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'recently';
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'today at ${DateFormat('HH:mm').format(lastSeen)}';
    if (diff.inDays == 1) return 'yesterday at ${DateFormat('HH:mm').format(lastSeen)}';
    return DateFormat('MMM d').format(lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.darkChatBg : AppTheme.lightChatBg,
      child: Stack(
        children: [
          Column(
            children: [
              _buildChatHeader(isDark),
              if (_showSearchBar) _buildSearchBar(isDark),
              Expanded(child: _showSearchBar && _searchResults.isNotEmpty
                  ? _buildSearchResults(isDark)
                  : _buildMessageList(isDark)),
              if (_replyToContent != null) _buildReplyBar(isDark),
              _buildInputBar(isDark),
              if (_showEmojiPicker) _buildEmojiPicker(isDark),
            ],
          ),
          // Scroll-to-bottom FAB
          if (_showScrollFab)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'scroll_fab_1on1',
                backgroundColor: AppTheme.whatsappGreen,
                onPressed: _scrollToBottom,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      child: Row(children: [
        Expanded(child: Container(height: 36,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSearchBg : AppTheme.lightSearchBg,
            borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(fontSize: 14,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            onChanged: _searchMessages,
            decoration: InputDecoration(
              hintText: 'Search in chat...',
              hintStyle: TextStyle(fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              prefixIcon: Icon(Icons.search, size: 20,
                color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        )),
        IconButton(
          icon: Icon(Icons.close, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
          onPressed: () => setState(() {
            _showSearchBar = false;
            _searchController.clear();
            _searchResults = [];
          }),
        ),
      ]),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, i) {
        final msg = _searchResults[i];
        final isMe = msg.senderId == _currentUserId;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkPanel : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider)),
          child: Row(children: [
            Icon(isMe ? Icons.arrow_forward : Icons.arrow_back, size: 16,
              color: AppTheme.whatsappGreen),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isMe ? 'You' : widget.user.name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.whatsappGreen)),
              const SizedBox(height: 2),
              Text(msg.content, style: TextStyle(fontSize: 14,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ])),
            Text(DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(fontSize: 11,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          ]),
        );
      },
    );
  }

  Widget _buildChatHeader(bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
        border: Border(bottom: BorderSide(
          color: isDark ? AppTheme.darkDivider : Colors.transparent)),
      ),
      child: Row(children: [
        if (!widget.isEmbedded)
          IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.darkIcon : Colors.white),
            onPressed: () {
              context.read<ChatBloc>().add(ChatClearSelection());
              Navigator.pop(context);
            },
          ),
        GestureDetector(
          onTap: () => _showContactInfo(isDark),
          child: Row(children: [
            _buildUserAvatar(widget.user, 40),
            const SizedBox(width: 12),
          ]),
        ),
        Expanded(child: GestureDetector(
          onTap: () => _showContactInfo(isDark),
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final isOnline = state.onlineUsers[widget.user.id] ?? widget.user.isOnline;
              final isTyping = state.typingUsers[widget.user.id] ?? false;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : Colors.white)),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      isTyping ? 'typing...'
                        : (isOnline ? 'online'
                          : 'last seen ${_formatLastSeen(widget.user.lastSeen)}'),
                      key: ValueKey(isTyping ? 'typing' : (isOnline ? 'online' : 'lastseen')),
                      style: TextStyle(fontSize: 13,
                        color: isTyping ? AppTheme.whatsappGreen
                            : (isDark ? AppTheme.darkTextSecondary : Colors.white70)),
                    ),
                  ),
                ],
              );
            },
          ),
        )),
        IconButton(
          icon: Icon(Icons.search, color: isDark ? AppTheme.darkIcon : Colors.white70),
          onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? AppTheme.darkIcon : Colors.white70),
          color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
          onSelected: (v) {
            if (v == 'contact') _showContactInfo(isDark);
            if (v == 'search') setState(() => _showSearchBar = !_showSearchBar);
            if (v == 'clear') _showClearChatDialog(isDark);
          },
          itemBuilder: (_) => [
            _popupItem('contact', Icons.person_outline, 'Contact info', isDark),
            _popupItem('search', Icons.search, 'Search', isDark),
            _popupItem('clear', Icons.cleaning_services_outlined, 'Clear chat', isDark),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String title, bool isDark) {
    return PopupMenuItem(value: value, child: Row(children: [
      Icon(icon, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
      const SizedBox(width: 12),
      Text(title, style: TextStyle(
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
    ]));
  }

  void _showClearChatDialog(bool isDark) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      title: Text('Clear chat', style: TextStyle(
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
      content: Text('Delete all messages in this chat?', style: TextStyle(
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
        TextButton(onPressed: () { Navigator.pop(ctx); },
          child: const Text('Clear', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _buildMessageList(bool isDark) {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        if (state.isLoadingMessages) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.whatsappGreen));
        }
        if (state.messages.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 20,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkPanel : Colors.white).withAlpha(200),
                borderRadius: BorderRadius.circular(8)),
              child: Text('Messages are end-to-end encrypted. Start chatting!',
                style: TextStyle(fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ),
          ]));
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.messages.length,
          itemBuilder: (context, index) {
            final msg = state.messages[index];
            final isMe = msg.senderId == _currentUserId;
            final showDate = index == 0 || !_isSameDay(
              state.messages[index - 1].createdAt, msg.createdAt);
            return AnimatedSlide(
              offset: Offset.zero,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Column(children: [
                  if (showDate) _buildDateChip(msg.createdAt, isDark),
                  _buildSwipeableMessage(msg, isMe, isDark),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSwipeableMessage(MessageModel msg, bool isMe, bool isDark) {
    return Dismissible(
      key: Key('swipe_${msg.id}'),
      direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        _setReply(msg);
        return false;
      },
      background: Container(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.only(left: isMe ? 0 : 24, right: isMe ? 24 : 0),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkInput : const Color(0xFFE0E0E0),
            shape: BoxShape.circle),
          child: Icon(Icons.reply, size: 18,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
        ),
      ),
      child: _buildMessageBubble(msg, isMe, isDark),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateChip(DateTime date, bool isDark) {
    final now = DateTime.now();
    String text;
    if (_isSameDay(date, now)) {
      text = 'TODAY';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = 'YESTERDAY';
    } else {
      text = DateFormat('MM/dd/yyyy').format(date);
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkPanel : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 2)]),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe, isDark),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          decoration: BoxDecoration(
            color: isMe
                ? (isDark ? AppTheme.darkBubbleOut : AppTheme.lightBubbleOut)
                : (isDark ? AppTheme.darkBubbleIn : AppTheme.lightBubbleIn),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(10),
              topRight: const Radius.circular(10),
              bottomLeft: Radius.circular(isMe ? 10 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 10)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
              blurRadius: 1, offset: const Offset(0, 1))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (msg.replyToContent != null) _buildReplyPreview(msg.replyToContent!, isDark, isMe),
            if (msg.messageType == 'image' && msg.imageUrl.isNotEmpty)
              _buildImageMessage(msg, isDark),
            if (msg.messageType != 'image' || msg.content != '📷 Photo')
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Flexible(child: Text(msg.content, style: TextStyle(fontSize: 14.5,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
                const SizedBox(width: 6),
                _buildTimestamp(msg, isMe, isDark),
              ])
            else
              _buildTimestamp(msg, isMe, isDark),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimestamp(MessageModel msg, bool isMe, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(DateFormat('HH:mm').format(msg.createdAt),
        style: TextStyle(fontSize: 11,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
      if (isMe) ...[
        const SizedBox(width: 3),
        _buildStatusIcon(msg.status, isDark),
      ],
    ]);
  }

  Widget _buildImageMessage(MessageModel msg, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imageUrl: msg.imageUrl, heroTag: msg.id,
          senderName: msg.senderName.isEmpty ? 'You' : msg.senderName,
          timestamp: msg.createdAt))),
      child: Hero(
        tag: msg.id,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 300),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: msg.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200, height: 150,
                color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                child: const Center(child: CircularProgressIndicator(
                  color: AppTheme.whatsappGreen, strokeWidth: 2))),
              errorWidget: (context, url, error) => Container(
                width: 200, height: 100,
                color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                child: Icon(Icons.broken_image, size: 40,
                  color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon)),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel msg, bool isMe, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bCtx) {
        return SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
                borderRadius: BorderRadius.circular(2))),
            // Message preview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                borderRadius: BorderRadius.circular(8)),
              child: Text(msg.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: AppTheme.whatsappGreen),
              title: Text('Reply', style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              onTap: () { Navigator.pop(bCtx); _setReply(msg); },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              title: Text('Copy', style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Navigator.pop(bCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied'), duration: Duration(seconds: 1),
                    backgroundColor: AppTheme.whatsappGreen));
              },
            ),
            ListTile(
              leading: Icon(Icons.forward, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              title: Text('Forward', style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              onTap: () { Navigator.pop(bCtx); },
            ),
            if (isMe) ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(bCtx);
                _confirmDelete(msg, isDark);
              },
            ),
          ]),
        ));
      },
    );
  }

  void _confirmDelete(MessageModel msg, bool isDark) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      title: Text('Delete message?', style: TextStyle(
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
      content: Text('This message will be deleted for you.', style: TextStyle(
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<ChatBloc>().add(ChatDeleteMessage(msg.id));
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _buildReplyPreview(String content, bool isDark, bool isMe) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: AppTheme.whatsappGreen, width: 3))),
      child: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
    );
  }

  Widget _buildStatusIcon(String status, bool isDark) {
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: AppTheme.whatsappBlue);
      case 'delivered':
        return Icon(Icons.done_all, size: 16,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);
      default:
        return Icon(Icons.done, size: 16,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);
    }
  }

  Widget _buildReplyBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      color: isDark ? AppTheme.darkPanel : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppTheme.whatsappGreen, width: 4))),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppTheme.whatsappGreen)),
              const SizedBox(height: 2),
              Text(_replyToContent ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ],
          )),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
            onPressed: () => setState(() { _replyToId = null; _replyToContent = null; }),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      child: Row(children: [
        IconButton(
          icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
            color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
          onPressed: () {
            setState(() => _showEmojiPicker = !_showEmojiPicker);
            if (!_showEmojiPicker) _focusNode.requestFocus();
          },
        ),
        _isUploadingImage
            ? const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.whatsappGreen)))
            : IconButton(
                icon: Icon(Icons.attach_file,
                  color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
                onPressed: _pickAndSendImage,
              ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: null,
              onChanged: _onTypingChanged,
              onSubmitted: (_) => _sendMessage(),
              onTap: () {
                if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
              },
              style: TextStyle(fontSize: 15,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 44, height: 44,
          decoration: const BoxDecoration(
            color: AppTheme.whatsappGreen, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 20),
            onPressed: _sendMessage,
          ),
        ),
      ]),
    );
  }

  Widget _buildEmojiPicker(bool isDark) {
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          _messageController.text += emoji.emoji;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length));
        },
        config: Config(
          height: 280,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
            columns: 8, emojiSizeMax: 28,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
            indicatorColor: AppTheme.whatsappGreen,
            iconColor: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
            iconColorSelected: AppTheme.whatsappGreen,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
            buttonIconColor: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user, double size) {
    if (user.avatar.isNotEmpty) {
      return CircleAvatar(radius: size / 2,
        child: ClipOval(child: CachedNetworkImage(
          imageUrl: user.avatar, width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, __) => CircleAvatar(radius: size / 2,
            backgroundColor: AppTheme.whatsappGreen,
            child: Text(user.initials, style: TextStyle(
              color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w600))),
          errorWidget: (_, __, ___) => CircleAvatar(radius: size / 2,
            backgroundColor: AppTheme.whatsappGreen,
            child: Text(user.initials, style: TextStyle(
              color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w600))),
        )));
    }
    final colors = [
      const Color(0xFF00A884), const Color(0xFF53BDEB), const Color(0xFFFF6B6B),
      const Color(0xFFFFA26B), const Color(0xFF6C5CE7), const Color(0xFFFF85A2),
    ];
    return CircleAvatar(radius: size / 2,
      backgroundColor: colors[user.name.hashCode.abs() % colors.length],
      child: Text(user.initials, style: TextStyle(
        color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w600)));
  }
}
