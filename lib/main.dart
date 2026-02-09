import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'package:saferoad/pages/login_page.dart';
import 'package:saferoad/pages/admin_pages/admin_dashboard.dart';
import 'package:saferoad/pages/police_pages/police_dashboard_page.dart';
import 'package:saferoad/pages/users_pages/user_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FineApp());
}

class FineApp extends StatelessWidget {
  const FineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeRoad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const InitFirebase(),
    );
  }
}

class InitFirebase extends StatelessWidget {
  const InitFirebase({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Firebase init failed")),
          );
        }

        // 🔥 After Firebase is ready → go to AuthGate
        return const AuthGate();
      },
    );
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    await FirebaseFirestore.instance.enableNetwork();
  }
}

////////////////////////////////////////////////////////////
/// 🔐 AUTH GATE — Keeps user logged in after restart
////////////////////////////////////////////////////////////

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Checking login state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If logged in → decide role
        if (snapshot.hasData) {
          return const RoleRedirector();
        }

        // Not logged in
        return const LoginPage();
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// 🎯 ROLE REDIRECTOR
////////////////////////////////////////////////////////////

class RoleRedirector extends StatelessWidget {
  const RoleRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('admin')
          .doc(user.uid)
          .get(),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Admin
        if (adminSnap.hasData && adminSnap.data!.exists) {
          return const AdminDashboard();
        }

        // Check police
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('police')
              .doc(user.uid)
              .get(),
          builder: (context, policeSnap) {
            if (policeSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (policeSnap.hasData && policeSnap.data!.exists) {
              return const PoliceDashboard();
            }

            // Default user
            return const UserDashboard();
          },
        );
      },
    );
  }
}
