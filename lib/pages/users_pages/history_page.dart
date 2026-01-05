import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> paidFines = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String? userLicenseNumber;

  @override
  void initState() {
    super.initState();
    _loadPaidFines();
  }

  Future<void> _loadPaidFines() async {
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

      // Load paid fines for this license number
      final finesQuery = await _firestore
          .collection('fines')
          .where('licenseNumber', isEqualTo: userLicenseNumber)
          .where('status', isEqualTo: 'Paid')
          .get();

      // Process fines with proper date handling
      final loadedFines = finesQuery.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      // Sort by payment date (newest first)
      loadedFines.sort((a, b) {
        final dateA = _getPaymentDate(a);
        final dateB = _getPaymentDate(b);
        return dateB.compareTo(dateA); // Descending order
      });

      setState(() {
        paidFines = loadedFines;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading paid fines: $e");
      setState(() {
        hasError = true;
        errorMessage = 'Failed to load payment history: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Helper method to get payment date as DateTime
  DateTime _getPaymentDate(Map<String, dynamic> fine) {
    try {
      // First try to get paymentDate (Timestamp)
      if (fine['paymentDate'] != null) {
        if (fine['paymentDate'] is Timestamp) {
          return (fine['paymentDate'] as Timestamp).toDate();
        } else if (fine['paymentDate'] is String) {
          return DateFormat('yyyy-MM-dd').parse(fine['paymentDate']);
        }
      }

      // Fallback to dateIssued if paymentDate is not available
      if (fine['dateIssued'] != null) {
        if (fine['dateIssued'] is Timestamp) {
          return (fine['dateIssued'] as Timestamp).toDate();
        } else if (fine['dateIssued'] is String) {
          return DateFormat('yyyy-MM-dd').parse(fine['dateIssued']);
        }
      }
    } catch (e) {
      debugPrint("Error parsing date: $e");
    }

    // Return current date as fallback
    return DateTime.now();
  }

  // Helper method to format date for display
  String _formatDateForDisplay(dynamic date) {
    try {
      if (date == null) return 'Unknown';

      if (date is Timestamp) {
        return DateFormat('MMM dd, yyyy').format(date.toDate());
      } else if (date is String) {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
        return DateFormat('MMM dd, yyyy').format(parsedDate);
      } else {
        return 'Invalid Date';
      }
    } catch (e) {
      debugPrint("Error formatting date: $e");
      return 'Unknown';
    }
  }

  // Helper method to format payment date specifically
  String _formatPaymentDate(Map<String, dynamic> fine) {
    try {
      if (fine['paymentDate'] != null) {
        return _formatDateForDisplay(fine['paymentDate']);
      }
      return 'Payment date not available';
    } catch (e) {
      return 'Date error';
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> fine, bool isDesktop) {
    final dateIssued = fine['dateIssued'] ?? 'Unknown';
    final amount = fine['amount'] ?? 0.0;
    final reason = fine['reason'] ?? 'Unknown Reason';
    final vehicleNumber = fine['vehicleNumber'] ?? 'Unknown';
    final policeId = fine['policeId'] ?? 'Unknown';
    final fineId = fine['fineId'] ?? 'Unknown';
    final type = fine['type'] ?? 'Manual';

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
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with paid status and amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade800,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'PAID',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: isDesktop ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
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
            Container(
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
                    value: _formatDateForDisplay(dateIssued),
                    isDesktop: isDesktop,
                  ),
                  SizedBox(height: isDesktop ? 12 : 8),
                  _buildDetailRow(
                    icon: Icons.payment,
                    label: 'Paid Date',
                    value: _formatPaymentDate(fine),
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
                    icon: Icons.credit_card,
                    label: 'Fine ID',
                    value: fineId,
                    isDesktop: isDesktop,
                  ),
                  SizedBox(height: isDesktop ? 12 : 8),
                  _buildDetailRow(
                    icon: Icons.category,
                    label: 'Type',
                    value: type,
                    isDesktop: isDesktop,
                  ),
                ],
              ),
            ),
          ],
        ),
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

  double getTotalPaidAmount() {
    return paidFines.fold(0.0, (sum, fine) {
      final amount = fine['amount'] ?? 0.0;
      return sum + amount;
    });
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
          "Payment History",
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
            onPressed: _loadPaidFines,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : hasError
          ? _buildErrorScreen()
          : paidFines.isEmpty
          ? _buildEmptyScreen()
          : _buildHistoryList(isDesktop),
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
                  color: Colors.green.shade100,
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
                    Icons.history,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading History...",
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
              "Unable to Load History",
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
                onPressed: _loadPaidFines,
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
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, color: Colors.blue.shade400, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              "No Payment History",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't made any payments yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pay your fines to see them here!",
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

  Widget _buildHistoryList(bool isDesktop) {
    final totalPaid = getTotalPaidAmount();

    return Column(
      children: [
        // Summary Card
        Container(
          margin: EdgeInsets.all(isDesktop ? 20 : 16),
          padding: EdgeInsets.all(isDesktop ? 24 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.green.shade400],
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
                      "Total Paid",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isDesktop ? 16 : 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 8 : 6),
                    Text(
                      'LKR ${totalPaid.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 28 : 24,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 8 : 6),
                    Text(
                      '${paidFines.length} payment${paidFines.length != 1 ? 's' : ''} completed',
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
                  Icons.history,
                  color: Colors.white,
                  size: isDesktop ? 32 : 28,
                ),
              ),
            ],
          ),
        ),

        // History List
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16),
            child: RefreshIndicator(
              onRefresh: _loadPaidFines,
              color: Colors.blue.shade700,
              backgroundColor: Colors.white,
              child: ListView.builder(
                itemCount: paidFines.length,
                itemBuilder: (context, index) {
                  return _buildHistoryCard(paidFines[index], isDesktop);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
