import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

  // FIX: Track loading per section independently.
  // Criminal alerts load separately from policeId-based data,
  // so they never block each other or finish early.
  bool _loadingPoliceId = true;
  bool _loadingAlerts = true;

  bool get isLoading => _loadingPoliceId || _loadingAlerts;

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _criminalAlerts = [];

  StreamSubscription? _reportsSubscription;
  StreamSubscription? _announcementsSubscription;
  StreamSubscription? _criminalAlertsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCriminalAlertsListener();
      _fetchPoliceId();
    });
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _criminalAlertsSubscription?.cancel();
    super.dispose();
  }

  void _startCriminalAlertsListener() {
    debugPrint("Starting criminal alerts listener...");
    _criminalAlertsSubscription?.cancel();

    // FIX: Force a fresh fetch from the SERVER first (bypasses stale cache).
    // On second app run, Firestore's local cache can return an empty snapshot
    // before the real data arrives — Source.server skips the cache entirely.
    _firestore
        .collection('police_alerts')
        .get(const GetOptions(source: Source.server))
        .then((snapshot) {
          debugPrint(
            "Criminal alerts server fetch: ${snapshot.docs.length} docs",
          );
          if (!mounted) return;
          setState(() {
            _criminalAlerts = _processCriminalAlerts(snapshot.docs);
            _loadingAlerts = false;
          });

          // After initial load, attach live listener for real-time updates
          _criminalAlertsSubscription = _firestore
              .collection('police_alerts')
              .snapshots()
              .listen((snap) {
                if (!mounted) return;
                setState(() {
                  _criminalAlerts = _processCriminalAlerts(snap.docs);
                });
              }, onError: (e) => debugPrint("Criminal alerts live error: $e"));
        })
        .catchError((error) {
          // Offline fallback: use cache/snapshots instead
          debugPrint("Server fetch failed, falling back to stream: $error");
          _criminalAlertsSubscription = _firestore
              .collection('police_alerts')
              .snapshots()
              .listen(
                (snap) {
                  if (!mounted) return;
                  setState(() {
                    _criminalAlerts = _processCriminalAlerts(snap.docs);
                    _loadingAlerts = false;
                  });
                },
                onError: (e) {
                  debugPrint("Criminal alerts fallback error: $e");
                  if (mounted) setState(() => _loadingAlerts = false);
                },
              );
        });
  }

  Future<void> _fetchPoliceId() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _loadingPoliceId = false);
        return;
      }

      debugPrint("Current user email: ${currentUser.email}");

      final querySnapshot = await _firestore
          .collection('police')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final loadedPoliceId = data['policeId']?.toString();
        debugPrint("Loaded policeId: $loadedPoliceId");
        setState(() {
          policeId = loadedPoliceId;
          _loadingPoliceId = false;
        });
        _startPoliceSpecificListeners();
      } else {
        debugPrint("No police document found for: ${currentUser.email}");
        setState(() => _loadingPoliceId = false);
      }
    } catch (e) {
      debugPrint("Error fetching policeId: $e");
      if (mounted) setState(() => _loadingPoliceId = false);
    }
  }

  void _startPoliceSpecificListeners() {
    if (policeId == null || policeId!.isEmpty) return;
    debugPrint("Starting police-specific listeners for policeId: $policeId");

    _reportsSubscription?.cancel();
    _announcementsSubscription?.cancel();

    _reportsSubscription = _firestore
        .collection('reports')
        .where('policeId', isEqualTo: policeId)
        .snapshots()
        .listen((snapshot) {
          debugPrint("Reports update: ${snapshot.docs.length} docs");
          if (!mounted) return;
          setState(() => _reports = _processReports(snapshot.docs));
        }, onError: (e) => debugPrint("Reports stream error: $e"));

    _announcementsSubscription = _firestore
        .collection('announcements')
        .where('eligiblePoliceIds', arrayContains: policeId)
        .snapshots()
        .listen((snapshot) {
          debugPrint("Announcements update: ${snapshot.docs.length} docs");
          if (!mounted) return;
          setState(() => _announcements = _processAnnouncements(snapshot.docs));
        }, onError: (e) => debugPrint("Announcements stream error: $e"));
  }

  void _refreshData() {
    _reportsSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _criminalAlertsSubscription?.cancel();

    setState(() {
      _reports = [];
      _announcements = [];
      _criminalAlerts = [];
      _loadingPoliceId = policeId == null;
      _loadingAlerts = true;
    });

    _startCriminalAlertsListener();

    if (policeId != null && policeId!.isNotEmpty) {
      _startPoliceSpecificListeners();
    } else {
      _fetchPoliceId();
    }
  }

  // ─── Data processors ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> _processReports(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> reports = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final email = data['email']?.toString() ?? 'Unknown';
      final reason = data['reason']?.toString() ?? 'No reason provided';
      final area = data['area']?.toString() ?? 'Unknown';
      final timestamp = _parseFirestoreDate(data['timestamp']);
      final status = data['status']?.toString() ?? 'Pending';

      reports.add({
        'icon': Icons.report_problem,
        'title': "New Report from $area",
        'message': "From: $email\nReason: $reason",
        'color': Colors.orange,
        'timestamp': timestamp ?? DateTime.now(),
        'status': status,
        'type': 'report',
        'id': doc.id,
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
          'id': doc.id,
        });
      }
    }
    return reports;
  }

  List<Map<String, dynamic>> _processAnnouncements(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'icon': Icons.announcement,
        'title': "New Announcement - ${data['category'] ?? 'General'}",
        'message':
            "Area: ${data['area'] ?? 'Unknown'}\nLocation: ${data['location'] ?? 'Unknown'}\nDetails: ${data['description'] ?? ''}",
        'color': Colors.blue,
        'timestamp': _parseFirestoreDate(data['createdAt']) ?? DateTime.now(),
        'status': 'info',
        'type': 'announcement',
        'id': doc.id,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _processCriminalAlerts(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final plate =
          data['plateNumber']?.toString() ??
          data['plate_number']?.toString() ??
          data['vehicleNumber']?.toString() ??
          'Unknown';
      final reason = data['reason']?.toString() ?? 'Unknown Crime';
      final location =
          data['location']?.toString() ??
          data['cameraLocation']?.toString() ??
          'Unknown Location';
      final timestamp =
          _parseFirestoreDate(data['detectedAt']) ??
          _parseFirestoreDate(data['timestamp']) ??
          _parseFirestoreDate(data['createdAt']);
      final status = data['status']?.toString() ?? 'UNKNOWN';

      return {
        'icon': Icons.local_police,
        'title': "🚨 Wanted Vehicle Detected",
        'message': "Plate: $plate\nLocation: $location\nCrime: $reason",
        'color': status == 'NEW' ? Colors.red : Colors.deepOrange,
        'timestamp': timestamp ?? DateTime.now(),
        'status': status,
        'type': 'criminal_alert',
        'id': doc.id,
      };
    }).toList();
  }

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isUrgentReport(String reason) {
    const urgentKeywords = [
      'emergency',
      'urgent',
      'accident',
      'crime',
      'theft',
      'assault',
    ];
    return urgentKeywords.any((k) => reason.toLowerCase().contains(k));
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

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
        body: const Center(
          child: Text(
            "No Police ID Found\nPlease contact administrator",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
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

  Widget _buildContent() {
    final allNotifications = [
      ..._criminalAlerts,
      ..._reports,
      ..._announcements,
    ];
    allNotifications.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    if (allNotifications.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allNotifications.length,
        itemBuilder: (context, index) {
          final n = allNotifications[index];
          return _buildNotificationCard(
            n['icon'],
            n['title'],
            n['message'],
            n['color'],
            n['status'],
            n['timestamp'],
            n['type'],
            n['id'],
          );
        },
      ),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "You'll see reports, announcements, and alerts here soon.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
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
    String? id,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(type, id),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(String type, String? id) {
    switch (type) {
      case 'report':
      case 'urgent_report':
        break;
      case 'announcement':
        break;
      case 'criminal_alert':
        break;
    }
  }

  void _debugCheckCurrentData() async {
    debugPrint("=== DEBUG INFO ===");
    debugPrint("Police ID: $policeId");
    debugPrint("Reports: ${_reports.length}");
    debugPrint("Announcements: ${_announcements.length}");
    debugPrint("Criminal Alerts: ${_criminalAlerts.length}");
    debugPrint("=== END DEBUG ===");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Reports: ${_reports.length}, Announcements: ${_announcements.length}, Alerts: ${_criminalAlerts.length}",
            style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
  }
}
