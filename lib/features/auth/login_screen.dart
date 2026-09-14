import 'package:flutter/material.dart';
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isLogin ? 'Welcome to FlowSlot' : 'Create Your Account',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Campus booking, queue management, and sustainability results.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),

              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              if (!_isLogin) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.school_outlined, color: Color(0xFF047857)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New public accounts are Student accounts. Staff/Admin access is assigned separately.',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Login' : 'Sign Up',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  _emailController.clear();
                  _passwordController.clear();
                  _nameController.clear();
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Sign Up"
                      : "Already have an account? Login",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
