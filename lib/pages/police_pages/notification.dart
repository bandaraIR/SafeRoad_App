import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PoliceNotificationsPage extends StatefulWidget {
  const PoliceNotificationsPage({super.key});

  @override
  State<PoliceNotificationsPage> createState() =>
      _PoliceNotificationsPageState();
}

class _PoliceNotificationsPageState extends State<PoliceNotificationsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? policeId;
  bool isLoading = true;

  // Separate lists for better management
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchPoliceId();
  }

  Future<void> _fetchPoliceId() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await _firestore
          .collection('police')
          .doc(currentUser.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('policeId')) {
        setState(() {
          policeId = doc['policeId'];
        });
        _startListeningToStreams();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching policeId: $e");
      setState(() => isLoading = false);
    }
  }

  void _startListeningToStreams() {
    // Listen to reports stream
    _firestore
        .collection('reports')
        .where('policeId', isEqualTo: policeId)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint("Reports update: ${snapshot.docs.length} documents");

            setState(() {
              _reports = _processReports(snapshot.docs);
            });
          },
          onError: (error) {
            debugPrint("Reports stream error: $error");
          },
        );

    // Listen to announcements stream
    _firestore
        .collection('announcements')
        .where('eligiblePoliceIds', arrayContains: policeId)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              "Announcements update: ${snapshot.docs.length} documents",
            );

            setState(() {
              _announcements = _processAnnouncements(snapshot.docs);
              isLoading = false;
            });
          },
          onError: (error) {
            debugPrint("Announcements stream error: $error");
            setState(() => isLoading = false);
          },
        );
  }

  List<Map<String, dynamic>> _processReports(List<QueryDocumentSnapshot> docs) {
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

    return reports;
  }

  List<Map<String, dynamic>> _processAnnouncements(
    List<QueryDocumentSnapshot> docs,
  ) {
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

    return announcements;
  }

  /// Safely parse Firestore date (handles Timestamp or String)
  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (policeId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: Text("No Police ID Found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Police Notifications",
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        backgroundColor: Colors.blue[600],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
            color: Colors.white,
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: _buildContent(),
    );
  }

  void _refreshData() {
    // Manually check the current state of data
    _debugCheckCurrentData();
  }

  void _debugCheckCurrentData() async {
    debugPrint("=== DEBUG INFO ===");
    debugPrint("Police ID: $policeId");
    debugPrint("Reports count: ${_reports.length}");
    debugPrint("Announcements count: ${_announcements.length}");

    // Check announcements directly from Firestore
    try {
      final announcementSnapshot = await _firestore
          .collection('announcements')
          .where('eligiblePoliceIds', arrayContains: policeId)
          .get();

      debugPrint(
        "Direct Firestore query - Announcements: ${announcementSnapshot.docs.length}",
      );

      for (var doc in announcementSnapshot.docs) {
        final data = doc.data();
        debugPrint("Announcement: ${doc.id}");
        debugPrint("  - eligiblePoliceIds: ${data['eligiblePoliceIds']}");
        debugPrint(
          "  - contains policeId: ${(data['eligiblePoliceIds'] as List).contains(policeId)}",
        );
        debugPrint("  - data: $data");
      }
    } catch (e) {
      debugPrint("Error in debug query: $e");
    }

    debugPrint("=== END DEBUG ===");

    // Show snackbar with debug info
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Refreshed: ${_announcements.length} announcements, ${_reports.length} reports",
            style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildContent() {
    final allNotifications = [..._reports, ..._announcements];

    // Sort by timestamp
    allNotifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    if (allNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allNotifications.length,
      itemBuilder: (context, index) {
        final notif = allNotifications[index];
        return _buildNotificationCard(
          notif['icon'],
          notif['title'],
          notif['message'],
          notif['color'],
          notif['status'],
          notif['timestamp'],
          notif['type'],
        );
      },
    );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No Notifications Yet",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You'll see reports or announcements here soon.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _debugCheckCurrentData,
            icon: const Icon(Icons.bug_report),
            label: const Text('Debug Info'),
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
    String? status,
    DateTime timestamp,
    String type,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            child: Icon(icon, color: color, size: 24),
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
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
}
