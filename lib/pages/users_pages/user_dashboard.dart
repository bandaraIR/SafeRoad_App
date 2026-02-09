import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saferoad/pages/users_pages/help_info_page.dart';
import 'package:saferoad/pages/users_pages/history_page.dart';
import 'package:saferoad/pages/users_pages/license_info_page.dart';
import 'package:saferoad/pages/users_pages/payment_page.dart';
import 'package:saferoad/pages/users_pages/sos_page.dart';
import 'package:saferoad/pages/users_pages/user_fine_page.dart';
import 'package:saferoad/pages/users_pages/user_notification_page.dart';
import 'package:saferoad/pages/users_pages/user_profile.dart';
import 'package:saferoad/services/license_service.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Function to check if license is expired
  bool _isLicenseExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate);
  }

  // Function to check if there are any overdue unpaid fines
  Future<bool> _hasOverdueUnpaidFines(String email) async {
    try {
      final finesSnapshot = await FirebaseFirestore.instance
          .collection('fines')
          .where('email', isEqualTo: email)
          .get();

      final now = DateTime.now();

      for (var fineDoc in finesSnapshot.docs) {
        final fineData = fineDoc.data();
        final dueDate = _parseFirestoreDate(fineData['dueDate']);
        final status = fineData['status']?.toString().toLowerCase() ?? '';

        // Check if fine is overdue and unpaid
        if (dueDate != null && now.isAfter(dueDate) && status != 'paid') {
          return true; // Found at least one overdue unpaid fine
        }
      }
      return false; // No overdue unpaid fines found
    } catch (e) {
      print('Error checking overdue fines: $e');
      return false;
    }
  }

  // Function to get license status considering both status field, expiry date, and overdue fines
  Future<String> _getLicenseStatus(
    Map<String, dynamic> userData,
    String currentStatus,
    String email,
  ) async {
    final expiryDate = _parseFirestoreDate(userData['expiryDate']);

    // If license is expired, override status to 'deactivated'
    if (_isLicenseExpired(expiryDate)) {
      return 'deactivated';
    }

    // Check for overdue unpaid fines
    final hasOverdueFines = await _hasOverdueUnpaidFines(email);
    if (hasOverdueFines) {
      return 'deactivated';
    }

    // Otherwise use the status from Firestore (convert to lowercase for consistency)
    return currentStatus.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final licenseService = LicenseService();

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
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
        title: StreamBuilder<Map<String, dynamic>>(
          stream: licenseService.licenseStatusStream(currentUser.email!),
          builder: (context, snapshot) {
            final userName = snapshot.hasData
                ? (snapshot.data!['userData']?['name'] ?? '').split(' ').first
                : 'User';
            final licenseNumber = snapshot.hasData
                ? snapshot.data!['licenseNumber'] ?? ''
                : '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Hello, $userName",
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  licenseNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationPage(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const UserProfilePage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          final enterTween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: Curves.easeInOut));

                          const exitBegin = Offset.zero;
                          const exitEnd = Offset(-1.0, 0.0);
                          final exitTween = Tween(
                            begin: exitBegin,
                            end: exitEnd,
                          ).chain(CurveTween(curve: Curves.easeInOut));

                          return SlideTransition(
                            position: animation.drive(enterTween),
                            child: SlideTransition(
                              position: secondaryAnimation.drive(exitTween),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                          );
                        },
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: licenseService.licenseStatusStream(currentUser.email!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data found'));
          }

          final data = snapshot.data!;
          final userData = data['userData'] ?? {};
          final currentStatus = data['status'] ?? 'active';
          final licenseNumber = data['licenseNumber'] ?? '';

          return FutureBuilder<String>(
            future: _getLicenseStatus(
              userData,
              currentStatus,
              currentUser.email!,
            ),
            builder: (context, statusSnapshot) {
              if (statusSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final licenseStatus = statusSnapshot.data ?? 'active';

              // Extract user information
              final fullName = userData['name'] ?? '';
              final idNumber = userData['idNumber'] ?? '';
              final address = userData['address'] ?? '';

              // Convert expiry date
              String expiryDateString = '';
              DateTime? expiryDate;
              if (userData['expiryDate'] != null) {
                expiryDate = _parseFirestoreDate(userData['expiryDate']);
                if (expiryDate != null) {
                  expiryDateString =
                      "${expiryDate.day.toString().padLeft(2, '0')}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.year}";
                }
              }

              // Check if license is expired for status display
              final isExpired = _isLicenseExpired(expiryDate);
              final isActive = licenseStatus == 'active' && !isExpired;
              final statusColor = isActive ? Colors.green : Colors.red;
              final statusText = isActive ? 'ACTIVE' : 'DEACTIVATED';

              // Add expiry warning if license is expired or expiring soon
              String? expiryWarning;
              Color? warningColor;
              if (isExpired) {
                expiryWarning = 'License Expired';
                warningColor = Colors.red;
              } else if (expiryDate != null) {
                final daysUntilExpiry = expiryDate
                    .difference(DateTime.now())
                    .inDays;
                if (daysUntilExpiry <= 30) {
                  expiryWarning = 'Expires in $daysUntilExpiry days';
                  warningColor = Colors.orange;
                }
              }

              // Check for overdue fines warning
              if (licenseStatus == 'deactivated' && !isExpired) {
                expiryWarning = 'Overdue Fine - License Deactivated';
                warningColor = Colors.red;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info Card with License Status in Bottom Left
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LicenseInfoPage(),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: expiryWarning != null ? 220 : 200,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[300]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      licenseNumber,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      idNumber,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70,
                                  ),
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Expiry warning
                                if (expiryWarning != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: warningColor!.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: warningColor!.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      expiryWarning,
                                      style: TextStyle(
                                        color: warningColor,
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                const Spacer(),

                                // Bottom row with Status on Left and Expiry on Right
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Status in Bottom Left Corner
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),

                                    // Expiry Date in Bottom Right
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Expires:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: 'Poppins',
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          expiryDateString,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Curved Line Artwork (your existing code remains the same)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Opacity(
                              opacity: 0.5,
                              child: CustomPaint(
                                size: const Size(80, 80),
                                painter: _CurvedLinePainter(),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 15,
                            left: 15,
                            child: Opacity(
                              opacity: 0.5,
                              child: CustomPaint(
                                size: const Size(60, 60),
                                painter: _WaveLinePainter(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 40,
                            left: 20,
                            child: Opacity(
                              opacity: 0.4,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: _CircleLinePainter(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 60,
                            right: 40,
                            child: Opacity(
                              opacity: 0.4,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: _CircleLinePainter(),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            right: 90,
                            child: Opacity(
                              opacity: 0.5,
                              child: CustomPaint(
                                size: const Size(40, 40),
                                painter: _SpiralLinePainter(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rest of your existing code remains the same...
                    // Notifications Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'see more',
                            style: TextStyle(
                              color: Colors.blue,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Real Notifications from Firestore
                    _buildNotificationsSection(currentUser.email!),
                    const SizedBox(height: 28),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      children: [
                        _buildQuickAction(
                          Icons.credit_card,
                          'Pay Fine',
                          Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PaymentPage(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          Icons.history,
                          'History',
                          Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryPage(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          Icons.gavel,
                          'Fines',
                          Colors.red,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UserFinesPage(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          Icons.badge,
                          'License',
                          Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LicenseInfoPage(),
                              ),
                            );
                          },
                        ),
                        _buildQuickAction(
                          Icons.sos,
                          'Emergency',
                          Colors.purple,
                          onTap: () {
                            final userId =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SOSPage(userId: userId),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in first'),
                                ),
                              );
                            }
                          },
                        ),
                        _buildQuickAction(
                          Icons.info_outline,
                          'Help & Info',
                          Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpInfoPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Your existing _buildNotificationsSection, _buildQuickAction, and _buildNotificationCard methods remain the same...
  Widget _buildNotificationsSection(String email) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fines')
          .where('email', isEqualTo: email)
          .snapshots(),
      builder: (context, finesSnapshot) {
        if (finesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!finesSnapshot.hasData || finesSnapshot.data!.docs.isEmpty) {
          return _buildNotificationCard(
            Icons.notifications_none,
            "No notifications",
            "You're all caught up!",
            Colors.grey,
          );
        }

        final fines = finesSnapshot.data!.docs;
        final now = DateTime.now();
        List<Map<String, dynamic>> notifications = [];

        for (var fine in fines) {
          final fineData = fine.data() as Map<String, dynamic>;
          final dueDate = _parseFirestoreDate(fineData['dueDate']);
          final status = fineData['status'] ?? 'Unknown';
          final issuedDate = _parseFirestoreDate(fineData['timestamp']) ?? now;

          // Fine notification
          notifications.add({
            'icon': Icons.gavel,
            'title': "Fine Issued",
            'message':
                "A fine was issued for ${fineData['reason'] ?? 'violation'}.",
            'color': Colors.amber,
            'timestamp': issuedDate,
            'type': 'fine',
          });

          // Due soon notification
          if (dueDate != null) {
            final daysLeft = dueDate.difference(now).inDays;
            if (daysLeft <= 3 && status != 'Paid') {
              notifications.add({
                'icon': Icons.warning_amber,
                'title': "Fine Due Soon",
                'message':
                    "Pay your fine within $daysLeft days to avoid penalties.",
                'color': Colors.orange,
                'timestamp': dueDate,
                'type': 'due_soon',
              });
            }
          }

          // Overdue fine notification
          if (dueDate != null && now.isAfter(dueDate) && status != 'Paid') {
            final daysOverdue = now.difference(dueDate).inDays;
            notifications.add({
              'icon': Icons.error_outline,
              'title': "Overdue Fine",
              'message':
                  "Fine is $daysOverdue days overdue. License deactivated.",
              'color': Colors.red,
              'timestamp': dueDate,
              'type': 'overdue',
            });
          }
        }

        // Sort by timestamp (newest first) and take only last 2
        notifications.sort((a, b) {
          final timeA = a['timestamp'] ?? DateTime.now();
          final timeB = b['timestamp'] ?? DateTime.now();
          return timeB.compareTo(timeA);
        });

        final lastTwoNotifications = notifications.take(2).toList();

        if (lastTwoNotifications.isEmpty) {
          return _buildNotificationCard(
            Icons.notifications_none,
            "No notifications",
            "You're all caught up!",
            Colors.grey,
          );
        }

        return Column(
          children: lastTwoNotifications.map((notif) {
            return _buildNotificationCard(
              notif['icon'],
              notif['title'],
              notif['message'],
              notif['color'],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
                    fontFamily: 'Poppins',
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

// Your existing CustomPainters remain the same...
class _CurvedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.7,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.5,
        size.width,
        size.height * 0.3,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaveLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final waveCount = 3;
    final waveWidth = size.width / waveCount;

    path.moveTo(0, size.height * 0.5);

    for (int i = 0; i < waveCount; i++) {
      final x = (i + 0.5) * waveWidth;
      final y = i % 2 == 0 ? size.height * 0.3 : size.height * 0.7;
      path.quadraticBezierTo(x, y, (i + 1) * waveWidth, size.height * 0.5);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.6, paint);
    canvas.drawCircle(center, radius * 0.3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpiralLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final turns = 3;

    path.moveTo(center.dx, center.dy);

    for (int i = 0; i <= 360 * turns; i += 5) {
      final angle = i * (3.14159 / 180);
      final radius = maxRadius * (i / (360 * turns));
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
