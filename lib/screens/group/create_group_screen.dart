import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  List<UserModel> _allUsers = [];
  final Set<String> _selectedIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.get('/users');
      final users = (resp['users'] as List).map((u) => UserModel.fromJson(u)).toList();
      setState(() => _allUsers = users);
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty || _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter group name and select members'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isCreating = true);
    try {
      final api = context.read<ApiService>();
      await api.post('/groups', {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'memberIds': _selectedIds.toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
        title: const Text('New Group'),
        actions: [
          _isCreating
              ? const Padding(padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : TextButton(
                  onPressed: _createGroup,
                  child: const Text('CREATE', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
      body: Column(children: [
        // Group info section
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
          child: Column(children: [
            Row(children: [
              CircleAvatar(radius: 28, backgroundColor: AppTheme.whatsappGreen.withAlpha(50),
                child: const Icon(Icons.group, color: AppTheme.whatsappGreen, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  border: InputBorder.none),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              style: TextStyle(fontSize: 14,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                border: InputBorder.none),
            ),
          ]),
        ),
        // Selected chips
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
            child: Wrap(spacing: 8, runSpacing: 4, children: _selectedIds.map((id) {
              final user = _allUsers.firstWhere((u) => u.id == id, orElse: () => const UserModel(id: '', name: '?', email: ''));
              return Chip(
                label: Text(user.name, style: const TextStyle(fontSize: 13)),
                avatar: CircleAvatar(radius: 12, backgroundColor: AppTheme.whatsappGreen,
                  child: Text(user.initials, style: const TextStyle(fontSize: 10, color: Colors.white))),
                onDeleted: () => setState(() => _selectedIds.remove(id)),
                backgroundColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
                deleteIconColor: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
              );
            }).toList()),
          ),
        const SizedBox(height: 8),
        // Members header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('Select members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            const Spacer(),
            Text('${_selectedIds.length} selected', style: TextStyle(fontSize: 13,
              color: AppTheme.whatsappGreen)),
          ]),
        ),
        // Users list
        Expanded(
          child: _allUsers.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppTheme.whatsappGreen))
              : ListView.builder(
                  itemCount: _allUsers.length,
                  itemBuilder: (context, i) {
                    final user = _allUsers[i];
                    final selected = _selectedIds.contains(user.id);
                    return ListTile(
                      leading: Stack(children: [
                        CircleAvatar(radius: 20,
                          backgroundColor: _getColor(user.name),
                          child: Text(user.initials, style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                        if (selected)
                          Positioned(right: 0, bottom: 0,
                            child: Container(width: 18, height: 18,
                              decoration: const BoxDecoration(
                                color: AppTheme.whatsappGreen, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Colors.white))),
                      ]),
                      title: Text(user.name, style: TextStyle(fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                      subtitle: Text(user.about, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                      tileColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
                      onTap: () => setState(() {
                        if (selected) _selectedIds.remove(user.id);
                        else _selectedIds.add(user.id);
                      }),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Color _getColor(String name) {
    final colors = [const Color(0xFF00A884), const Color(0xFF53BDEB),
      const Color(0xFFFF6B6B), const Color(0xFFFFA26B), const Color(0xFF6C5CE7)];
    return colors[name.hashCode.abs() % colors.length];
  }
}
