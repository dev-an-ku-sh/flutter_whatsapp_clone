import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  
  late TabController _tabController;
  bool _obscureLogin = true;
  bool _obscureRegister = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo/header
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  // Card with login/register tabs
                  _buildAuthCard(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.whatsappGreen,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.whatsappGreen.withAlpha(80),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'ChatApp',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect with people around the world',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkPanel : AppTheme.lightPanel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 20),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.whatsappGreen,
              indicatorWeight: 3,
              labelColor: AppTheme.whatsappGreen,
              unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: const [
                Tab(text: 'Login'),
                Tab(text: 'Register'),
              ],
            ),
          ),
          // Tab views
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoginForm(isDark),
                _buildRegisterForm(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _loginEmailController,
              label: 'Email',
              icon: Icons.email_outlined,
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty ? 'Enter your email' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _loginPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isDark: isDark,
              obscure: _obscureLogin,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLogin ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
              ),
              validator: (v) => v!.isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 24),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: state is AuthLoading
                        ? null
                        : () {
                            if (_loginFormKey.currentState!.validate()) {
                              context.read<AuthBloc>().add(AuthLoginRequested(
                                email: _loginEmailController.text.trim(),
                                password: _loginPasswordController.text,
                              ));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.whatsappGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: state is AuthLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(
                controller: _registerNameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                isDark: isDark,
                validator: (v) => v!.length < 2 ? 'Name must be at least 2 characters' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _registerEmailController,
                label: 'Email',
                icon: Icons.email_outlined,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _registerPasswordController,
                label: 'Password',
                icon: Icons.lock_outline,
                isDark: isDark,
                obscure: _obscureRegister,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegister ? Icons.visibility_off : Icons.visibility,
                    color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureRegister = !_obscureRegister),
                ),
                validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
              ),
              const SizedBox(height: 24),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state is AuthLoading
                          ? null
                          : () {
                              if (_registerFormKey.currentState!.validate()) {
                                context.read<AuthBloc>().add(AuthRegisterRequested(
                                  name: _registerNameController.text.trim(),
                                  email: _registerEmailController.text.trim(),
                                  password: _registerPasswordController.text,
                                ));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.whatsappGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: state is AuthLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? AppTheme.darkIcon : AppTheme.lightIcon,
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.whatsappGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
