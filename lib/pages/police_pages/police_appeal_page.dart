import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PoliceAppealPage extends StatefulWidget {
  const PoliceAppealPage({super.key});

  @override
  State<PoliceAppealPage> createState() => _PoliceAppealPageState();
}

class _PoliceAppealPageState extends State<PoliceAppealPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> appeals = [];
  List<Map<String, dynamic>> filteredAppeals = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String? policeId;
  String selectedFilter = 'all';
  String searchQuery = '';

  final List<String> filterOptions = ['all', 'pending', 'approved', 'rejected'];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPoliceProfileAndAppeals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPoliceProfileAndAppeals() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          hasError = true;
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      // Get police profile
      final policeDoc = await _firestore
          .collection('police')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (policeDoc.docs.isEmpty) {
        setState(() {
          hasError = true;
          errorMessage = 'Police profile not found';
          isLoading = false;
        });
        return;
      }

      policeId = policeDoc.docs.first['policeId'] ?? policeDoc.docs.first.id;

      // Load appeals
      final appealsQuery = await _firestore
          .collection('appeals')
          .orderBy('appealDate', descending: true)
          .get();

      // Load appeals data
      final loadedAppeals = appealsQuery.docs.map((doc) {
        final data = doc.data();
        return {'appealId': doc.id, ...data};
      }).toList();

      // Sort by timestamp (newest first)
      loadedAppeals.sort((a, b) {
        final timeA = a['timestamp']?.toDate() ?? DateTime.now();
        final timeB = b['timestamp']?.toDate() ?? DateTime.now();
        return timeB.compareTo(timeA); // Descending order
      });

      setState(() {
        appeals = loadedAppeals;
        filteredAppeals = loadedAppeals;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading appeals: $e");
      setState(() {
        hasError = true;
        errorMessage = 'Failed to load appeals: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _filterAppeals() {
    List<Map<String, dynamic>> result = appeals;

    // Apply status filter
    if (selectedFilter != 'all') {
      result = result.where((appeal) {
        final status =
            appeal['appealStatus']?.toString().toLowerCase() ?? 'pending';
        return status == selectedFilter.toLowerCase();
      }).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      result = result.where((appeal) {
        final fineId = appeal['fineId']?.toString().toLowerCase() ?? '';
        final licenseNumber =
            appeal['licenseNumber']?.toString().toLowerCase() ?? '';
        final vehicleNumber =
            appeal['vehicleNumber']?.toString().toLowerCase() ?? '';
        final reason = appeal['fineReason']?.toString().toLowerCase() ?? '';
        final driverName = appeal['driverName']?.toString().toLowerCase() ?? '';
        final location = appeal['location']?.toString().toLowerCase() ?? '';

        return fineId.contains(searchQuery.toLowerCase()) ||
            licenseNumber.contains(searchQuery.toLowerCase()) ||
            vehicleNumber.contains(searchQuery.toLowerCase()) ||
            reason.contains(searchQuery.toLowerCase()) ||
            driverName.contains(searchQuery.toLowerCase()) ||
            location.contains(searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredAppeals = result;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
      _filterAppeals();
    });
  }

  Future<void> _updateAppealStatus(
    String appealId,
    String fineDocId,
    String newStatus,
    String? notes,
  ) async {
    try {
      final batch = _firestore.batch();

      // Update appeal document
      final appealRef = _firestore.collection('appeals').doc(appealId);
      batch.update(appealRef, {
        'appealStatus': newStatus,
        'reviewedBy': policeId,
        'reviewDate': FieldValue.serverTimestamp(),
        if (notes != null && notes.isNotEmpty) 'reviewNotes': notes,
      });

      // Update fine document using REAL Firestore Doc ID
      final fineRef = _firestore.collection('fines').doc(fineDocId);
      batch.update(fineRef, {
        'appealStatus': newStatus,
        if (newStatus == 'approved') 'status': 'Waived',
      });

      await batch.commit();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Appeal $newStatus successfully')));

      _loadPoliceProfileAndAppeals();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update appeal: $e')));
    }
  }

  void _showAppealDetails(BuildContext context, Map<String, dynamic> appeal) {
    final fineId = appeal['fineId'] ?? 'N/A';
    final licenseNumber = appeal['licenseNumber'] ?? 'N/A';
    final vehicleNumber = appeal['vehicleNumber'] ?? 'N/A';
    final appealReason = appeal['appealReason'] ?? 'N/A';
    final appealDescription = appeal['appealDescription'] ?? 'N/A';
    final appealStatus = appeal['appealStatus'] ?? 'pending';
    final type = appeal['type'] ?? 'Manual';
    final policeIssuedId = appeal['policeId'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.gavel, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Text('Appeal Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Appeal Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getAppealStatusColor(appealStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getAppealStatusColor(appealStatus).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _getStatusShortName(appealStatus),
                  style: TextStyle(
                    color: _getAppealStatusColor(appealStatus),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fine Information
              _buildDetailRow('Fine ID', fineId),
              _buildDetailRow('License Number', licenseNumber),
              _buildDetailRow('Vehicle Number', vehicleNumber),
              _buildDetailRow('appealReason', appealReason),
              _buildDetailRow('appealDescription', appealDescription),
              _buildDetailRow('Type', type),
              _buildDetailRow('Issued Police ID', policeIssuedId),

              // Notes section (if any)
              if (appeal['appealNotes'] != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Review Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(appeal['appealNotes']),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (appealStatus.toLowerCase() == 'pending')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showReviewDialog(
                  context,
                  appeal['appealId'],
                  appeal['fineDocId'],
                );
              },
              child: const Text('Review'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, String appealId, String fineId) {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Review Appeal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select decision and add notes (optional):',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Decision options
                  Column(
                    children: [
                      _buildDecisionOption(
                        'Approve',
                        'Approve this appeal and waive the fine',
                        Colors.green,
                        context,
                        () {
                          _updateAppealStatus(
                            appealId,
                            fineId,
                            'approved',
                            notesController.text,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDecisionOption(
                        'Reject',
                        'Reject this appeal and maintain the fine',
                        Colors.red,
                        context,
                        () {
                          _updateAppealStatus(
                            appealId,
                            fineId,
                            'rejected',
                            notesController.text,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Notes field
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Review Notes',
                      hintText: 'Add notes about your decision...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDecisionOption(
    String title,
    String description,
    Color color,
    BuildContext context,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              title == 'Approve' ? Icons.check_circle : Icons.cancel,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAppealStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getAppealStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade800;
      case 'rejected':
        return Colors.red.shade800;
      case 'pending':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildAppealCard(Map<String, dynamic> appeal, bool isDesktop) {
    final fineId = appeal['fineId'] ?? 'N/A';
    final licenseNumber = appeal['licenseNumber'] ?? 'N/A';
    final vehicleNumber = appeal['vehicleNumber'] ?? 'N/A';
    final fineAmount = appeal['fineAmount'] ?? 0.0;
    final fineReason = appeal['fineReason'] ?? 'N/A';
    final appealStatus = appeal['appealStatus'] ?? 'pending';
    final timestamp = appeal['timestamp']?.toDate();

    return Container(
      margin: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getAppealStatusColor(appealStatus).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with status and amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getAppealStatusColor(
                        appealStatus,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getAppealStatusColor(
                          appealStatus,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getStatusShortName(appealStatus),
                      style: TextStyle(
                        color: _getAppealStatusColor(appealStatus),
                        fontWeight: FontWeight.w700,
                        fontSize: isDesktop ? 12 : 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text(
                  'LKR ${fineAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 16 : 12),

            // Fine information
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fineReason,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Fine ID: $fineId',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.badge, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 6),
                    Text(
                      'License: $licenseNumber',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Vehicle: $vehicleNumber',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if (timestamp != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Submitted: ${DateFormat('MMM dd, HH:mm').format(timestamp)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            SizedBox(height: isDesktop ? 16 : 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showAppealDetails(context, appeal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isDesktop ? 16 : 12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, size: isDesktop ? 18 : 16),
                        SizedBox(width: 8),
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isDesktop ? 14 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (appealStatus.toLowerCase() == 'pending') ...[
                  SizedBox(width: isDesktop ? 12 : 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.orange.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(
                        context,
                        appeal['appealId'],
                        appeal['fineDocId'],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 16,
                          vertical: isDesktop ? 16 : 12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            color: Colors.white,
                            size: isDesktop ? 18 : 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: isDesktop ? 14 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

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
          "Appeal Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
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
            onPressed: _loadPoliceProfileAndAppeals,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : hasError
          ? _buildErrorScreen()
          : _buildAppealsList(isDesktop),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade700,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.gavel,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading Appeals...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
            const SizedBox(height: 20),
            Text(
              "Unable to Load Appeals",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade300,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loadPoliceProfileAndAppeals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Try Again",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppealsList(bool isDesktop) {
    return Column(
      children: [
        // Filter and Search Bar Container
        Container(
          margin: EdgeInsets.all(isDesktop ? 20 : 16),
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Filter & Search Appeals',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: isDesktop ? 16 : 12),

              // Status Filter Dropdown and Search field in a Row
              Row(
                children: [
                  // Status Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFilter,
                          isExpanded: true,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                              size: isDesktop ? 24 : 20,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          items: filterOptions.map((String value) {
                            IconData icon;
                            Color color;

                            switch (value) {
                              case 'all':
                                icon = Icons.list;
                                color = Colors.blue;
                                break;
                              case 'pending':
                                icon = Icons.access_time;
                                color = Colors.orange;
                                break;
                              case 'approved':
                                icon = Icons.check_circle;
                                color = Colors.green;
                                break;
                              case 'rejected':
                                icon = Icons.cancel;
                                color = Colors.red;
                                break;
                              default:
                                icon = Icons.category;
                                color = Colors.grey;
                            }

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      icon,
                                      color: color,
                                      size: isDesktop ? 20 : 18,
                                    ),
                                    SizedBox(width: isDesktop ? 12 : 8),
                                    Text(
                                      _getFilterShortName(value),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                        fontSize: isDesktop ? 14 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedFilter = newValue!;
                              _filterAppeals();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 16 : 12),

                  // Search field
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                  _filterAppeals();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search appeals...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: isDesktop ? 14 : 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey.shade600,
                                  size: isDesktop ? 24 : 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 16 : 12,
                                  vertical: isDesktop ? 18 : 14,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isDesktop ? 14 : 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: IconButton(
                                onPressed: _clearSearch,
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                  size: isDesktop ? 20 : 18,
                                ),
                                splashRadius: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Search tips
              Padding(
                padding: EdgeInsets.only(top: isDesktop ? 12 : 8),
                child: Text(
                  'Search by: Fine ID, License, Vehicle, Reason, Driver, Location',
                  style: TextStyle(
                    fontSize: isDesktop ? 11 : 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Results count
        Padding(
          padding: EdgeInsets.only(
            left: isDesktop ? 20 : 16,
            right: isDesktop ? 20 : 16,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : 12,
                  vertical: isDesktop ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: Colors.blue.shade700,
                      size: isDesktop ? 16 : 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${filteredAppeals.length} appeal${filteredAppeals.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedFilter != 'all')
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 12 : 10,
                    vertical: isDesktop ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getAppealStatusColor(
                      selectedFilter,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getAppealStatusColor(
                        selectedFilter,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFilterIcon(selectedFilter),
                        color: _getAppealStatusColor(selectedFilter),
                        size: isDesktop ? 16 : 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _getFilterShortName(selectedFilter),
                        style: TextStyle(
                          color: _getAppealStatusColor(selectedFilter),
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Appeals List
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16),
            child: RefreshIndicator(
              onRefresh: _loadPoliceProfileAndAppeals,
              color: Colors.blue.shade700,
              backgroundColor: Colors.white,
              child: filteredAppeals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            color: Colors.grey.shade400,
                            size: 80,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isEmpty
                                ? 'No appeals found'
                                : 'No appeals match your search',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isEmpty
                                ? 'There are no appeals in the selected category'
                                : 'Try different search terms or clear filters',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          if (selectedFilter != 'all' || searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedFilter = 'all';
                                    _searchController.clear();
                                    searchQuery = '';
                                    _filterAppeals();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Clear All Filters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredAppeals.length,
                      itemBuilder: (context, index) {
                        return _buildAppealCard(
                          filteredAppeals[index],
                          isDesktop,
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'all':
        return Icons.list;
      case 'pending':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.category;
    }
  }

  String _getFilterShortName(String filter) {
    switch (filter) {
      case 'all':
        return 'ALL';
      case 'pending':
        return 'PEND';
      case 'approved':
        return 'APPV';
      case 'rejected':
        return 'REJ';
      default:
        return filter.toUpperCase();
    }
  }

  String _getStatusShortName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }
}
