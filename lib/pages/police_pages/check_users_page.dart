import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:saferoad/pages/police_pages/place_fine_page.dart';

class CheckUsersPage extends StatefulWidget {
  const CheckUsersPage({super.key});

  @override
  State<CheckUsersPage> createState() => _CheckUsersPageState();
}

class _CheckUsersPageState extends State<CheckUsersPage> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  bool hasSearched = false;

  // Helper method to parse Firestore dates
  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Check if license is expired based on expiry date
  bool _isLicenseExpired(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate);
  }

  // Check if there are any overdue unpaid fines
  Future<bool> _hasOverdueUnpaidFines(String email) async {
    try {
      final finesSnapshot = await FirebaseFirestore.instance
          .collection('fines')
          .where('email', isEqualTo: email)
          .get();

      final now = DateTime.now();

      for (var fineDoc in finesSnapshot.docs) {
        final fineData = fineDoc.data() as Map<String, dynamic>;
        final dueDate = _parseFirestoreDate(fineData['dueDate']);
        final status = fineData['status']?.toString().toLowerCase() ?? '';

        // Check if fine is overdue and unpaid
        if (dueDate != null && now.isAfter(dueDate) && status != 'paid') {
          return true; // Found at least one overdue unpaid fine
        }
      }
      return false; // No overdue unpaid fines found
    } catch (e) {
      debugPrint("Error checking overdue fines: $e");
      return false;
    }
  }

  // Get actual license status considering expiry date AND overdue fines
  Future<String> _getActualLicenseStatus(Map<String, dynamic> user) async {
    final currentStatus = user['status']?.toString().toLowerCase() ?? 'active';
    final expiryDate = _parseFirestoreDate(user['expiryDate']);
    final userEmail = user['email']?.toString() ?? '';

    // If license is expired, override status to 'deactivated'
    if (_isLicenseExpired(expiryDate)) {
      return 'deactivated';
    }

    // Check for overdue unpaid fines
    if (userEmail.isNotEmpty) {
      final hasOverdueFines = await _hasOverdueUnpaidFines(userEmail);
      if (hasOverdueFines) {
        return 'deactivated';
      }
    }

    return currentStatus;
  }

  // Check if license is expiring soon (within 30 days)
  bool _isLicenseExpiringSoon(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }

  // Updated _formatDate to handle both Timestamp and DateTime
  String _formatDate(dynamic date) {
    if (date == null) return 'Not provided';

    DateTime dateTime;

    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'Invalid date';
    }

    return "${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}";
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        users = [];
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasSearched = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('idNumber', isEqualTo: query)
          .get();

      final licenseQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('licenseNumber', isEqualTo: query)
          .get();

      final allResults = [...querySnapshot.docs, ...licenseQuerySnapshot.docs];

      // Fetch license data for each user
      final List<Map<String, dynamic>> usersWithLicenseData = [];

      for (var doc in allResults) {
        final userData = {'id': doc.id, ...doc.data()};
        final licenseNumber = userData['licenseNumber'];

        if (licenseNumber != null && licenseNumber.isNotEmpty) {
          try {
            final licenseDoc = await FirebaseFirestore.instance
                .collection('licenses')
                .doc(licenseNumber)
                .get();

            if (licenseDoc.exists) {
              userData['licenseData'] = licenseDoc.data();
            }
          } catch (e) {
            debugPrint("Error fetching license data: $e");
          }
        }

        usersWithLicenseData.add(userData);
      }

      final uniqueResults = {
        for (var user in usersWithLicenseData) user['id']: user,
      }.values.toList();

      setState(() {
        users = uniqueResults.cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error searching users: $e");
      setState(() => isLoading = false);
    }
  }

  void _clearSearch() {
    searchController.clear();
    setState(() {
      users = [];
      hasSearched = false;
    });
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == 'deactivated' || lowerStatus == 'expired') {
      return Colors.red;
    }

    switch (lowerStatus) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'banned':
        return Colors.red;
      case 'expiring soon':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getUserIcon(String userType) {
    switch (userType.toLowerCase()) {
      case 'driver':
        return Icons.directions_car;
      case 'rider':
        return Icons.pedal_bike;
      case 'premium':
        return Icons.star;
      default:
        return Icons.person;
    }
  }

  // Helper method to get license class from license data
  String _getLicenseClass(Map<String, dynamic> user) {
    final licenseData = user['licenseData'];
    if (licenseData != null && licenseData['licenseClass'] != null) {
      return licenseData['licenseClass'].toString();
    }
    return 'Not available';
  }

  // Helper method to format license classes for better display
  String _formatLicenseClass(String licenseClass) {
    if (licenseClass.contains(',')) {
      final classes = licenseClass.split(',');
      return classes.map((cls) => 'Class ${cls.trim()}').join(', ');
    }
    return 'Class $licenseClass';
  }

  // Get status text with expiry AND overdue fines consideration
  Future<String> _getStatusText(Map<String, dynamic> user) async {
    final actualStatus = await _getActualLicenseStatus(user);
    final expiryDate = _parseFirestoreDate(user['expiryDate']);

    if (actualStatus == 'deactivated') {
      // Check if it's due to expiry or overdue fines
      final isExpired = _isLicenseExpired(expiryDate);
      final userEmail = user['email']?.toString() ?? '';
      final hasOverdueFines = userEmail.isNotEmpty
          ? await _hasOverdueUnpaidFines(userEmail)
          : false;

      if (isExpired) {
        return 'EXPIRED';
      } else if (hasOverdueFines) {
        return 'OVERDUE FINES';
      }
      return 'DEACTIVATED';
    } else if (_isLicenseExpiringSoon(expiryDate)) {
      return 'EXPIRING SOON';
    }

    return (user['status'] ?? 'active').toString().toUpperCase();
  }

  // Get status description for detailed view
  Future<String> _getStatusDescription(Map<String, dynamic> user) async {
    final actualStatus = await _getActualLicenseStatus(user);
    final expiryDate = _parseFirestoreDate(user['expiryDate']);
    final userEmail = user['email']?.toString() ?? '';
    final hasOverdueFines = userEmail.isNotEmpty
        ? await _hasOverdueUnpaidFines(userEmail)
        : false;

    if (actualStatus == 'deactivated') {
      if (_isLicenseExpired(expiryDate)) {
        return 'License Expired on ${_formatDate(expiryDate!)}';
      } else if (hasOverdueFines) {
        return 'License deactivated due to overdue unpaid fines';
      }
      return 'License Deactivated';
    } else if (_isLicenseExpiringSoon(expiryDate)) {
      final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
      return 'Expires in $daysLeft days';
    }

    return 'Valid License';
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizes
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingHorizontal = screenWidth * 0.04;

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
          "Check Users",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 20,
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
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: paddingHorizontal,
              vertical: 12,
            ),
            child: _buildSearchSection(screenWidth),
          ),
          Expanded(child: _buildResultsSection(screenHeight)),
        ],
      ),
    );
  }

  Widget _buildSearchSection(double screenWidth) {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: "Enter User ID or License Number...",
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[600]),
                onPressed: _clearSearch,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: 16,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        if (value.length >= 3) {
          searchUsers(value.trim());
        }
      },
      onSubmitted: (value) => searchUsers(value.trim()),
    );
  }

  Widget _buildResultsSection(double screenHeight) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          height: screenHeight * 0.2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: screenHeight * 0.08,
                height: screenHeight * 0.08,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Searching Users...",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: screenHeight * 0.08,
              color: Colors.blue[300],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              "Search for Users",
              style: TextStyle(
                fontSize: screenHeight * 0.025,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.03),
              child: Text(
                "Enter a user's ID number or license number above to view their details and records",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenHeight * 0.018,
                  fontFamily: 'Poppins',
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: screenHeight * 0.07,
              color: Colors.orange[300],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              "No Users Found",
              style: TextStyle(
                fontSize: screenHeight * 0.022,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              "Try searching with a different ID or license number",
              style: TextStyle(
                fontSize: screenHeight * 0.018,
                fontFamily: 'Poppins',
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenHeight * 0.02,
        vertical: screenHeight * 0.01,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return FutureBuilder<String>(
          future: _getStatusText(user),
          builder: (context, statusSnapshot) {
            final statusText = statusSnapshot.data ?? 'ACTIVE';
            final isDeactivated =
                statusText == 'EXPIRED' ||
                statusText == 'OVERDUE FINES' ||
                statusText == 'DEACTIVATED';

            return _buildUserCard(
              user,
              screenHeight,
              statusText,
              isDeactivated,
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    double screenHeight,
    String statusText,
    bool isDeactivated,
  ) {
    final licenseClass = _getLicenseClass(user);
    final formattedLicenseClass = _formatLicenseClass(licenseClass);
    final statusColor = _getStatusColor(statusText);

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: isDeactivated ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(screenHeight * 0.015),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDeactivated ? Colors.red[300]! : Colors.grey[200]!,
          width: isDeactivated ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.015),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: screenHeight * 0.06,
                  height: screenHeight * 0.06,
                  decoration: BoxDecoration(
                    gradient: isDeactivated
                        ? LinearGradient(
                            colors: [Colors.grey[400]!, Colors.grey[600]!],
                          )
                        : LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[600]!],
                          ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getUserIcon(user['userType'] ?? 'user'),
                    color: Colors.white,
                    size: screenHeight * 0.03,
                  ),
                ),
                SizedBox(width: screenHeight * 0.015),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: screenHeight * 0.022,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: isDeactivated
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: screenHeight * 0.004),
                      Text(
                        user['email'] ?? 'No email provided',
                        style: TextStyle(
                          fontSize: screenHeight * 0.015,
                          fontFamily: 'Poppins',
                          color: isDeactivated
                              ? Colors.grey[500]
                              : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenHeight * 0.015,
                    vertical: screenHeight * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(screenHeight * 0.02),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: screenHeight * 0.012,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),
            // User details
            Column(
              children: [
                _buildDetailRow(
                  icon: Icons.badge,
                  label: "ID Number",
                  value: user['idNumber'] ?? 'Not provided',
                  screenHeight: screenHeight,
                  isDeactivated: isDeactivated,
                ),
                SizedBox(height: screenHeight * 0.008),
                _buildDetailRow(
                  icon: Icons.directions_car,
                  label: "License Number",
                  value: user['licenseNumber'] ?? 'Not provided',
                  screenHeight: screenHeight,
                  isDeactivated: isDeactivated,
                ),
                SizedBox(height: screenHeight * 0.008),
                _buildDetailRow(
                  icon: Icons.class_,
                  label: "License Classes",
                  value: formattedLicenseClass,
                  screenHeight: screenHeight,
                  isDeactivated: isDeactivated,
                ),
                SizedBox(height: screenHeight * 0.008),
                _buildDetailRow(
                  icon: Icons.phone,
                  label: "Phone",
                  value: user['phoneNumber'] ?? 'Not provided',
                  screenHeight: screenHeight,
                  isDeactivated: isDeactivated,
                ),
                // Expiry warning for deactivated licenses
                if (isDeactivated) ...[
                  SizedBox(height: screenHeight * 0.008),
                  Container(
                    padding: EdgeInsets.all(screenHeight * 0.01),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(screenHeight * 0.008),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: screenHeight * 0.018,
                        ),
                        SizedBox(width: screenHeight * 0.008),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _getStatusDescription(user),
                            builder: (context, snapshot) {
                              final description =
                                  snapshot.data ?? 'License deactivated';
                              return Text(
                                description,
                                style: TextStyle(
                                  fontSize: screenHeight * 0.013,
                                  fontFamily: 'Poppins',
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: screenHeight * 0.012),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.remove_red_eye, size: screenHeight * 0.02),
                    label: const Text(
                      "View Details",
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    onPressed: () => _showUserDetails(user),
                  ),
                ),
                SizedBox(width: screenHeight * 0.008),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.receipt_long, size: screenHeight * 0.02),
                    label: const Text(
                      "Issue Fine",
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    onPressed: () {
                      _issueFine(user);
                    },
                    style: isDeactivated
                        ? ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[400],
                          )
                        : null,
                  ),
                ),
              ],
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
    required double screenHeight,
    bool isDeactivated = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(screenHeight * 0.008),
          decoration: BoxDecoration(
            color: isDeactivated ? Colors.grey[200] : Colors.blue[100],
            borderRadius: BorderRadius.circular(screenHeight * 0.01),
          ),
          child: Icon(
            icon,
            size: screenHeight * 0.02,
            color: isDeactivated ? Colors.grey[600] : Colors.blue[700],
          ),
        ),
        SizedBox(width: screenHeight * 0.012),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: screenHeight * 0.012,
                  fontFamily: 'Poppins',
                  color: isDeactivated ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: screenHeight * 0.002),
              Text(
                value,
                style: TextStyle(
                  fontSize: screenHeight * 0.015,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: isDeactivated ? Colors.grey[600] : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final screenHeight = MediaQuery.of(context).size.height;
    final licenseClass = _getLicenseClass(user);
    final formattedLicenseClass = _formatLicenseClass(licenseClass);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<String>(
        future: _getActualLicenseStatus(user),
        builder: (context, statusSnapshot) {
          final actualStatus = statusSnapshot.data ?? 'active';
          final isDeactivated = actualStatus == 'deactivated';

          return FutureBuilder<String>(
            future: _getStatusDescription(user),
            builder: (context, descriptionSnapshot) {
              final statusDescription =
                  descriptionSnapshot.data ?? 'Valid License';

              return Container(
                height: screenHeight * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(screenHeight * 0.02),
                      decoration: BoxDecoration(
                        gradient: isDeactivated
                            ? LinearGradient(
                                colors: [Colors.grey[600]!, Colors.grey[400]!],
                              )
                            : LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[400]!],
                              ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              _getUserIcon(user['userType'] ?? 'user'),
                              color: isDeactivated
                                  ? Colors.grey[600]
                                  : Colors.blue[700],
                            ),
                          ),
                          SizedBox(width: screenHeight * 0.015),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'] ?? 'Unknown User',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenHeight * 0.022,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user['email'] ?? 'No email',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: screenHeight * 0.015,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenHeight * 0.015,
                              vertical: screenHeight * 0.008,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                screenHeight * 0.02,
                              ),
                            ),
                            child: FutureBuilder<String>(
                              future: _getStatusText(user),
                              builder: (context, textSnapshot) {
                                final statusText =
                                    textSnapshot.data ?? 'ACTIVE';
                                return Text(
                                  statusText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenHeight * 0.012,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(screenHeight * 0.02),
                        child: ListView(
                          children: [
                            // Status information
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDeactivated
                                    ? Colors.red[50]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDeactivated
                                      ? Colors.red[100]!
                                      : Colors.green[100]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isDeactivated
                                        ? Icons.warning
                                        : Icons.check_circle,
                                    color: isDeactivated
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  SizedBox(width: screenHeight * 0.015),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isDeactivated
                                              ? 'License Deactivated'
                                              : 'License Status',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.bold,
                                            color: isDeactivated
                                                ? Colors.red[700]
                                                : Colors.green[700],
                                          ),
                                        ),
                                        SizedBox(height: screenHeight * 0.005),
                                        Text(
                                          statusDescription,
                                          style: TextStyle(
                                            color: isDeactivated
                                                ? Colors.red[600]
                                                : Colors.green[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildDetailItem("ID Number", user['idNumber']),
                            _buildDetailItem(
                              "License Number",
                              user['licenseNumber'],
                            ),
                            _buildDetailItem(
                              "License Classes",
                              formattedLicenseClass,
                            ),
                            _buildDetailItem("Phone", user['phoneNumber']),
                            _buildDetailItem(
                              "Expiry Date",
                              _formatDate(user['expiryDate']),
                            ),
                            _buildDetailItem("Address", user['address']),
                            _buildDetailItem(
                              "Registration Date",
                              _formatDate(user['createdAt']),
                            ),
                            // Show additional license data if available
                            if (user['licenseData'] != null) ...[
                              _buildDetailItem(
                                "License Owner",
                                user['licenseData']['ownerName']?.toString(),
                              ),
                              _buildDetailItem(
                                "License Status",
                                user['licenseData']['isUsed']?.toString() ==
                                        'true'
                                    ? 'In Use'
                                    : 'Available',
                              ),
                              _buildDetailItem(
                                "License Created",
                                _formatDate(user['licenseData']['createdAt']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value ?? 'Not provided',
              style: const TextStyle(color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _issueFine(Map<String, dynamic> user) {
    final licenseClass = _getLicenseClass(user);
    final formattedLicenseClass = _formatLicenseClass(licenseClass);

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<String>(
        future: _getActualLicenseStatus(user),
        builder: (context, statusSnapshot) {
          final actualStatus = statusSnapshot.data ?? 'active';
          final isDeactivated = actualStatus == 'deactivated';

          return FutureBuilder<String>(
            future: _getStatusDescription(user),
            builder: (context, descriptionSnapshot) {
              final statusDescription =
                  descriptionSnapshot.data ?? 'Valid License';

              return AlertDialog(
                title: Text(
                  "Issue Fine",
                  style: TextStyle(
                    color: isDeactivated ? Colors.red[700] : Colors.blue[700],
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDeactivated) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusDescription,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text("Issue fine to ${user['name'] ?? 'this user'}?"),
                    const SizedBox(height: 8),
                    Text(
                      "User ID: ${user['idNumber'] ?? 'N/A'}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      "License: ${user['licenseNumber'] ?? 'N/A'}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      "License Classes: $formattedLicenseClass",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (isDeactivated) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Status: DEACTIVATED",
                        style: TextStyle(
                          color: Colors.red[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceFinePage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeactivated
                          ? Colors.orange[600]
                          : Colors.blue[600],
                    ),
                    child: const Text("Continue"),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
