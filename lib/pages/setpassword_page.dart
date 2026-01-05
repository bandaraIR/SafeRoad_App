import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class SetPasswordPage extends StatefulWidget {
  final String email;
  final String userDocId;

  const SetPasswordPage({
    super.key,
    required this.email,
    required this.userDocId,
  });

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  Future<void> _setPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill both fields")),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 8 characters")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Create user in FirebaseAuth
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup successful! Please login.")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _pillField(String hint,
      {bool isPassword = false, bool show = false, VoidCallback? toggle}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: toggle,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Set a password",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: _pillField(
                  "New password",
                  isPassword: true,
                  show: _showPassword,
                  toggle: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: _pillField(
                  "Confirm password",
                  isPassword: true,
                  show: _showConfirmPassword,
                  toggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _setPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A86D8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Set",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
