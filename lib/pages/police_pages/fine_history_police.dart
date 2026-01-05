import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FineHistoryPage extends StatefulWidget {
  const FineHistoryPage({super.key});

  @override
  State<FineHistoryPage> createState() => _FineHistoryPageState();
}

class _FineHistoryPageState extends State<FineHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _officerId = "";
  String _officerEmail = "";
  bool _isLoading = true;
  List<Map<String, dynamic>> _fines = [];
  String _searchQuery = "";
  String _filterStatus = "All";

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
  }

  Future<void> _loadOfficerData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _officerEmail = user.email ?? "No email";

      // Get police officer data to retrieve policeId
      final policeQuery = await _firestore
          .collection('police')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (policeQuery.docs.isNotEmpty) {
        final policeData = policeQuery.docs.first.data();
        _officerId = policeData['policeId']?.toString().trim() ?? "";

        debugPrint("🎯 Officer ID: '$_officerId'");
        debugPrint("📧 Officer Email: '$_officerEmail'");

        _loadFines();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error loading officer data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFines() async {
    try {
      if (_officerId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      debugPrint("🔍 Searching for fines with policeId: '$_officerId'");

      // Get ALL fines and filter locally to handle any data issues
      final allFinesSnapshot = await _firestore
          .collection('fines')
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint(
        "📊 Total fines in collection: ${allFinesSnapshot.docs.length}",
      );

      List<Map<String, dynamic>> fines = [];

      for (var doc in allFinesSnapshot.docs) {
        final data = doc.data();
        final finePoliceId = data['policeId']?.toString().trim() ?? "";
        final originalFinePoliceId =
            data['policeId']?.toString() ?? "No policeId";
        final fineId = data['fineId']?.toString() ?? "No fineId";

        debugPrint(
          "📝 Fine: $fineId | PoliceId in DB: '$originalFinePoliceId' | Trimmed: '$finePoliceId' | Match: ${finePoliceId == _officerId}",
        );

        // Compare trimmed versions to handle spacing issues
        if (finePoliceId == _officerId) {
          fines.add({
            'id': doc.id,
            ...data,
            'timestamp': _parseTimestamp(data['timestamp']),
            'paymentDate': _parseTimestamp(data['paymentDate']),
          });
        }
      }

      debugPrint("✅ Found ${fines.length} fines for officer '$_officerId'");

      setState(() {
        _fines = fines;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error loading fines: $e");
      setState(() => _isLoading = false);
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String)
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    return DateTime.now();
  }

  List<Map<String, dynamic>> get _filteredFines {
    List<Map<String, dynamic>> filtered = _fines;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((fine) {
        final vehicleNumber =
            fine['vehicleNumber']?.toString().toLowerCase() ?? '';
        final licenseNumber =
            fine['licenseNumber']?.toString().toLowerCase() ?? '';
        final reason = fine['reason']?.toString().toLowerCase() ?? '';
        final fineId = fine['fineId']?.toString().toLowerCase() ?? '';

        return vehicleNumber.contains(_searchQuery.toLowerCase()) ||
            licenseNumber.contains(_searchQuery.toLowerCase()) ||
            reason.contains(_searchQuery.toLowerCase()) ||
            fineId.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (_filterStatus != "All") {
      filtered = filtered.where((fine) {
        return fine['status']?.toString().toLowerCase() ==
            _filterStatus.toLowerCase();
      }).toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green.shade800;
      case 'pending':
        return Colors.orange.shade800;
      case 'overdue':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  Widget _buildFineCard(Map<String, dynamic> fine) {
    final timestamp = fine['timestamp'] as DateTime;
    final paymentDate = fine['paymentDate'] as DateTime?;
    final status = fine['status']?.toString() ?? 'Pending';
    final amount = fine['amount']?.toString() ?? '0';
    final reason = fine['reason']?.toString() ?? 'No reason provided';
    final vehicleNumber = fine['vehicleNumber']?.toString() ?? 'N/A';
    final licenseNumber = fine['licenseNumber']?.toString() ?? 'N/A';
    final fineId = fine['fineId']?.toString() ?? 'N/A';
    final dueDate = fine['dueDate']?.toString() ?? 'N/A';
    final policeId = fine['policeId']?.toString() ?? 'N/A';
    final email = fine['email']?.toString() ?? 'N/A';
    final type = fine['type']?.toString() ?? 'Manual';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with Fine ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Fine ID: $fineId",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusTextColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount and Reason
            Row(
              children: [
                Text(
                  "Rs. $amount",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details in a nice layout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow("Vehicle Number", vehicleNumber),
                  _buildDetailRow("License Number", licenseNumber),
                  _buildDetailRow("Driver Email", email),
                  _buildDetailRow("Due Date", dueDate),
                  _buildDetailRow("Issued Date", _formatDateTime(timestamp)),
                  if (paymentDate != null)
                    _buildDetailRow(
                      "Payment Date",
                      _formatDateTime(paymentDate),
                    ),
                  _buildDetailRow("Type", type),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Poppins',
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Poppins',
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "No Fines Issued",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Fines you issue will appear here",
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Your Police ID: $_officerId",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadFines, child: const Text("Refresh")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          'Fine History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFines,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Search by vehicle, license, reason...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Status Filter
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ["All", "Pending", "Paid", "Overdue"].map((
                            status,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: _filterStatus == status,
                                onSelected: (selected) {
                                  setState(() {
                                    _filterStatus = selected ? status : "All";
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.blue[100],
                                labelStyle: TextStyle(
                                  color: _filterStatus == status
                                      ? Colors.blue[800]
                                      : Colors.grey[700],
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results count and officer info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        "Total Fines: ${_filteredFines.length}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "ID: $_officerId",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Fines List
                Expanded(
                  child: _filteredFines.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadFines,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredFines.length,
                            itemBuilder: (context, index) {
                              return _buildFineCard(_filteredFines[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
