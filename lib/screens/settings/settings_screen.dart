import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true);
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkHeader : AppTheme.lightHeader,
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.darkTextPrimary : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(children: [
        const SizedBox(height: 8),
        // Profile tile
        _buildTile(
          isDark, Icons.person, 'Profile',
          subtitle: 'View and edit your profile',
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<AuthBloc>()),
                RepositoryProvider.value(value: context.read<ApiService>()),
              ],
              child: const ProfileScreen(),
            ))),
        ),
        _divider(isDark),
        // Theme
        BlocBuilder<ThemeCubit, bool>(
          builder: (context, isDarkMode) {
            return _buildTile(
              isDark, isDarkMode ? Icons.dark_mode : Icons.light_mode,
              'Theme',
              subtitle: isDarkMode ? 'Dark mode' : 'Light mode',
              trailing: Switch(
                value: isDarkMode,
                activeThumbColor: AppTheme.whatsappGreen,
                onChanged: (_) => context.read<ThemeCubit>().toggleTheme(),
              ),
            );
          },
        ),
        _divider(isDark),
        // Notifications
        _buildTile(isDark, Icons.notifications_outlined, 'Notifications',
          subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
          trailing: Switch(
            value: _notificationsEnabled,
            activeThumbColor: AppTheme.whatsappGreen,
            onChanged: _toggleNotifications,
          ),
        ),
        _divider(isDark),
        // Chat wallpaper
        _buildTile(isDark, Icons.wallpaper, 'Chat Wallpaper',
          subtitle: 'Customize chat background'),
        _divider(isDark),
        // Privacy
        _buildTile(isDark, Icons.lock_outline, 'Privacy',
          subtitle: 'Last seen, profile photo, about'),
        _divider(isDark),
        // Storage
        _buildTile(isDark, Icons.storage_outlined, 'Storage and Data',
          subtitle: 'Network usage, auto-download'),
        _divider(isDark),
        // Help
        _buildTile(isDark, Icons.help_outline, 'Help',
          subtitle: 'Help center, contact us, privacy policy'),
        _divider(isDark),
        // Logout
        _buildTile(isDark, Icons.logout, 'Logout',
          subtitle: 'Sign out of the app',
          iconColor: Colors.red,
          onTap: () {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
              title: Text('Logout', style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
              content: Text('Are you sure you want to logout?', style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  },
                  child: const Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ],
            ));
          },
        ),
        const SizedBox(height: 32),
        Center(child: Column(children: [
          Text('ChatApp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          const SizedBox(height: 4),
          Text('v1.0.0', style: TextStyle(fontSize: 12,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildTile(bool isDark, IconData icon, String title,
      {String? subtitle, Widget? trailing, VoidCallback? onTap, Color? iconColor}) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.whatsappGreen).withAlpha(20),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor ?? AppTheme.whatsappGreen, size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right,
        color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      tileColor: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      hoverColor: isDark ? AppTheme.darkInput.withAlpha(80) : const Color(0xFFF5F6F6),
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
      child: Divider(height: 1, indent: 76,
        color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
    );
  }
}
