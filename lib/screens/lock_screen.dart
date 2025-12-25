import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/crypto_service.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _crypto = CryptoService();
  
  bool _isFirstTime = true;
  bool _isLoading = true;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final hash = await _storage.read(key: 'password_hash');
    setState(() {
      _isFirstTime = hash == null;
      _isLoading = false;
    });
  }

  Future<void> _handleSubmit() async {
    final password = _passwordController.text;
    
    if (password.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    if (_isFirstTime) {
      final confirm = _confirmController.text;
      if (password != confirm) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
      
      final hash = _crypto.hashPassword(password);
      await _storage.write(key: 'password_hash', value: hash);
      _crypto.setMasterKey(password);
      _navigateToHome();
    } else {
      final storedHash = await _storage.read(key: 'password_hash');
      final inputHash = _crypto.hashPassword(password);
      
      if (storedHash == inputHash) {
        _crypto.setMasterKey(password);
        _navigateToHome();
      } else {
        setState(() => _error = 'Incorrect password');
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 50,
                      color: Color(0xFF6C63FF),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.05, 1.05)),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'SecureNotes',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isFirstTime 
                        ? 'Create your master password' 
                        : 'Enter your password to unlock',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  
                  const SizedBox(height: 48),
                  
                  // Password Field
                  _buildPasswordField(
                    controller: _passwordController,
                    hint: 'Password',
                    delay: 300,
                  ),
                  
                  if (_isFirstTime) ...[
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmController,
                      hint: 'Confirm Password',
                      delay: 400,
                    ),
                  ],
                  
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF6B6B)),
                    ).animate().shake(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isFirstTime ? 'Create Password' : 'Unlock',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required int delay,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white38,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onSubmitted: (_) => _handleSubmit(),
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay)).slideX(begin: -0.1);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
