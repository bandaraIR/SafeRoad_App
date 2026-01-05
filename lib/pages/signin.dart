import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'setpassword_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _handleNext() async {
    final name = _nameController.text.trim();
    final licenseNumber = _licenseController.text.trim().toUpperCase();
    final email = _emailController.text.trim();

    if (name.isEmpty || licenseNumber.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Check if license exists
      final licenseDoc = await FirebaseFirestore.instance
          .collection("licenses")
          .doc(licenseNumber)
          .get();

      if (!licenseDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("License not found")),
        );
        setState(() => _loading = false);
        return;
      }

      // 2️⃣ Find user by licenseNumber
      final userQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("licenseNumber", isEqualTo: licenseNumber)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User record not found")),
        );
        setState(() => _loading = false);
        return;
      }

      final userDoc = userQuery.docs.first;

      // 3️⃣ Update email if empty
      final currentEmail = userDoc.data()["email"] ?? "";
      if (currentEmail.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This license already has an email")),
        );
        setState(() => _loading = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userDoc.id)
          .update({"email": email});

      // 4️⃣ Navigate to SetPasswordPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordPage(
            email: email,
            userDocId: userDoc.id,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final titleSize = (w / 20).clamp(28, 44).toDouble();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      height: w < 500 ? 160 : 200,
                      child: Image.asset(
                        'assets/images/signin/signin.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          width: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.person, size: 64, color: Color(0xFF0A86D8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: _fieldDecoration("User Name"),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _licenseController,
                    decoration: _fieldDecoration("License Number"),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    decoration: _fieldDecoration("Email Address"),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A86D8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Next",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
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
