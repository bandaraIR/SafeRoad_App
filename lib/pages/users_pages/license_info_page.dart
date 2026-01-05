import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:saferoad/services/license_service.dart';

class LicenseInfoPage extends StatelessWidget {
  const LicenseInfoPage({super.key});

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final licenseService = LicenseService();

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(color: Colors.white),
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
          "License Information",
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: licenseService.licenseStatusStream(currentUser.email!),
        builder: (context, snapshot) {
          // Debug output
          if (snapshot.hasData) {
            print('=== LICENSE INFO PAGE DEBUG ===');
            print('Has licenseData: ${snapshot.data!['licenseData'] != null}');
            if (snapshot.data!['licenseData'] != null) {
              print(
                'LicenseData keys: ${snapshot.data!['licenseData'].keys.toList()}',
              );
              print(
                'licenseClass: ${snapshot.data!['licenseData']['licenseClass']}',
              );
              print('issueDate: ${snapshot.data!['licenseData']['issueDate']}');
            }
            print('==============================');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No license data found'));
          }

          final data = snapshot.data!;
          final userData = data['userData'] ?? {};
          final licenseData = data['licenseData'] ?? {};
          final licenseStatus = data['status'] ?? 'active';
          final licenseNumber = data['licenseNumber'] ?? '';

          // Extract license information from licenseData (licenses collection)
          final licenseClass = licenseData['licenseClass'] ?? 'B';
          final issueDate = _parseFirestoreDate(licenseData['createdAt']);

          // Extract user information from userData (users collection)
          final fullName = userData['name'] ?? 'N/A';
          final idNumber = userData['idNumber'] ?? 'N/A';
          final address = userData['address'] ?? 'N/A';
          final bloodGroup = userData['bloodGroup'] ?? 'N/A';
          final restrictions = userData['restrictions'] ?? 'None';
          final issuedAuthority =
              userData['issuedAuthority'] ?? 'Traffic Department';
          final expiryDate = _parseFirestoreDate(userData['expiryDate']);
          final dateOfBirth = _parseFirestoreDate(userData['dateOfBirth']);

          final isActive = licenseStatus == 'active';
          final statusColor = isActive ? Colors.green : Colors.red;
          final statusText = isActive ? 'ACTIVE' : 'DEACTIVATED';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // License Status Card
                _buildStatusCard(
                  statusText,
                  statusColor,
                  licenseNumber,
                  fullName,
                  expiryDate,
                ),
                const SizedBox(height: 20),

                // Personal Information
                _buildInfoSection(
                  "Personal Information",
                  Icons.person_outline,
                  [
                    _buildInfoRow("Full Name", fullName),
                    _buildInfoRow("ID Number", idNumber),
                    _buildInfoRow("Date of Birth", _formatDate(dateOfBirth)),
                    _buildInfoRow("Blood Group", bloodGroup),
                    _buildInfoRow("Address", address),
                  ],
                ),
                const SizedBox(height: 20),

                // License Details
                _buildInfoSection("License Details", Icons.card_membership, [
                  _buildInfoRow("License Number", licenseNumber),
                  _buildInfoRow("License Class", licenseClass),
                  _buildInfoRow("Issue Date", _formatDate(issueDate)),
                  _buildInfoRow("Expiry Date", _formatDate(expiryDate)),
                  _buildInfoRow("Issued Authority", issuedAuthority),
                  _buildInfoRow("Restrictions", restrictions),
                ]),
                const SizedBox(height: 20),

                // License Conditions
                _buildConditionsSection(isActive),
                const SizedBox(height: 20),

                // Quick Actions
                _buildQuickActions(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    String status,
    Color statusColor,
    String licenseNumber,
    String fullName,
    DateTime? expiryDate,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[300]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                licenseNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Expires on ${_formatDate(expiryDate)}",
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Poppins',
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _calculateExpiryProgress(expiryDate),
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              _calculateExpiryProgress(expiryDate) > 0.2
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getExpiryMessage(expiryDate),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Poppins',
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateExpiryProgress(DateTime? expiryDate) {
    if (expiryDate == null) return 0.0;
    final now = DateTime.now();
    final issueDate = expiryDate.subtract(const Duration(days: 365 * 5));
    final totalDays = expiryDate.difference(issueDate).inDays;
    final daysPassed = now.difference(issueDate).inDays;
    return (daysPassed / totalDays).clamp(0.0, 1.0);
  }

  String _getExpiryMessage(DateTime? expiryDate) {
    if (expiryDate == null) return 'Validity information not available';

    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;

    if (daysUntilExpiry < 0) {
      return 'License has expired';
    } else if (daysUntilExpiry <= 30) {
      return 'Expires in $daysUntilExpiry days - Renew soon!';
    } else if (daysUntilExpiry <= 90) {
      return 'Expires in $daysUntilExpiry days';
    } else {
      return 'Valid for ${daysUntilExpiry ~/ 30} months';
    }
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsSection(bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                "License Conditions",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConditionItem(
            Icons.check_circle,
            "Valid for personal use only",
            Colors.green,
          ),
          _buildConditionItem(
            Icons.check_circle,
            "Must carry license while driving",
            Colors.green,
          ),
          _buildConditionItem(
            Icons.check_circle,
            "Subject to traffic regulations",
            Colors.green,
          ),
          _buildConditionItem(
            isActive ? Icons.check_circle : Icons.error,
            isActive ? "No outstanding fines" : "Outstanding fines detected",
            isActive ? Colors.green : Colors.red,
          ),
          _buildConditionItem(
            Icons.info,
            "Renew 30 days before expiry",
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildConditionItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(Icons.print, "Print Copy", Colors.blue, () {
                _showComingSoon(context);
              }),
              _buildActionButton(Icons.download, "Download", Colors.green, () {
                _showComingSoon(context);
              }),
              _buildActionButton(
                Icons.contact_support,
                "Support",
                Colors.orange,
                () {
                  _showComingSoon(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
