import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _nameController = TextEditingController(text: authState.user.name);
      _aboutController = TextEditingController(text: authState.user.about);
    } else {
      _nameController = TextEditingController();
      _aboutController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      try {
        final api = context.read<ApiService>();
        final response = await api.post('/upload', {'base64': base64, 'filename': image.name});
        final imageUrl = '${AppConstants.baseUrl}${response['url']}';
        await api.put('/users/profile', {'avatar': imageUrl});
        setState(() => _avatarBase64 = imageUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      await api.put('/users/profile', {
        'name': _nameController.text.trim(),
        'about': _aboutController.text.trim(),
      });
      setState(() { _isEditing = false; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!'),
            backgroundColor: AppTheme.whatsappGreen));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
        title: const Text('Profile'),
        leading: widget.isEmbedded ? null : IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.darkTextPrimary : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(icon: Icon(Icons.edit, color: isDark ? AppTheme.darkIcon : Colors.white70),
              onPressed: () => setState(() => _isEditing = true)),
          if (_isEditing)
            IconButton(icon: Icon(Icons.close, color: isDark ? AppTheme.darkIcon : Colors.white70),
              onPressed: () => setState(() => _isEditing = false)),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) return const SizedBox();
          final user = state.user;
          return SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 32),
              _buildAvatarSection(user, isDark),
              const SizedBox(height: 32),
              _buildInfoSection(user, isDark),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(UserModel user, bool isDark) {
    final avatarUrl = _avatarBase64 ?? user.avatar;
    return Center(child: Stack(children: [
      Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.whatsappGreen, width: 3),
          boxShadow: [BoxShadow(color: AppTheme.whatsappGreen.withAlpha(40),
            blurRadius: 20, spreadRadius: 2)],
        ),
        child: avatarUrl.isNotEmpty
            ? CircleAvatar(radius: 67, backgroundImage: NetworkImage(avatarUrl))
            : CircleAvatar(radius: 67,
                backgroundColor: _getColor(user.name),
                child: Text(user.initials, style: const TextStyle(
                  fontSize: 48, fontWeight: FontWeight.w600, color: Colors.white))),
      ),
      Positioned(right: 4, bottom: 4,
        child: GestureDetector(
          onTap: _pickImage,
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.whatsappGreen, shape: BoxShape.circle,
              border: Border.all(color: isDark ? AppTheme.darkBg : AppTheme.lightBg, width: 3)),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20)),
        ),
      ),
    ]));
  }

  Widget _buildInfoSection(UserModel user, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 10), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildInfoRow(Icons.person, 'Name',
          _isEditing ? null : user.name, isDark,
          controller: _isEditing ? _nameController : null),
        Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
        _buildInfoRow(Icons.info_outline, 'About',
          _isEditing ? null : user.about, isDark,
          controller: _isEditing ? _aboutController : null),
        Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
        _buildInfoRow(Icons.email, 'Email', user.email, isDark),
        if (_isEditing) ...[
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 44,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.whatsappGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _isSaving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, bool isDark,
      {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            const SizedBox(height: 4),
            controller != null
              ? TextField(controller: controller,
                  style: TextStyle(fontSize: 16,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  decoration: InputDecoration(
                    isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.whatsappGreen)),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.whatsappGreen, width: 2))))
              : Text(value ?? '', style: TextStyle(fontSize: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
          ],
        )),
      ]),
    );
  }

  Color _getColor(String name) {
    final colors = [const Color(0xFF00A884), const Color(0xFF53BDEB),
      const Color(0xFFFF6B6B), const Color(0xFFFFA26B), const Color(0xFF6C5CE7)];
    return colors[name.hashCode.abs() % colors.length];
  }
}
