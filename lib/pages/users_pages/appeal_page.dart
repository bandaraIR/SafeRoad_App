import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AppealPage extends StatefulWidget {
  final String fineId;
  final String licenseNumber;
  final Map<String, dynamic>? fineData;

  const AppealPage({
    super.key,
    required this.fineId,
    required this.licenseNumber,
    this.fineData,
  });

  @override
  State<AppealPage> createState() => _AppealPageState();
}

class _AppealPageState extends State<AppealPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _fineDocId;
  String? _fineOwnerId;

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoading = true;
  Map<String, dynamic> _fineDetails = {};

  @override
  void initState() {
    super.initState();
    _loadFineDetails();
  }

  Future<void> _loadFineDetails() async {
    try {
      final fineQuery = await _firestore
          .collection('fines')
          .where('fineId', isEqualTo: widget.fineId)
          .limit(1)
          .get();

      if (fineQuery.docs.isNotEmpty) {
        final doc = fineQuery.docs.first;
        _fineDetails = doc.data();
        _fineDocId = doc.id;
        _fineOwnerId = _fineDetails['userId'];

        // ✅ DEBUG OUTPUT
        print("==================== FINE DEBUG ====================");
        print("📄 Document ID: $_fineDocId");
        print("👤 User ID from fine: $_fineOwnerId");
        print("👤 Current user UID: ${_auth.currentUser?.uid}");
        print("📧 Current user email: ${_auth.currentUser?.email}");
        print("📋 Full fine data: $_fineDetails");
        print("===================================================");
      } else {
        print("❌ No fine found with fineId: ${widget.fineId}");
      }

      _isLoading = false;
      setState(() {});
    } catch (e) {
      print("❌ ERROR loading fine details: $e");
      _isLoading = false;
      setState(() {});
    }
  }

  Future<void> _submitAppeal() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isSubmitting = true;
      });

      final user = _auth.currentUser;
      if (user == null) {
        print("⚠️ ERROR: User not logged in");
        _showErrorDialog("You must be logged in to submit an appeal");
        return;
      }
      if (_fineDocId == null) {
        _showErrorDialog("Fine document not found. Please try again.");
        return;
      }

      // ✅ USE CURRENT USER'S UID INSTEAD OF _fineOwnerId
      final appealData = {
        'fineId': widget.fineId,
        'fineDocId': _fineDocId,
        'licenseNumber': widget.licenseNumber,
        'userId': user.uid, // ✅ CHANGED: Use current user's UID
        'userEmail': user.email,
        'appealReason': _reasonController.text.trim(),
        'appealDescription': _descriptionController.text.trim(),
        'appealDate': DateTime.now().toIso8601String(),
        'appealStatus': 'pending',
        'fineAmount': _fineDetails['amount'] ?? 0.0,
        'fineReason': _fineDetails['reason'] ?? 'Unknown',
        'vehicleNumber': _fineDetails['vehicleNumber'] ?? 'Unknown',
        'dateIssued': _fineDetails['dateIssued'] ?? '',
        'policeId': _fineDetails['policeId'] ?? 'Unknown',
        'reviewedBy': null,
        'reviewDate': null,
        'reviewNotes': null,
      };

      print("📝 Submitting appeal data: $appealData");

      // ✅ USE BATCH WRITE FOR ATOMIC OPERATION
      final batch = _firestore.batch();

      // 1️⃣ Add to appeals collection
      final appealRef = _firestore.collection('appeals').doc();
      batch.set(appealRef, appealData);

      // 2️⃣ Update fine document
      final fineRef = _firestore.collection('fines').doc(_fineDocId);
      batch.update(fineRef, {
        'hasAppeal': true,
        'appealStatus': 'pending',
        'appealId': appealRef.id,
      });

      // 🔥 COMMIT BOTH OPERATIONS TOGETHER
      await batch.commit();

      print("✅ Appeal submitted and fine updated successfully");

      _showSuccessDialog();
    } catch (e, stackTrace) {
      print("❌ ERROR submitting appeal: $e");
      print("Stack trace: $stackTrace");
      _showErrorDialog("Failed to submit appeal: ${e.toString()}");
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Appeal Submitted',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your appeal has been submitted successfully. '
          'You will be notified once it\'s reviewed.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 15),
        ),
        actions: [
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to fines page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Error',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      print("⚠️ Date format error: $e");
      return dateString;
    }
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
          'Appeal Fine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Loading Fine Details...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fine Details Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 24 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade700,
                                        Colors.blue.shade500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Fine Details',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRow(
                              label: 'Fine ID:',
                              value: widget.fineId,
                              isBold: true,
                              color: Colors.blue.shade800,
                            ),
                            _buildDetailRow(
                              label: 'Amount:',
                              value:
                                  'LKR ${(_fineDetails['amount'] ?? 0.0).toStringAsFixed(2)}',
                            ),
                            _buildDetailRow(
                              label: 'Reason:',
                              value: _fineDetails['reason'] ?? 'Unknown',
                            ),
                            _buildDetailRow(
                              label: 'Vehicle:',
                              value: _fineDetails['vehicleNumber'] ?? 'Unknown',
                            ),
                            _buildDetailRow(
                              label: 'Date Issued:',
                              value: _formatDate(
                                _fineDetails['dateIssued'] ?? '',
                              ),
                            ),
                            _buildDetailRow(
                              label: 'Location:',
                              value: _fineDetails['location'] ?? 'Unknown',
                            ),
                            _buildDetailRow(
                              label: 'Police ID:',
                              value: _fineDetails['policeId'] ?? 'Unknown',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Appeal Form Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 24 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade700,
                                        Colors.blue.shade500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.edit_document,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Appeal Information',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please provide detailed information about why you are appealing this fine.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Appeal Reason
                            Text(
                              'Appeal Reason',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reasonController,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'e.g., Wrong vehicle identification, Emergency situation',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade600,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade600,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.flag_outlined,
                                  color: Colors.blue.shade700,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter appeal reason';
                                }
                                if (value.trim().length < 10) {
                                  return 'Please provide a more detailed reason (min 10 characters)';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // Detailed Description
                            Text(
                              'Detailed Description',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Provide detailed explanation and any evidence you have...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade600,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade600,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.description_outlined,
                                  color: Colors.blue.shade700,
                                ),
                                alignLabelWithHint: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              maxLines: 6,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter detailed description';
                                }
                                if (value.trim().length < 30) {
                                  return 'Please provide more details (min 30 characters)';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 30),

                            // Note about appeal process
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.blue.shade50.withOpacity(0.5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.info_outline,
                                          color: Colors.blue.shade700,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Important Information',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoItem(
                                    '• Appeals are typically reviewed within 7-14 business days',
                                  ),
                                  _buildInfoItem(
                                    '• You will be notified via email about the decision',
                                  ),
                                  _buildInfoItem(
                                    '• Provide as much evidence as possible to support your appeal',
                                  ),
                                  _buildInfoItem(
                                    '• False appeals may result in additional penalties',
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Submit Button
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSubmitting
                                      ? [
                                          Colors.grey.shade400,
                                          Colors.grey.shade400,
                                        ]
                                      : [
                                          Colors.blue.shade700,
                                          Colors.blue.shade500,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isSubmitting
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.blue.shade300,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitAppeal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Submit Appeal',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'Poppins',
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Cancel Button
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
          fontFamily: 'Poppins',
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Poppins',
                fontSize: 14,
                color: color ?? Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
