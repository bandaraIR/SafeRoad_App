import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Safely parse Firestore date (handles Timestamp or String)
  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('fines')
            .where('email', isEqualTo: user.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications available"));
          }

          final fines = snapshot.data!.docs;
          final now = DateTime.now();

          List<Map<String, dynamic>> notifications = [];

          for (var fine in fines) {
            final fineData = fine.data() as Map<String, dynamic>;
            final dueDate = _parseFirestoreDate(fineData['dueDate']);
            final status = fineData['status'] ?? 'Unknown';
            final offenseType = fineData['offenseType'] ?? 'violation';
            final amount = fineData['amount'] ?? 'N/A';
            final policeId = fineData['policeId'] ?? 'Unknown polliceId';
            final reason = fineData['reason'] ?? 'No reason provided';

            // Fine notification with detailed information
            notifications.add({
              'icon': Icons.gavel,
              'title': "Fine Issued - \$$amount",
              'message':
                  "Offense: $offenseType\npoliceId: $policeId\nReason: $reason",
              'color': Colors.orange,
              'timestamp': fineData['issuedDate'] ?? DateTime.now(),
            });

            // Due soon notification
            if (dueDate != null) {
              final daysLeft = dueDate.difference(now).inDays;
              if (daysLeft <= 3 && status != 'Paid') {
                notifications.add({
                  'icon': Icons.warning_amber,
                  'title': "Fine Due Soon",
                  'message':
                      "Pay your \$$amount fine for $offenseType within $daysLeft days to avoid penalties.",
                  'color': Colors.orange,
                  'timestamp': dueDate,
                });
              }
            }
          }

          // License expiry notification
          return FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('users')
                .where('email', isEqualTo: user.email)
                .limit(1)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.hasData && userSnap.data!.docs.isNotEmpty) {
                final userData =
                    userSnap.data!.docs.first.data() as Map<String, dynamic>;
                final expiryDate = _parseFirestoreDate(userData['expiryDate']);
                if (expiryDate != null) {
                  final daysLeft = expiryDate.difference(now).inDays;
                  if (daysLeft <= 580 && daysLeft > 0) {
                    notifications.add({
                      'icon': Icons.add_card,
                      'title': "License Expiry Soon",
                      'message':
                          "Your license will expire in $daysLeft days. Renew early to avoid suspension!",
                      'color': Colors.blue,
                      'timestamp': expiryDate,
                    });
                  } else if (daysLeft <= 0) {
                    notifications.add({
                      'icon': Icons.error,
                      'title': "License Expired",
                      'message':
                          "Your license has expired! Renew immediately to avoid legal issues.",
                      'color': Colors.red,
                      'timestamp': expiryDate,
                    });
                  }
                }
              }

              // Sort notifications by timestamp (most recent first)
              notifications.sort((a, b) {
                final timeA =
                    _parseFirestoreDate(a['timestamp']) ?? DateTime.now();
                final timeB =
                    _parseFirestoreDate(b['timestamp']) ?? DateTime.now();
                return timeB.compareTo(timeA);
              });

              if (notifications.isEmpty) {
                return const Center(child: Text("No notifications available"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationCard(
                    notif['icon'],
                    notif['title'],
                    notif['message'],
                    notif['color'],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    IconData icon,
    String title,
    String message,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
