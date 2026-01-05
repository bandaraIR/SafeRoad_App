import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _policeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String adminName = "Admin";
  bool _isLoading = false;
  bool _policeDataFound = false;

  @override
  void initState() {
    super.initState();
    fetchAdminName();

    _policeIdController.addListener(() {
      if (_policeIdController.text.length >= 3) {
        _fetchPoliceData(_policeIdController.text.trim());
      } else {
        _clearPoliceData();
      }
    });
  }

  @override
  void dispose() {
    _policeIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _areaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> fetchAdminName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection("admin")
            .doc(uid)
            .get();
        if (adminDoc.exists) {
          setState(() {
            adminName = adminDoc["fullName"] ?? "Admin";
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin name: $e");
    }
  }

  Future<void> _fetchPoliceData(String policeId) async {
    if (policeId.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("police")
          .where("policeId", isEqualTo: policeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var policeData =
            querySnapshot.docs.first.data() as Map<String, dynamic>;

        setState(() {
          _nameController.text = policeData['name'] ?? '';
          _emailController.text = policeData['email'] ?? '';
          _areaController.text =
              policeData['area'] ?? policeData['station'] ?? '';
          _policeDataFound = true;
        });
      } else {
        _clearPoliceData();
        setState(() => _policeDataFound = false);
      }
    } catch (e) {
      debugPrint("Error fetching police data: $e");
      _clearPoliceData();
      setState(() => _policeDataFound = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearPoliceData() {
    _nameController.clear();
    _emailController.clear();
    _areaController.clear();
    setState(() => _policeDataFound = false);
  }

  Future<void> sendReport() async {
    if (_formKey.currentState!.validate() && _policeDataFound) {
      try {
        await FirebaseFirestore.instance.collection("reports").add({
          "policeId": _policeIdController.text.trim(),
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "area": _areaController.text.trim(),
          "reason": _reasonController.text.trim(),
          "adminName": adminName,
          "date": DateFormat('yyyy-MM-dd HH:mm a').format(DateTime.now()),
          "timestamp": FieldValue.serverTimestamp(),
        });

        // ✅ Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("Report sent successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );

        // ✅ Clear fields after submit
        _formKey.currentState!.reset();
        _clearPoliceData();
        _policeIdController.clear();
        _reasonController.clear();
      } catch (e) {
        debugPrint("Error sending report: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text("Error sending report: $e"),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text("Please fill all fields and ensure police ID is valid."),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 65,
        iconTheme: const IconThemeData(color: Colors.white),
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
        title: const Text(
          "Officer Report",
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildNeumorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.search, color: Color(0xFF1565C0)),
                        SizedBox(width: 10),
                        Text(
                          "Search Officer",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _policeIdController,
                      decoration: InputDecoration(
                        hintText: "Enter Police ID...",
                        prefixIcon: const Icon(Icons.badge),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _policeDataFound
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF90CAF9),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF1565C0),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter police ID";
                        }
                        if (!_policeDataFound) {
                          return "Police ID not found";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_policeDataFound)
                _buildNeumorphicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person, color: Color(0xFF1565C0)),
                          SizedBox(width: 10),
                          Text(
                            "Officer Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildDetailItem(
                        "Name",
                        _nameController.text,
                        Icons.person_outline,
                      ),
                      _buildDetailItem(
                        "Email",
                        _emailController.text,
                        Icons.email_outlined,
                      ),
                      _buildDetailItem(
                        "Area",
                        _areaController.text,
                        Icons.location_on_outlined,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _buildNeumorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description, color: Color(0xFF1565C0)),
                        SizedBox(width: 10),
                        Text(
                          "Report Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Describe the reason for this report...",
                        hintStyle: const TextStyle(color: Colors.black45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF90CAF9), // light blue
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF1565C0), // dark blue
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a reason for the report';
                        }
                        if (value.length < 10) {
                          return 'Provide more details (min. 10 characters)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFF64B5F6),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: sendReport,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            "SEND REPORT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
