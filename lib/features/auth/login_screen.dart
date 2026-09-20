import 'package:flutter/material.dart';
import '../../core/app_design.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    String? errorMessage;

    if (_isLogin) {
      errorMessage = await _authService.signIn(email, password);
    } else {
      if (name.isEmpty) {
        errorMessage = "Please enter your name.";
      } else {
        errorMessage = await _authService.signUp(
          email,
          password,
          name,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFF8FAFC), Color(0xFFEFFAF7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 820;
                    final form = _LoginPanel(
                      isLogin: _isLogin,
                      isLoading: _isLoading,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      nameController: _nameController,
                      onSubmit: _submit,
                      onToggleMode: () {
                        _emailController.clear();
                        _passwordController.clear();
                        _nameController.clear();
                        setState(() => _isLogin = !_isLogin);
                      },
                    );

                    if (compact) {
                      return Column(
                        children: [
                          const _BrandPanel(compact: true),
                          const SizedBox(height: 18),
                          form,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(child: _BrandPanel()),
                        const SizedBox(width: 24),
                        SizedBox(width: 430, child: form),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'FlowSlot Campus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            compact
                ? 'Book, approve, and monitor campus services.'
                : 'A campus booking workspace for students, lecturers, and administrators.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 24 : 32,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Manage service requests, facility reservations, announcements, feedback, and operational insights in one system.',
            style: TextStyle(color: Color(0xFFCBD5E1), height: 1.45),
          ),
          if (!compact) ...[
            const SizedBox(height: 24),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                AppPill(label: 'Student booking', color: Color(0xFF38BDF8)),
                AppPill(label: 'Staff facilities', color: Color(0xFFA78BFA)),
                AppPill(label: 'Admin approval', color: Color(0xFF34D399)),
                AppPill(label: 'Reports', color: Color(0xFFFBBF24)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.isLogin,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final bool isLogin;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLogin ? 'Sign in' : 'Create account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isLogin
                  ? 'Continue to your campus booking dashboard.'
                  : 'New public accounts are created as Student accounts.',
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 22),
            if (!isLogin) ...[
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              onSubmitted: (_) => isLoading ? null : onSubmit(),
            ),
            if (!isLogin) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: AppColors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Staff and admin access is assigned by an existing administrator.',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onSubmit,
              icon: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(isLogin ? Icons.login_outlined : Icons.person_add_alt),
              label: Text(isLogin ? 'Login' : 'Sign up'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onToggleMode,
              child: Text(
                isLogin
                    ? 'Create a student account'
                    : 'I already have an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
