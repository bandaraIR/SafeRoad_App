import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PlaceFinePage extends StatefulWidget {
  const PlaceFinePage({super.key});

  @override
  State<PlaceFinePage> createState() => _PlaceFinePageState();
}

class _PlaceFinePageState extends State<PlaceFinePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController licenseController = TextEditingController();
  final TextEditingController vehicleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  DateTime? selectedDueDate;
  String policeId = "N/A";
  bool isLoading = false;

  // Dropdown values for reason with predefined amounts
  String? selectedReason;
  final Map<String, double> fineAmounts = {
    'Speeding': 2500.0,
    'Red Light Violation': 3000.0,
    'Illegal Parking': 1500.0,
    'No Helmet': 1000.0,
    'Seat Belt Violation': 1500.0,
    'Driving Without License': 5000.0,
    'Drunk Driving': 10000.0,
    'Wrong Way Driving': 3500.0,
    'Overloading': 4000.0,
    'Vehicle Modification': 6000.0,
    'No Insurance': 7500.0,
    'Expired Documents': 2000.0,
    'Mobile Phone Usage': 2500.0,
    'Other Violation': 2000.0,
  };

  List<String> get reasonOptions => fineAmounts.keys.toList();

  @override
  void initState() {
    super.initState();
    _loadPoliceId();
  }

  Future<void> _loadPoliceId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('police')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          policeId = querySnapshot.docs.first['policeId'] ?? "Unknown";
        });
      }
    } catch (e) {
      debugPrint("Error loading police ID: $e");
    }
  }

  // Generate sequential fine ID
  Future<String> _generateFineId() async {
    try {
      // Reference to a counter document
      final counterRef = FirebaseFirestore.instance
          .collection('counters')
          .doc('fines');

      // Use transaction to ensure atomic increment
      return await FirebaseFirestore.instance.runTransaction<String>((
        transaction,
      ) async {
        // Get the current counter
        final counterDoc = await transaction.get(counterRef);
        int currentCount = 1;

        if (counterDoc.exists && counterDoc.data() != null) {
          currentCount = (counterDoc.data()!['count'] ?? 0) + 1;
        }

        // Update the counter
        transaction.set(counterRef, {'count': currentCount});

        // Generate fine ID with leading zeros (0001, 0002, etc.)
        return currentCount.toString().padLeft(4, '0');
      });
    } catch (e) {
      debugPrint("Error generating fine ID: $e");
      // Fallback: use timestamp if counter fails
      return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    }
  }

  // Called when license number changes to auto-fill user email
  Future<void> _fetchUserEmail() async {
    final licenseNumber = licenseController.text.trim();
    if (licenseNumber.isEmpty) return;

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('licenseNumber', isEqualTo: licenseNumber)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userEmail = userQuery.docs.first['email'] ?? "";
        setState(() {
          emailController.text = userEmail;
        });
      } else {
        setState(() {
          emailController.clear();
        });
      }
    } catch (e) {
      debugPrint("Error fetching user email: $e");
    }
  }

  // Auto-fill amount when reason is selected
  void _autoFillAmount(String? reason) {
    if (reason != null && fineAmounts.containsKey(reason)) {
      final amount = fineAmounts[reason]!;
      amountController.text = amount.toStringAsFixed(0);
    } else {
      amountController.clear();
    }
  }

  Future<void> _placeFine() async {
    // Safe form validation
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all fields properly."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a due date."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (selectedReason == null || selectedReason!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a reason for the fine."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (policeId == "N/A" || policeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Police ID not found. Please try again."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final licenseNumber = licenseController.text.trim();
    final vehicleNumber = vehicleController.text.trim();
    final reason = selectedReason!;
    final amountText = amountController.text.trim();
    final location = locationController.text.trim();

    if (licenseNumber.isEmpty ||
        vehicleNumber.isEmpty ||
        amountText.isEmpty ||
        location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all required fields."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid amount greater than 0."),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final userEmail = emailController.text.trim();
    if (userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "User email not found. Please check the license number.",
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ Check license exists
      final licenseDoc = await FirebaseFirestore.instance
          .collection('licenses')
          .doc(licenseNumber)
          .get();

      if (!licenseDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Invalid license number!"),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 2️⃣ Check user exists
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('licenseNumber', isEqualTo: licenseNumber)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No user found for this license number!"),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // 3️⃣ Generate sequential fine ID
      final fineId = await _generateFineId();

      // 🔹 Get the REAL Firebase Auth UID of the user
      final userDoc = userQuery.docs.first;
      final String userId = userDoc.id;

      // 4️⃣ Save fine
      final finesRef = FirebaseFirestore.instance.collection('fines');
      final dueDate = selectedDueDate!;
      await finesRef.add({
        'fineId': fineId, // Store the sequential fine ID
        'userId': userId,
        'licenseNumber': licenseNumber,
        'vehicleNumber': vehicleNumber,
        'reason': reason,
        'amount': amount,
        'dueDate': DateFormat('yyyy-MM-dd').format(dueDate),
        'dateIssued': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'email': userEmail,
        'policeId': policeId,
        'status': 'Pending',
        'location': location,
        'type': 'Manual',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 5️⃣ Create notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'email': userEmail,
        'title': 'New Fine Issued',
        'message':
            'You have received a fine for $reason (LKR ${amount.toStringAsFixed(2)}). Fine ID: $fineId',
        'fineId': fineId, // Include fine ID in notification
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fine placed successfully! Fine ID: $fineId"),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Reset form
      _resetForm();
    } catch (e) {
      debugPrint("Error placing fine: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _resetForm() {
    licenseController.clear();
    vehicleController.clear();
    amountController.clear();
    emailController.clear();
    locationController.clear();
    setState(() {
      selectedDueDate = null;
      selectedReason = null;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final isTablet = MediaQuery.of(context).size.width > 400;

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
          "Issue Fine",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
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
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 600 : double.infinity,
                ),
                child: Column(
                  children: [
                    // Header Card
                    _buildHeaderCard(isDesktop),
                    SizedBox(height: isDesktop ? 32 : 24),

                    // Form Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(isDesktop ? 32 : 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: licenseController,
                              label: "License Number",
                              icon: Icons.badge_outlined,
                              onChanged: (_) => _fetchUserEmail(),
                              isDesktop: isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24 : 20),
                            _buildTextField(
                              controller: vehicleController,
                              label: "Vehicle Number",
                              icon: Icons.directions_car_outlined,
                              isDesktop: isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24 : 20),
                            _buildTextField(
                              controller: locationController,
                              label: "Fine Location",
                              icon: Icons.location_on_outlined,
                              isDesktop: isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24 : 20),

                            // Reason Dropdown
                            _buildReasonDropdown(isDesktop),

                            SizedBox(height: isDesktop ? 24 : 20),

                            // Amount field with auto-fill indicator
                            Stack(
                              children: [
                                _buildTextField(
                                  controller: amountController,
                                  label: "Amount (LKR)",
                                  icon: Icons.currency_rupee_outlined,
                                  keyboardType: TextInputType.number,
                                  isDesktop: isDesktop,
                                ),
                                if (selectedReason != null &&
                                    fineAmounts.containsKey(selectedReason))
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome,
                                            size: 14,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Auto-filled",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'Poppins',
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 24 : 20),
                            _buildTextField(
                              controller: emailController,
                              label: "User Email",
                              icon: Icons.email_outlined,
                              enabled: true,
                              isDesktop: isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 24 : 20),
                            _buildDatePicker(context, isDesktop),
                            SizedBox(height: isDesktop ? 36 : 30),

                            // Submit Button
                            Container(
                              width: double.infinity,
                              height: isDesktop ? 64 : 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade500,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade300,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _placeFine,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      color: Colors.white,
                                      size: isDesktop ? 24 : 22,
                                    ),
                                    SizedBox(width: isDesktop ? 16 : 12),
                                    Text(
                                      "Issue Fine",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w700,
                                        fontSize: isDesktop ? 18 : 16,
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
                  ],
                ),
              ),
            ),
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
                    Icons.gavel_outlined,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Processing Fine...",
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please wait while we issue the fine",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100, width: 1),
      ),
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.gavel_rounded,
              color: Colors.blue.shade800,
              size: isDesktop ? 32 : 28,
            ),
          ),
          SizedBox(width: isDesktop ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Issue Traffic Fine",
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Fill in the details below to issue a fine",
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    fontFamily: 'Poppins',
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    Function(String)? onChanged,
    required bool isDesktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          color: enabled ? Colors.grey.shade800 : Colors.grey.shade500,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: isDesktop ? 16 : 14,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade700,
              size: isDesktop ? 22 : 20,
            ),
          ),
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: isDesktop ? 15 : 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isDesktop ? 20 : 16,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please enter $label";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildReasonDropdown(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedReason,
        onChanged: (String? newValue) {
          setState(() {
            selectedReason = newValue;
            _autoFillAmount(newValue);
          });
        },
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.report_problem_outlined,
              color: Colors.blue.shade700,
              size: isDesktop ? 22 : 20,
            ),
          ),
          labelText: "Reason for Fine",
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: isDesktop ? 15 : 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isDesktop ? 20 : 16,
          ),
        ),
        items: reasonOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                fontSize: isDesktop ? 16 : 14,
              ),
            ),
          );
        }).toList(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please select a reason";
          }
          return null;
        },
        icon: Icon(
          Icons.arrow_drop_down,
          color: Colors.blue.shade700,
          size: isDesktop ? 28 : 24,
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        isExpanded: true,
        menuMaxHeight: 400,
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _selectDueDate(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isDesktop ? 20 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.blue.shade700,
                  size: isDesktop ? 22 : 20,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Due Date",
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedDueDate == null
                          ? "Select Date"
                          : DateFormat(
                              'MMMM dd, yyyy',
                            ).format(selectedDueDate!),
                      style: TextStyle(
                        fontSize: isDesktop ? 17 : 16,
                        color: selectedDueDate == null
                            ? Colors.grey.shade500
                            : Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: Colors.blue.shade700,
                size: isDesktop ? 28 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    licenseController.dispose();
    vehicleController.dispose();
    amountController.dispose();
    emailController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
