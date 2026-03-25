import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../core/theme.dart';
import '../../models/conversation_model.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../group/create_group_screen.dart';
import '../group/group_chat_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<GroupModel> _groups = [];
  GroupModel? _selectedGroup;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatBloc>().add(ChatLoadConversations());
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.get('/groups');
      final groups = (resp['groups'] as List).map((g) => GroupModel.fromJson(g)).toList();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final chatBloc = context.read<ChatBloc>();
    switch (state) {
      case AppLifecycleState.resumed:
        chatBloc.add(ChatAppFocusChanged(true));
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        chatBloc.add(ChatAppFocusChanged(false));
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 768;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: isWide ? _wideLayout(isDark) : _narrowLayout(isDark),
    );
  }

  Widget _wideLayout(bool isDark) {
    return Row(children: [
      SizedBox(width: 380, child: _conversationsPanel(isDark)),
      Container(width: 1, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
      Expanded(
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (_selectedGroup != null) {
              return BlocProvider.value(
                value: context.read<ChatBloc>(),
                child: GroupChatScreen(group: _selectedGroup!),
              );
            }
            if (state.selectedUser != null) {
              return ChatScreen(user: state.selectedUser!, isEmbedded: true);
            }
            return _emptyChat(isDark);
          },
        ),
      ),
    ]);
  }

  Widget _narrowLayout(bool isDark) => _conversationsPanel(isDark);

  Widget _conversationsPanel(bool isDark) {
    return Column(children: [
      _header(isDark),
      _tabBar(isDark),
      Expanded(child: TabBarView(
        controller: _tabController,
        children: [
          _chatsTab(isDark),
          _groupsTab(isDark),
        ],
      )),
    ]);
  }

  Widget _tabBar(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.whatsappGreen,
        indicatorWeight: 3,
        labelColor: AppTheme.whatsappGreen,
        unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'CHATS'),
          Tab(text: 'GROUPS'),
        ],
      ),
    );
  }

  Widget _chatsTab(bool isDark) {
    return Column(children: [
      _searchBar(isDark),
      Expanded(
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state.isLoadingConversations && state.conversations.isEmpty) {
              return _shimmer(isDark);
            }
            if (state.conversations.isEmpty) return _noChats(isDark);
            // Apply search filter
            final filtered = _searchQuery.isEmpty
                ? state.conversations
                : state.conversations.where((c) =>
                    c.otherUser.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();
            if (filtered.isEmpty && _searchQuery.isNotEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, size: 48,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                const SizedBox(height: 12),
                Text('No results for "$_searchQuery"', style: TextStyle(fontSize: 16,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              ]));
            }
            return RefreshIndicator(
              color: AppTheme.whatsappGreen,
              onRefresh: () async {
                context.read<ChatBloc>().add(ChatLoadConversations());
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _conversationTile(
                  filtered[i], isDark,
                  selected: state.selectedUser?.id == filtered[i].otherUser.id,
                  online: state.onlineUsers, typing: state.typingUsers),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _groupsTab(bool isDark) {
    return Column(children: [
      // Create group button
      Material(
        color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
        child: InkWell(
          onTap: () => _openCreateGroup(isDark),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.whatsappGreen, shape: BoxShape.circle),
                child: const Icon(Icons.group_add, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Text('New Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ]),
          ),
        ),
      ),
      Divider(height: 1, thickness: 1,
        color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
      Expanded(
        child: RefreshIndicator(
          color: AppTheme.whatsappGreen,
          onRefresh: () async { await _loadGroups(); },
          child: _groups.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                  SizedBox(height: 120,
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.group_outlined, size: 48,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      const SizedBox(height: 12),
                      Text('No groups yet', style: TextStyle(fontSize: 16,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                    ]))),
                ])
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) => _groupTile(_groups[i], isDark),
                ),
        ),
      ),
    ]);
  }

  Widget _groupTile(GroupModel group, bool isDark) {
    final selected = _selectedGroup?.id == group.id;
    return Material(
      color: selected
          ? (isDark ? AppTheme.darkInput : const Color(0xFFF0F2F5))
          : (isDark ? AppTheme.darkPanel : AppTheme.lightPanel),
      child: InkWell(
        onTap: () {
          setState(() => _selectedGroup = group);
          context.read<ChatBloc>().add(ChatClearSelection());
          if (MediaQuery.of(context).size.width <= 768) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<ChatBloc>()),
                  RepositoryProvider.value(value: context.read<ApiService>()),
                ],
                child: GroupChatScreen(group: group))));
          }
        },
        hoverColor: isDark ? AppTheme.darkInput.withAlpha(100) : const Color(0xFFF5F6F6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: AppTheme.whatsappGreen,
              child: Text(group.initials,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              const SizedBox(height: 4),
              Text('${group.memberIds.length} members',
                style: TextStyle(fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ])),
            Icon(Icons.chevron_right_rounded, size: 20,
              color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
          ]),
        ),
      ),
    );
  }

  Future<void> _openCreateGroup(bool isDark) async {
    final result = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<AuthBloc>()),
          RepositoryProvider.value(value: context.read<ApiService>()),
        ],
        child: const CreateGroupScreen())));
    if (result == true) {
      await _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created!'),
            backgroundColor: AppTheme.whatsappGreen, duration: Duration(seconds: 2)));
        _tabController.animateTo(1);
      }
    }
  }

  Widget _header(bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
      child: Row(children: [
        BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
          if (state is AuthAuthenticated) return _avatar(state.user, 36);
          return const SizedBox(width: 36, height: 36);
        }),
        const SizedBox(width: 12),
        Text('ChatApp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
          color: isDark ? AppTheme.darkTextPrimary : Colors.white)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.chat_outlined, size: 22,
            color: isDark ? AppTheme.darkIcon : Colors.white70),
          onPressed: () => _newChatDialog(isDark),
        ),
        BlocBuilder<ThemeCubit, bool>(builder: (context, dark) {
          return IconButton(
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22, color: isDark ? AppTheme.darkIcon : Colors.white70),
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          );
        }),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: isDark ? AppTheme.darkIcon : Colors.white70),
          color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
          onSelected: (v) {
            if (v == 'logout') context.read<AuthBloc>().add(AuthLogoutRequested());
            if (v == 'profile') {
              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                MultiBlocProvider(providers: [
                  BlocProvider.value(value: context.read<AuthBloc>()),
                  RepositoryProvider.value(value: context.read<ApiService>()),
                ], child: const ProfileScreen())));
            }
            if (v == 'settings') {
              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                MultiBlocProvider(providers: [
                  BlocProvider.value(value: context.read<AuthBloc>()),
                  BlocProvider.value(value: context.read<ThemeCubit>()),
                  RepositoryProvider.value(value: context.read<ApiService>()),
                ], child: const SettingsScreen())));
            }
            if (v == 'newgroup') _openCreateGroup(isDark);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'profile', child: Row(children: [
              Icon(Icons.person_outline, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              const SizedBox(width: 12),
              Text('Profile', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ])),
            PopupMenuItem(value: 'newgroup', child: Row(children: [
              Icon(Icons.group_add_outlined, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              const SizedBox(width: 12),
              Text('New Group', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ])),
            PopupMenuItem(value: 'settings', child: Row(children: [
              Icon(Icons.settings_outlined, size: 20, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
              const SizedBox(width: 12),
              Text('Settings', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'logout', child: Row(children: [
              const Icon(Icons.logout, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ])),
          ],
        ),
      ]),
    );
  }

  Widget _searchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      child: Container(height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSearchBg : AppTheme.lightSearchBg,
          borderRadius: BorderRadius.circular(8)),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(fontSize: 14,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'Search or start new chat',
            hintStyle: TextStyle(fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            prefixIcon: Icon(Icons.search, size: 20,
              color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 18,
                      color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        ),
      ),
    );
  }

  Widget _conversationTile(ConversationModel c, bool isDark,
      {bool selected = false, Map<String, bool> online = const {},
       Map<String, bool> typing = const {}}) {
    final user = c.otherUser;
    final isOn = online[user.id] ?? user.isOnline;
    final isTyp = typing[user.id] ?? false;
    return Material(
      color: selected
          ? (isDark ? AppTheme.darkInput : const Color(0xFFF0F2F5))
          : (isDark ? AppTheme.darkPanel : AppTheme.lightPanel),
      child: InkWell(
        onTap: () {
          setState(() => _selectedGroup = null);
          context.read<ChatBloc>().add(ChatSelectConversation(user));
          if (MediaQuery.of(context).size.width <= 768) {
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              BlocProvider.value(value: context.read<ChatBloc>(),
                child: ChatScreen(user: user, isEmbedded: false))));
          }
        },
        hoverColor: isDark ? AppTheme.darkInput.withAlpha(100) : const Color(0xFFF5F6F6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Stack(children: [
              _avatar(user, 48),
              if (isOn) Positioned(right: 0, bottom: 0, child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(color: AppTheme.whatsappGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel, width: 2)),
              )),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16,
                    fontWeight: c.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
                Text(_fmtTime(c.lastMessageTime), style: TextStyle(fontSize: 12,
                  color: c.unreadCount > 0 ? AppTheme.whatsappGreen
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: isTyp
                  ? const Text('typing...', style: TextStyle(fontSize: 14,
                      color: AppTheme.whatsappGreen, fontStyle: FontStyle.italic))
                  : Text(c.lastMessageType == 'image' ? '📷 Photo' : c.lastMessage,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary))),
                if (c.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.whatsappGreen,
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('${c.unreadCount}', style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _avatar(UserModel u, double s) {
    if (u.avatar.isNotEmpty) {
      return CircleAvatar(radius: s / 2,
        child: ClipOval(child: CachedNetworkImage(
          imageUrl: u.avatar, width: s, height: s, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initialsAvatar(u, s))));
    }
    return _initialsAvatar(u, s);
  }

  Widget _initialsAvatar(UserModel u, double s) {
    final colors = [const Color(0xFF00A884), const Color(0xFF53BDEB), const Color(0xFFFF6B6B),
      const Color(0xFFFFA26B), const Color(0xFF6C5CE7), const Color(0xFFFF85A2),
      const Color(0xFF00BCD4), const Color(0xFF8BC34A)];
    return CircleAvatar(radius: s / 2,
      backgroundColor: colors[u.name.hashCode.abs() % colors.length],
      child: Text(u.initials, style: TextStyle(
        color: Colors.white, fontSize: s * 0.35, fontWeight: FontWeight.w600)));
  }

  Widget _emptyChat(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkChatBg : const Color(0xFFF0F2F5),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 200, height: 200,
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkPanel : AppTheme.lightPanel).withAlpha(180),
            shape: BoxShape.circle),
          child: Icon(Icons.chat_bubble_outline_rounded, size: 80,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 28),
        Text('ChatApp Web', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
        const SizedBox(height: 16),
        Text('Send and receive messages.\nNow with groups & real-time features.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.whatsappGreen.withAlpha(20),
            borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 14, color: AppTheme.darkTextSecondary),
            const SizedBox(width: 8),
            Text('End-to-end encrypted', style: TextStyle(fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          ]),
        ),
      ])),
    );
  }

  Widget _noChats(bool isDark) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.forum_outlined, size: 64,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
      const SizedBox(height: 16),
      Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
      const SizedBox(height: 8),
      Text('Start a new chat to begin messaging', style: TextStyle(fontSize: 14,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => _newChatDialog(isDark),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Chat'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.whatsappGreen, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      ),
    ]));
  }

  Widget _shimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkInput : const Color(0xFFE9EDEF),
      highlightColor: isDark ? AppTheme.darkPanel : const Color(0xFFF5F5F5),
      child: ListView.builder(itemCount: 8, physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkInput : Colors.white,
                shape: BoxShape.circle)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 120, height: 14,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkInput : Colors.white,
                  borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(width: 200, height: 12,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkInput : Colors.white,
                  borderRadius: BorderRadius.circular(4))),
            ])),
          ]),
        ),
      ),
    );
  }

  void _newChatDialog(bool isDark) {
    final sc = TextEditingController();
    List<UserModel> results = [];
    bool loading = false;
    Timer? debounce;
    showDialog(context: context, builder: (dc) {
      return StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
          title: Text('New Chat', style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
          content: SizedBox(width: 360, height: 400, child: Column(children: [
            TextField(
              controller: sc, autofocus: true,
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
                filled: true, fillColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 300), () async {
                  if (v.length < 2) { setSt(() => results = []); return; }
                  setSt(() => loading = true);
                  try {
                    final api = this.context.read<ApiService>();
                    final resp = await api.get('/users/search?q=$v');
                    final users = (resp['users'] as List).map((u) => UserModel.fromJson(u)).toList();
                    setSt(() { results = users; loading = false; });
                  } catch (_) { setSt(() => loading = false); }
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.whatsappGreen))
              : results.isEmpty
                ? Center(child: Text(sc.text.length < 2 ? 'Type to search' : 'No users found',
                    style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)))
                : ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
                    final u = results[i];
                    return ListTile(
                      leading: _avatar(u, 40),
                      title: Text(u.name, style: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                      subtitle: Text(u.email, style: TextStyle(fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        Navigator.pop(dc);
                        setState(() => _selectedGroup = null);
                        this.context.read<ChatBloc>().add(ChatSelectConversation(u));
                        if (MediaQuery.of(this.context).size.width <= 768) {
                          Navigator.push(this.context, MaterialPageRoute(builder: (_) =>
                            BlocProvider.value(value: this.context.read<ChatBloc>(),
                              child: ChatScreen(user: u, isEmbedded: false))));
                        }
                      },
                    );
                  }),
            ),
          ])),
        );
      });
    });
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
