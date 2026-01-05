import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saferoad/pages/admin_pages/admin_dashboard.dart';
import 'package:saferoad/pages/forgot_password_page.dart';
import 'package:saferoad/pages/police_pages/police_dashboard_page.dart';
import 'package:saferoad/pages/signin.dart';
import 'package:saferoad/pages/users_pages/user_dashboard.dart';
import 'package:saferoad/utils/colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Sign in with Firebase Auth
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCred.user!.uid;
      print("Firebase Auth successful - UID: $uid");

      // 2️⃣ Check all collections for user data
      String role = 'user'; // Default role
      String? userName;
      String? userEmail;

      // Search strategy: Check all possible collections
      bool userFound = false;

      // First, try to find user in 'police' collection by UID (since authId = police docId)
      print("Checking 'police' collection by UID: $uid");
      final policeDoc = await FirebaseFirestore.instance
          .collection('police')
          .doc(uid)
          .get();

      if (policeDoc.exists) {
        print("Police found in 'police' collection by UID");
        role = policeDoc.data()?['role'] ?? 'police';
        userName = policeDoc.data()?['name'];
        userEmail = policeDoc.data()?['email'];
        userFound = true;
      } else {
        // If not found by UID in police, check by email
        print("Police not found by UID, searching by email in 'police' collection");
        final policeQuery = await FirebaseFirestore.instance
            .collection('police')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (policeQuery.docs.isNotEmpty) {
          final policeData = policeQuery.docs.first.data();
          role = policeData['role'] ?? 'police';
          userName = policeData['name'];
          userEmail = policeData['email'];
          print("Police found in 'police' collection by email - Role: $role");
          userFound = true;
        }
      }

      // If not found in police collection, check users collection
      if (!userFound) {
        print("Checking 'users' collection by UID");
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          print("User found in 'users' collection");
          role = userDoc.data()?['role'] ?? 'user';
          userName = userDoc.data()?['name'];
          userEmail = userDoc.data()?['email'];
          userFound = true;
        } else {
          // If not found by UID, try searching by email in 'users' collection
          print("User not found by UID, searching by email in 'users' collection");
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final userData = userQuery.docs.first.data();
            role = userData['role'] ?? 'user';
            userName = userData['name'];
            userEmail = userData['email'];
            print("User found in 'users' collection by email - Role: $role");
            userFound = true;
          }
        }
      }

      // If still not found, check admin collection
      if (!userFound) {
        print("Checking 'admin' collection by UID");
        final adminDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc(uid)
            .get();

        if (adminDoc.exists) {
          print("Admin found in 'admin' collection by UID");
          role = 'admin';
          userName = adminDoc.data()?['name'];
          userEmail = adminDoc.data()?['email'];
          userFound = true;
        } else {
          // Check admin collection by email
          print("🔍 Checking 'admin' collection by email");
          final adminQuery = await FirebaseFirestore.instance
              .collection('admin')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (adminQuery.docs.isNotEmpty) {
            final adminData = adminQuery.docs.first.data();
            role = 'admin';
            userName = adminData['name'];
            userEmail = adminData['email'];
            print("Admin found in 'admin' collection by email");
            userFound = true;
          }
        }
      }

      if (!userFound) {
        print("User not found in any collection (police, users, admin)");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User data not found in system")),
        );
        return;
      }

      print("Final determined role: $role");
      print("User name: $userName");
      print("User email: $userEmail");

      // 3️⃣ Navigate based on role
      switch (role) {
        case 'admin':
          print("Navigating to Admin Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
          break;
        case 'police':
          print("Navigating to Police Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PoliceDashboard()),
          );
          break;
        default:
          print("Navigating to User Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserDashboard()),
          );
          break;
      }

    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } catch (e) {
      print("General Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
          maxWidth: 48,
          maxHeight: 48,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final padding = w >= 1200
        ? const EdgeInsets.symmetric(horizontal: 48, vertical: 32)
        : w >= 800
            ? const EdgeInsets.symmetric(horizontal: 36, vertical: 28)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
    final titleSize = (w / 20).clamp(28, 44).toDouble();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: SizedBox(
                        height: w < 500 ? 180 : 220,
                        child: Image.asset(
                          'assets/images/login/login.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            height: 160,
                            width: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.lock, size: 72, color: blue),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: w < 500 ? 8 : 16),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration('Email Address'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _fieldDecoration(
                          'Password',
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                            );
                          },
                          child: Text('Forgot Password ?',
                              style: TextStyle(color: blue)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A86D8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Login'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'DO YOU HAVE ACCOUNT?',
                            style: TextStyle(
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const SignInPage()),
                              );
                            },
                            style: TextButton.styleFrom(foregroundColor: blue),
                            child: const Text('SIGN UP'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}