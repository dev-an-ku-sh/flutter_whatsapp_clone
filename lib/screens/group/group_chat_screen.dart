import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../core/di.dart';
import '../chat/image_viewer_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _showEmojiPicker = false;
  bool _isUploadingImage = false;
  bool _showScrollFab = false;
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  String? _replyToId;
  String? _replyToContent;

  String get _currentUserId {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.id : '';
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200;
      if (atBottom != !_showScrollFab) setState(() => _showScrollFab = !atBottom);
    });
    // Listen for new messages from ChatBloc
    context.read<ChatBloc>().stream.listen((state) {
      if (state.messages.isNotEmpty) {
        final newMsg = state.messages.last;
        if (newMsg.conversationId == widget.group.id) {
          setState(() => _messages = [..._messages, newMsg]);
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.get('/groups/${widget.group.id}/messages');
      final msgs = (resp['messages'] as List).map((m) => MessageModel.fromJson(m)).toList();
      setState(() { _messages = msgs; _isLoading = false; });
      _scrollToBottom();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _sendMessage() {
    final content = _msgController.text.trim();
    if (content.isEmpty) return;
    sl<SocketService>().sendGroupMessage(
      groupId: widget.group.id, content: content);
    _msgController.clear();
    setState(() { _replyToId = null; _replyToContent = null; });
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 75);
    if (image == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final bytes = await image.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final api = context.read<ApiService>();
      final resp = await api.post('/upload', {'base64': b64, 'filename': image.name});
      final imageUrl = '${AppConstants.baseUrl}${resp['url']}';
      if (mounted) {
        sl<SocketService>().sendGroupMessage(
          groupId: widget.group.id, content: '📷 Photo',
          messageType: 'image', imageUrl: imageUrl);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkChatBg : AppTheme.lightChatBg,
      appBar: _buildAppBar(isDark),
      floatingActionButton: _showScrollFab
          ? FloatingActionButton.small(
              backgroundColor: AppTheme.whatsappGreen,
              onPressed: _scrollToBottom,
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white))
          : null,
      body: Column(children: [
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.whatsappGreen))
            : _buildMessageList(isDark)),
        if (_replyToContent != null) _buildReplyBar(isDark),
        _buildInputBar(isDark),
        if (_showEmojiPicker) _buildEmojiPicker(isDark),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.darkIcon : Colors.white),
        onPressed: () => Navigator.pop(context)),
      title: GestureDetector(
        onTap: () => _showGroupInfo(isDark),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: AppTheme.whatsappGreen,
            child: Text(widget.group.initials,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.group.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : Colors.white)),
            Text('${widget.group.memberIds.length} members', style: TextStyle(
              fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.white70)),
          ])),
        ]),
      ),
      actions: [
        IconButton(icon: Icon(Icons.more_vert, color: isDark ? AppTheme.darkIcon : Colors.white70),
          onPressed: () => _showGroupInfo(isDark)),
      ],
    );
  }

  void _showGroupInfo(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: isDark ? AppTheme.darkIcon : AppTheme.lightDivider,
              borderRadius: BorderRadius.circular(2)))),
          Center(child: CircleAvatar(radius: 48, backgroundColor: AppTheme.whatsappGreen,
            child: Text(widget.group.initials,
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          Center(child: Text(widget.group.name, style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
          if (widget.group.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(child: Text(widget.group.description, style: TextStyle(fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
          ],
          const SizedBox(height: 20),
          Text('${widget.group.members.length} members',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: AppTheme.whatsappGreen)),
          const SizedBox(height: 8),
          ...widget.group.members.map((m) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 18, backgroundColor: Colors.cyan,
              child: Text(m.initials, style: const TextStyle(color: Colors.white, fontSize: 13))),
            title: Text(m.name, style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            subtitle: Text(m.about, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            trailing: m.id == widget.group.createdBy
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.whatsappGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(4)),
                    child: const Text('Admin', style: TextStyle(fontSize: 12,
                      color: AppTheme.whatsappGreen)))
                : null,
          )),
        ]),
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    if (_messages.isEmpty) {
      return Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? AppTheme.darkPanel : Colors.white).withAlpha(200),
          borderRadius: BorderRadius.circular(8)),
        child: Text('No messages yet. Say hi! 👋', style: TextStyle(fontSize: 13,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
      ));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isMe = msg.senderId == _currentUserId;
        final showDate = i == 0 || !_isSameDay(_messages[i - 1].createdAt, msg.createdAt);
        final showName = !isMe && (i == 0 || _messages[i - 1].senderId != msg.senderId);
        return Column(children: [
          if (showDate) _buildDateChip(msg.createdAt, isDark),
          _buildBubble(msg, isMe, showName, isDark),
        ]);
      },
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMe, bool showName, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMsgOptions(msg, isMe, isDark),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          decoration: BoxDecoration(
            color: isMe
                ? (isDark ? AppTheme.darkBubbleOut : AppTheme.lightBubbleOut)
                : (isDark ? AppTheme.darkBubbleIn : AppTheme.lightBubbleIn),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(10), topRight: const Radius.circular(10),
              bottomLeft: Radius.circular(isMe ? 10 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 10)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 1)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showName && !isMe)
              Text(msg.senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: _nameColor(msg.senderName))),
            if (msg.messageType == 'image' && msg.imageUrl.isNotEmpty)
              _buildImageMsg(msg, isDark),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (msg.messageType != 'image' || msg.content != '📷 Photo')
                Flexible(child: Text(msg.content, style: TextStyle(fontSize: 14.5,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
              const SizedBox(width: 6),
              Text(DateFormat('HH:mm').format(msg.createdAt),
                style: TextStyle(fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              if (isMe) ...[
                const SizedBox(width: 2),
                Icon(Icons.done_all, size: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageMsg(MessageModel msg, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
        imageUrl: msg.imageUrl, heroTag: msg.id,
        senderName: msg.senderName, timestamp: msg.createdAt))),
      child: Hero(
        tag: msg.id,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: msg.imageUrl, fit: BoxFit.cover,
            width: 220, height: 180,
            placeholder: (_, __) => Container(width: 220, height: 180,
              color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              child: const Center(child: CircularProgressIndicator(
                color: AppTheme.whatsappGreen, strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(width: 220, height: 100,
              color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              child: Icon(Icons.broken_image, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon)),
          ),
        ),
      ),
    );
  }

  void _showMsgOptions(MessageModel msg, bool isMe, bool isDark) {
    showModalBottomSheet(context: context,
      backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isDark ? AppTheme.darkIcon : AppTheme.lightDivider,
            borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: const Icon(Icons.reply, color: AppTheme.whatsappGreen),
          title: Text('Reply', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
          onTap: () { Navigator.pop(bctx); setState(() { _replyToId = msg.id; _replyToContent = msg.content; }); _focusNode.requestFocus(); },
        ),
        ListTile(
          leading: Icon(Icons.copy, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
          title: Text('Copy', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
          onTap: () { Clipboard.setData(ClipboardData(text: msg.content)); Navigator.pop(bctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), backgroundColor: AppTheme.whatsappGreen, duration: Duration(seconds: 1))); },
        ),
      ])));
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.whatsappGreen)),
            const SizedBox(height: 2),
            Text(_replyToContent ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          ])),
          IconButton(icon: const Icon(Icons.close, size: 18), padding: EdgeInsets.zero,
            constraints: const BoxConstraints(), color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
            onPressed: () => setState(() { _replyToId = null; _replyToContent = null; })),
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
          onPressed: () { setState(() => _showEmojiPicker = !_showEmojiPicker); if (!_showEmojiPicker) _focusNode.requestFocus(); }),
        _isUploadingImage
            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.whatsappGreen)))
            : IconButton(
                icon: Icon(Icons.attach_file, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
                onPressed: _pickAndSendImage),
        Expanded(child: Container(
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
            borderRadius: BorderRadius.circular(24)),
          child: TextField(
            controller: _msgController, focusNode: _focusNode, maxLines: null,
            onSubmitted: (_) => _sendMessage(),
            onTap: () { if (_showEmojiPicker) setState(() => _showEmojiPicker = false); },
            style: TextStyle(fontSize: 15, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            decoration: InputDecoration(
              hintText: 'Message ${widget.group.name}',
              hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
        )),
        const SizedBox(width: 8),
        Container(width: 44, height: 44,
          decoration: const BoxDecoration(color: AppTheme.whatsappGreen, shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage)),
      ]),
    );
  }

  Widget _buildEmojiPicker(bool isDark) {
    return SizedBox(height: 250, child: EmojiPicker(
      onEmojiSelected: (_, emoji) {
        _msgController.text += emoji.emoji;
        _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
      },
      config: Config(height: 250,
        emojiViewConfig: EmojiViewConfig(backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel),
        categoryViewConfig: CategoryViewConfig(
          backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
          indicatorColor: AppTheme.whatsappGreen,
          iconColor: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
          iconColorSelected: AppTheme.whatsappGreen),
        bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
      ),
    ));
  }

  Widget _buildDateChip(DateTime date, bool isDark) {
    final now = DateTime.now();
    final text = _isSameDay(date, now) ? 'TODAY'
        : _isSameDay(date, now.subtract(const Duration(days: 1))) ? 'YESTERDAY'
        : DateFormat('MM/dd/yyyy').format(date);
    return Container(margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkPanel : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 2)]),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _nameColor(String name) {
    final colors = [Colors.teal, Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.green];
    return colors[name.hashCode.abs() % colors.length];
  }
}
