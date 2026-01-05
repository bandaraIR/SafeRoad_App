import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saferoad/pages/users_pages/history_page.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _fineIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _policeIdController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();

  Map<String, dynamic>? fineData;
  String? documentId;
  bool isLoading = false;
  bool fineFound = false;

  @override
  void initState() {
    super.initState();
    _fineIdController.addListener(_onFineIdChanged);
  }

  void _onFineIdChanged() {
    if (_fineIdController.text.length >= 6) {
      _fetchFineDetails();
    }
  }

  Future<void> _fetchFineDetails() async {
    final fineId = _fineIdController.text.trim();
    if (fineId.isEmpty) return;

    setState(() {
      isLoading = true;
      fineFound = false;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('fines')
          .where('fineId', isEqualTo: fineId)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();

        setState(() {
          fineData = data;
          documentId = doc.id;
          fineFound = true;
        });

        _emailController.text = data['email'] ?? '';
        _amountController.text = data['amount']?.toString() ?? '';
        _dueDateController.text = data['dueDate'] ?? '';
        _policeIdController.text = data['policeId'] ?? '';
        _licenseController.text = data['licenseNumber'] ?? '';
      } else {
        _clearFields();
        if (_fineIdController.text.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Fine ID not found")));
        }
      }
    } catch (e) {
      _clearFields();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching fine: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _clearFields() {
    setState(() {
      fineData = null;
      fineFound = false;
    });
    _emailController.clear();
    _amountController.clear();
    _dueDateController.clear();
    _policeIdController.clear();
    _licenseController.clear();
  }

  Future<void> _makePayment() async {
    if (documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No fine selected."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (fineData?['status'] == 'Paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This fine has already been paid."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('fines')
          .doc(documentId)
          .update({
            'status': 'Paid',
            'paymentDate': FieldValue.serverTimestamp(),
          });

      await _fetchFineDetails(); // refresh after update

      setState(() {
        isLoading = false;
        fineData!['status'] = 'Paid';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Payment Successful!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to History Page after a short delay
      await Future.delayed(const Duration(seconds: 2));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HistoryPage()),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Payment failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue.shade700),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: TextStyle(
          color: enabled ? Colors.black : Colors.blue.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFineDetailsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.blue.shade100, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.lightBlue.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fine Details",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: fineData?['status'] == 'Paid'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: fineData?['status'] == 'Paid'
                                    ? Colors.green.shade300
                                    : Colors.orange.shade300,
                              ),
                            ),
                            child: Text(
                              fineData?['status'] ?? 'Pending',
                              style: TextStyle(
                                color: fineData?['status'] == 'Paid'
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                _buildInputField(
                  label: "Email Address",
                  icon: Icons.email_rounded,
                  controller: _emailController,
                  enabled: false,
                ),
                _buildInputField(
                  label: "Fine Amount",
                  icon: Icons.attach_money_rounded,
                  controller: _amountController,
                  enabled: false,
                  keyboardType: TextInputType.number,
                ),
                _buildInputField(
                  label: "Due Date",
                  icon: Icons.calendar_today_rounded,
                  controller: _dueDateController,
                  enabled: false,
                ),
                _buildInputField(
                  label: "Police ID",
                  icon: Icons.badge_rounded,
                  controller: _policeIdController,
                  enabled: false,
                ),
                _buildInputField(
                  label: "License Number",
                  icon: Icons.drive_eta_rounded,
                  controller: _licenseController,
                  enabled: false,
                ),
                const SizedBox(height: 24),

                // Pay Now Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: fineData?['status'] == 'Paid'
                        ? LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade600,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.blue.shade500,
                              Colors.lightBlue.shade400,
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: fineData?['status'] == 'Paid'
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: fineData?['status'] == 'Paid'
                        ? null
                        : _makePayment,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          fineData?['status'] == 'Paid'
                              ? Icons.check_circle_rounded
                              : Icons.payment_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          fineData?['status'] == 'Paid'
                              ? 'Payment Completed'
                              : 'Pay Now',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ),
    );
  }

  @override
  void dispose() {
    _fineIdController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _policeIdController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          "Fine Payment",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        "Enter Your Fine ID",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _fineIdController,
                          decoration: InputDecoration(
                            hintText: "Enter your Fine ID number...",
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isLoading)
                        LinearProgressIndicator(
                          color: Colors.blue.shade400,
                          backgroundColor: Colors.blue.shade100,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (fineFound && fineData != null) _buildFineDetailsCard(),
            if (!fineFound && !isLoading && _fineIdController.text.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "No Fine Found",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please check your Fine ID and try again",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
