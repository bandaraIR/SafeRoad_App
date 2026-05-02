import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:saferoad/pages/police_pages/check_users_page.dart';
import 'package:saferoad/pages/police_pages/fine_history_police.dart';
import 'package:saferoad/pages/police_pages/notification.dart';
import 'package:saferoad/pages/police_pages/place_fine_page.dart';
import 'package:saferoad/pages/police_pages/police_appeal_page.dart';
import 'package:saferoad/pages/police_pages/police_profile_page.dart';
import 'package:saferoad/pages/police_pages/vehicle_lookup_page.dart';
import 'add_police_page.dart';

class PoliceDashboard extends StatefulWidget {
  const PoliceDashboard({super.key});

  @override
  State<PoliceDashboard> createState() => _PoliceDashboardState();
}

class _PoliceDashboardState extends State<PoliceDashboard>
    with WidgetsBindingObserver {
  String officerName = "Officer";
  String officerId = "N/A";
  String officerEmail = "";
  bool onlineStatus = false;
  bool isLoading = true;
  String? currentUserId;
  String? policeDocId;

  // Real notifications data
  List<Map<String, dynamic>> _notifications = [];
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPoliceData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 App Lifecycle State: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set online
        print('📱 App resumed - Setting ONLINE');
        _setOnlineStatus();
        break;
      case AppLifecycleState.inactive:
        // App is inactive - set offline
        print('📱 App inactive - Setting OFFLINE');
        _setOfflineStatus();
        break;
      case AppLifecycleState.paused:
        // App is in background - set offline
        print('📱 App paused - Setting OFFLINE');
        _setOfflineStatus();
        break;
      case AppLifecycleState.detached:
        // App is closed - set offline
        print('📱 App detached - Setting OFFLINE');
        _setOfflineStatus();
        break;
      case AppLifecycleState.hidden:
        // App is hidden - set offline
        print('📱 App hidden - Setting OFFLINE');
        _setOfflineStatus();
        break;
    }
  }

  @override
  void dispose() {
    print('🚪 Dashboard disposed - Setting OFFLINE');
    _setOfflineStatus();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Set online status
  Future<void> _setOnlineStatus() async {
    if (policeDocId != null && mounted) {
      try {
        print('🟢 Attempting to set ONLINE status...');
        await _firestore.collection('police').doc(policeDocId).update({
          'onlineStatus': true,
          'lastOnline': FieldValue.serverTimestamp(),
        });

        setState(() {
          onlineStatus = true;
        });
        print('🟢 Successfully set ONLINE status');
      } catch (e) {
        print('❌ Error setting online status: $e');
      }
    } else {
      print('❌ Cannot set online: policeDocId is null or widget not mounted');
    }
  }

  // Set offline status
  Future<void> _setOfflineStatus() async {
    if (policeDocId != null) {
      try {
        print('🔴 Attempting to set OFFLINE status...');
        await _firestore.collection('police').doc(policeDocId).update({
          'onlineStatus': false,
          'lastOnline': FieldValue.serverTimestamp(),
        });
        print('🔴 Successfully set OFFLINE status');
      } catch (e) {
        print('❌ Error setting offline status: $e');
      }
    } else {
      print('❌ Cannot set offline: policeDocId is null');
    }
  }

  Future<void> _loadPoliceData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      currentUserId = user.uid;
      print('👤 Loading data for user: ${user.email}');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('police')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        policeDocId = doc.id;
        final data = doc.data();

        print('📄 Found police data: ${data['name']}');

        setState(() {
          officerName = data['name'] ?? "Unknown Officer";
          officerId = data['policeId'] ?? "N/A";
          officerEmail = data['email'] ?? "No email";
          onlineStatus = data['onlineStatus'] ?? false;
        });

        // Set online status after loading data
        await _setOnlineStatus();
        _startListeningToNotifications();
      } else {
        print('❌ No police data found for email: ${user.email}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ Error loading police data: $e");
      setState(() => isLoading = false);
    }
  }

  // Manual toggle for online/offline status
  Future<void> _toggleOnlineStatus() async {
    try {
      final newStatus = !onlineStatus;
      print(
        '🔄 Manually toggling status to: ${newStatus ? "ONLINE" : "OFFLINE"}',
      );

      if (policeDocId != null) {
        await _firestore.collection('police').doc(policeDocId).update({
          'onlineStatus': newStatus,
          'lastOnline': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        onlineStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? "You are now ONLINE" : "You are now OFFLINE",
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("❌ Error updating online status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update status"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startListeningToNotifications() {
    print('🔔 Starting notifications listener...');

    // Listen to reports stream
    _firestore
        .collection('reports')
        .where('policeId', isEqualTo: officerId)
        .snapshots()
        .listen(
          (snapshot) {
            _processReports(snapshot.docs);
          },
          onError: (error) {
            print("❌ Reports stream error: $error");
          },
        );

    // Listen to announcements stream
    _firestore
        .collection('announcements')
        .where('eligiblePoliceIds', arrayContains: officerId)
        .snapshots()
        .listen(
          (snapshot) {
            _processAnnouncements(snapshot.docs);
            setState(() => isLoading = false);
            print('✅ Notifications setup complete');
          },
          onError: (error) {
            print("❌ Announcements stream error: $error");
            setState(() => isLoading = false);
          },
        );
  }

  void _processReports(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> reports = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final email = data['email'] ?? 'Unknown';
      final reason = data['reason'] ?? 'No reason provided';
      final area = data['area'] ?? 'Unknown';
      final timestamp = _parseFirestoreDate(data['timestamp']);
      final status = data['status'] ?? 'Pending';

      reports.add({
        'icon': Icons.report_problem,
        'title': "New Report from $area",
        'message': "From: $email\nReason: $reason",
        'color': Colors.orange,
        'timestamp': timestamp ?? DateTime.now(),
        'status': status,
        'type': 'report',
      });

      if (_isUrgentReport(reason)) {
        reports.add({
          'icon': Icons.warning_amber,
          'title': "🚨 Urgent Report - $area",
          'message': "Immediate attention required!\nReason: $reason",
          'color': Colors.red,
          'timestamp': timestamp ?? DateTime.now(),
          'status': 'urgent',
          'type': 'urgent_report',
        });
      }
    }

    _updateNotificationsList(reports, 'reports');
  }

  void _processAnnouncements(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> announcements = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final area = data['area'] ?? 'Unknown';
      final category = data['category'] ?? 'General';
      final description = data['description'] ?? '';
      final location = data['location'] ?? 'Unknown';
      final createdAt = _parseFirestoreDate(data['createdAt']);

      announcements.add({
        'icon': Icons.announcement,
        'title': "New Announcement - $category",
        'message': "Area: $area\nLocation: $location\nDetails: $description",
        'color': Colors.blue,
        'timestamp': createdAt ?? DateTime.now(),
        'status': 'info',
        'type': 'announcement',
        'id': doc.id,
      });
    }

    _updateNotificationsList(announcements, 'announcements');
  }

  void _updateNotificationsList(
    List<Map<String, dynamic>> newItems,
    String source,
  ) {
    // Remove old items of the same source type
    _notifications.removeWhere((notif) => notif['_source'] == source);

    // Add new items with source identifier
    for (var item in newItems) {
      item['_source'] = source;
    }

    _notifications.addAll(newItems);

    // Sort by timestamp (newest first)
    _notifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isUrgentReport(String reason) {
    final urgentKeywords = [
      'emergency',
      'urgent',
      'accident',
      'crime',
      'theft',
      'assault',
    ];
    return urgentKeywords.any(
      (keyword) => reason.toLowerCase().contains(keyword),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Loading Dashboard...",
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 80,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[800]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hello, $officerName",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              officerId,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        actions: [
          // Online Status Indicator in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: _toggleOnlineStatus,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: onlineStatus
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      onlineStatus ? "Online" : "Offline",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PoliceNotificationsPage(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {},
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PoliceProfilePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, color: Colors.blue),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRealNotificationsSection(),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER SECTION -----------------
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Welcome Back!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Stay alert and ready for duty",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontFamily: 'Poppins',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Tappable Online Status Indicator
              GestureDetector(
                onTap: _toggleOnlineStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: onlineStatus
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        onlineStatus ? "Online" : "Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_horiz,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                officerEmail.isNotEmpty ? officerEmail : "No email",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status Description
          Text(
            onlineStatus
                ? "You are visible and available for assignments"
                : "You are not available for new assignments",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontFamily: 'Poppins',
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildActionButton("Add Police", Icons.person_add, Colors.blue),
            _buildActionButton("Check Users", Icons.people, Colors.green),
            _buildActionButton("Place Fine", Icons.receipt, Colors.orange),
            _buildActionButton(
              "Vehicle LookUp",
              Icons.directions_car,
              Colors.purple,
            ),
            _buildActionButton("Appeal", Icons.gavel, Colors.red),
            _buildActionButton("Fine History", Icons.history, Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == "Add Police") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPolicePage()),
          );
        } else if (title == "Check Users") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CheckUsersPage()),
          );
        } else if (title == "Vehicle LookUp") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VehicleLookupPage()),
          );
        } else if (title == "Place Fine") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlaceFinePage()),
          );
        } else if (title == "Fine History") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FineHistoryPage()),
          );
        } else if (title == "Appeal") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PoliceAppealPage()),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealNotificationsSection() {
    // Get only the last 2 notifications
    final lastTwoNotifications = _notifications.take(2).toList();
    final newNotificationsCount = _notifications.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Recent Notifications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontFamily: 'Poppins',
              ),
            ),
            const Spacer(),
            if (newNotificationsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$newNotificationsCount New",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (lastTwoNotifications.isEmpty)
          _buildEmptyNotificationState()
        else
          ...lastTwoNotifications.map(
            (notif) => _buildRealNotificationItem(
              notif['icon'],
              notif['title'],
              notif['message'],
              notif['color'],
              notif['timestamp'],
              notif['type'],
            ),
          ),

        const SizedBox(height: 8),

        // Always show "View All" button if there are notifications
        if (_notifications.isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PoliceNotificationsPage(),
                  ),
                );
              },
              child: Text(
                "View All Notifications",
                style: TextStyle(
                  color: Colors.blue[600],
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyNotificationState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            "No Notifications",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll see reports and announcements here when they arrive.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealNotificationItem(
    IconData icon,
    String title,
    String message,
    Color color,
    DateTime timestamp,
    String type,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
