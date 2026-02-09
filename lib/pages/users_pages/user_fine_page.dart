import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:saferoad/pages/users_pages/appeal_page.dart';
import 'package:saferoad/pages/users_pages/payment_page.dart'; // Add this import for clipboard

class UserFinesPage extends StatefulWidget {
  const UserFinesPage({super.key});

  @override
  State<UserFinesPage> createState() => _UserFinesPageState();
}

class _UserFinesPageState extends State<UserFinesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> fines = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String? userLicenseNumber;

  @override
  void initState() {
    super.initState();
    _loadUserFines();
  }

  Future<void> _loadUserFines() async {
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

      // Get user's license number from users collection
      final userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) {
        setState(() {
          hasError = true;
          errorMessage = 'User profile not found';
          isLoading = false;
        });
        return;
      }

      userLicenseNumber = userDoc.docs.first['licenseNumber'];

      if (userLicenseNumber == null || userLicenseNumber!.isEmpty) {
        setState(() {
          hasError = true;
          errorMessage = 'License number not found in profile';
          isLoading = false;
        });
        return;
      }

      // Load fines for this license number - filter out paid fines
      final finesQuery = await _firestore
          .collection('fines')
          .where('licenseNumber', isEqualTo: userLicenseNumber)
          .get();

      // Filter out paid fines and sort manually by date issued (newest first)
      final loadedFines = finesQuery.docs
          .map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          })
          .where((fine) {
            // Filter out paid fines - only keep pending and overdue fines
            final status =
                fine['status']?.toString().toLowerCase() ?? 'pending';
            return status != 'paid';
          })
          .toList();

      // Sort by date issued (newest first)
      loadedFines.sort((a, b) {
        final dateA = a['dateIssued'] ?? '';
        final dateB = b['dateIssued'] ?? '';
        return dateB.compareTo(dateA); // Descending order
      });

      setState(() {
        fines = loadedFines;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading fines: $e");
      setState(() {
        hasError = true;
        errorMessage = 'Failed to load fines: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // All the UI methods remain the same as before
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

  // NEW METHOD: Get appeal status color
  Color _getAppealStatusColor(String? appealStatus) {
    if (appealStatus == null) return Colors.grey;

    switch (appealStatus.toLowerCase()) {
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

  // NEW METHOD: Get appeal status text color
  Color _getAppealStatusTextColor(String? appealStatus) {
    if (appealStatus == null) return Colors.grey.shade800;

    switch (appealStatus.toLowerCase()) {
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

  Widget _buildFineCard(Map<String, dynamic> fine, bool isDesktop) {
    final dateIssued = fine['dateIssued'] ?? 'Unknown';
    final dueDate = fine['dueDate'] ?? 'Unknown';
    final amount = fine['amount'] ?? 0.0;
    final reason = fine['reason'] ?? 'Unknown Reason';
    final vehicleNumber = fine['vehicleNumber'] ?? 'Unknown';
    final status = fine['status']?.toString() ?? 'Pending';
    final location = fine['location'] ?? 'Unknown Location';
    final policeId = fine['policeId'] ?? 'Unknown';
    final fineId = fine['fineId'] ?? 'Unknown';
    final type = fine['type'] ?? 'Manual';
    final hasAppeal = fine['hasAppeal'] ?? false;
    final appealStatus = fine['appealStatus']?.toString();

    final isOverdue = status.toLowerCase() == 'overdue';
    final isPending = status.toLowerCase() == 'pending';
    final isAppealPending = appealStatus?.toLowerCase() == 'pending';
    final isAppealApproved = appealStatus?.toLowerCase() == 'approved';
    final isAppealRejected = appealStatus?.toLowerCase() == 'rejected';

    final canAppeal = !hasAppeal && (isPending || isOverdue);
    final canPay = (isPending || isOverdue) && (!hasAppeal || isAppealRejected);

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
        border: isOverdue
            ? Border.all(color: Colors.red.shade200, width: 2)
            : null,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fine Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusTextColor(status),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: isDesktop ? 12 : 10,
                        ),
                      ),
                    ),
                    // Appeal Status Badge (if exists)
                    if (hasAppeal && appealStatus != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
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
                          'Appeal: ${appealStatus.toUpperCase()}',
                          style: TextStyle(
                            color: _getAppealStatusTextColor(appealStatus),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: isDesktop ? 10 : 8,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'LKR ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 16 : 12),

            // Reason
            Text(
              reason,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: isDesktop ? 12 : 8),

            // Details grid
            _buildDetailGrid(
              vehicleNumber: vehicleNumber,
              dateIssued: dateIssued,
              dueDate: dueDate,
              policeId: policeId,
              fineId: fineId,
              type: type,
              location: location,
              hasAppeal: hasAppeal,
              appealStatus: appealStatus,
              isDesktop: isDesktop,
            ),
            SizedBox(height: isDesktop ? 16 : 12),

            // Action buttons row
            if (canPay || canAppeal)
              Row(
                children: [
                  // PAY BUTTON
                  if (canPay)
                    Expanded(
                      child: Container(
                        height: isDesktop ? 50 : 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.blue.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            "Pay Now",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (canPay && canAppeal) SizedBox(width: isDesktop ? 12 : 8),

                  // APPEAL BUTTON
                  if (canAppeal)
                    Container(
                      height: isDesktop ? 50 : 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _appealFine(fineId),
                        icon: Icon(Icons.gavel, color: Colors.orange.shade700),
                      ),
                    ),
                ],
              ),

            // Show appeal info if appeal exists
            if (hasAppeal && appealStatus != null)
              _buildAppealInfoSection(appealStatus, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailGrid({
    required String vehicleNumber,
    required String dateIssued,
    required String dueDate,
    required String policeId,
    required String fineId,
    required String type,
    required String location,
    required bool hasAppeal,
    required String? appealStatus,
    required bool isDesktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.directions_car,
            label: 'Vehicle',
            value: vehicleNumber,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: 'Issued Date',
            value: _formatDate(dateIssued),
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildDetailRow(
            icon: Icons.event_available,
            label: 'Due Date',
            value: _formatDate(dueDate),
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildDetailRow(
            icon: Icons.badge,
            label: 'Police ID',
            value: policeId,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildDetailRow(
            icon: Icons.location_on,
            label: 'Location',
            value: location,
            isDesktop: isDesktop,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          // Fine ID row with copy icon
          _buildFineIdRow(fineId, isDesktop),
          SizedBox(height: isDesktop ? 12 : 8),
          _buildDetailRow(
            icon: Icons.category,
            label: 'Type',
            value: type,
            isDesktop: isDesktop,
          ),
          // Appeal Status row (if exists)
          if (hasAppeal && appealStatus != null) ...[
            SizedBox(height: isDesktop ? 12 : 8),
            _buildDetailRow(
              icon: Icons.gavel,
              label: 'Appeal Status',
              value: appealStatus.toUpperCase(),
              isDesktop: isDesktop,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDesktop,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: isDesktop ? 18 : 16),
        SizedBox(width: isDesktop ? 12 : 8),
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: Colors.grey.shade700,
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
              color: Colors.grey.shade800,
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ],
    );
  }

  // NEW METHOD: Build appeal info section
  Widget _buildAppealInfoSection(String appealStatus, bool isDesktop) {
    IconData appealIcon;
    Color appealColor;
    String statusText;

    switch (appealStatus.toLowerCase()) {
      case 'approved':
        appealIcon = Icons.check_circle;
        appealColor = Colors.green;
        statusText = 'Your appeal has been approved. This fine may be waived.';
        break;
      case 'rejected':
        appealIcon = Icons.cancel;
        appealColor = Colors.red;
        statusText = 'Your appeal has been rejected. Please pay the fine.';
        break;
      case 'pending':
      default:
        appealIcon = Icons.access_time;
        appealColor = Colors.orange;
        statusText =
            'Your appeal is under review. Please wait for the decision.';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appealColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appealColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(appealIcon, color: appealColor, size: isDesktop ? 20 : 18),
          SizedBox(width: isDesktop ? 12 : 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: appealColor,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 14 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFineIdRow(String fineId, bool isDesktop) {
    return Row(
      children: [
        Icon(
          Icons.credit_card,
          color: Colors.blue.shade600,
          size: isDesktop ? 18 : 16,
        ),
        SizedBox(width: isDesktop ? 12 : 8),
        Expanded(
          flex: 2,
          child: Text(
            'Fine ID:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: Colors.grey.shade700,
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fineId,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade800,
                    fontSize: isDesktop ? 14 : 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              SizedBox(width: 8),
              InkWell(
                onTap: () => _copyFineId(fineId),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Icon(
                    Icons.content_copy,
                    color: Colors.blue.shade700,
                    size: isDesktop ? 16 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String fineId, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: isDesktop ? 50 : 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: isDesktop ? 20 : 18,
                  ),
                  SizedBox(width: isDesktop ? 8 : 6),
                  Text(
                    'Pay Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 12 : 8),
        Container(
          height: isDesktop ? 50 : 44,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: IconButton(
            onPressed: () => _appealFine(fineId),
            icon: Icon(
              Icons.gavel,
              color: Colors.orange.shade700,
              size: isDesktop ? 20 : 18,
            ),
            tooltip: 'Appeal Fine',
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Copy Fine ID to clipboard
  void _copyFineId(String fineId) async {
    try {
      await Clipboard.setData(ClipboardData(text: fineId));

      // Show snackbar feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fine ID "$fineId" copied to clipboard'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy Fine ID'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _payFine(String fineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fine ID: $fineId'),
            const SizedBox(height: 8),
            const Text('Payment integration would go here.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _appealFine(String fineId) {
    if (userLicenseNumber == null || userLicenseNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('License number not found'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    // Find the specific fine data
    final fine = fines.firstWhere(
      (f) => f['fineId'] == fineId,
      orElse: () => {},
    );

    // Check if already has appeal
    if (fine['hasAppeal'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You have already submitted an appeal for this fine',
          ),
          backgroundColor: Colors.orange.shade600,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppealPage(
          fineId: fineId,
          licenseNumber: userLicenseNumber!,
          fineData: fine,
        ),
      ),
    );
  }

  double getTotalAmount() {
    return fines.fold(0.0, (sum, fine) {
      final amount = fine['amount'] ?? 0.0;
      final status = fine['status']?.toString().toLowerCase() ?? 'pending';
      if (status == 'pending' || status == 'overdue') {
        return sum + amount;
      }
      return sum;
    });
  }

  int getPendingFinesCount() {
    return fines.where((fine) {
      final status = fine['status']?.toString().toLowerCase() ?? 'pending';
      return status == 'pending' || status == 'overdue';
    }).length;
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
          "My Fines",
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserFines,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : hasError
          ? _buildErrorScreen()
          : fines.isEmpty
          ? _buildEmptyScreen()
          : _buildFinesList(isDesktop),
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
                    Icons.receipt_long,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading Fines...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
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
              "Unable to Load Fines",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
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
                onPressed: _loadUserFines,
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
                        fontFamily: 'Poppins',
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

  Widget _buildEmptyScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade400,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Outstanding Fines",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You don't have any pending traffic fines at the moment.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Keep following traffic rules!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontFamily: 'Poppins',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinesList(bool isDesktop) {
    final totalAmount = getTotalAmount();
    final pendingCount = getPendingFinesCount();

    return Column(
      children: [
        // Summary Card
        Container(
          margin: EdgeInsets.all(isDesktop ? 20 : 16),
          padding: EdgeInsets.all(isDesktop ? 24 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade300,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Outstanding",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isDesktop ? 16 : 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 8 : 6),
                    Text(
                      'LKR ${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 28 : 24,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 8 : 6),
                    Text(
                      '$pendingCount pending fine${pendingCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: 'Poppins',
                        fontSize: isDesktop ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: isDesktop ? 32 : 28,
                ),
              ),
            ],
          ),
        ),

        // Fines List
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16),
            child: RefreshIndicator(
              onRefresh: _loadUserFines,
              color: Colors.blue.shade700,
              backgroundColor: Colors.white,
              child: ListView.builder(
                itemCount: fines.length,
                itemBuilder: (context, index) {
                  return _buildFineCard(fines[index], isDesktop);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
