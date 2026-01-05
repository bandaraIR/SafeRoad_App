import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String name;
  final String phoneNumber;

  EmergencyContact({required this.name, required this.phoneNumber});

  Map<String, dynamic> toMap() {
    return {'name': name, 'phoneNumber': phoneNumber};
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }
}

class SOSPage extends StatefulWidget {
  final String userId;

  const SOSPage({super.key, required this.userId});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  List<EmergencyContact> _emergencyContacts = [];
  bool _contactsLoaded = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  // Load emergency contacts from Firestore - using userId as document ID
  Future<void> _loadEmergencyContacts() async {
    try {
      final doc = await _firestore
          .collection('emergency_contacts')
          .doc(widget.userId) // Use userId as document ID
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['contacts'] != null) {
          final List<dynamic> contactsList = data['contacts'];
          setState(() {
            _emergencyContacts = contactsList
                .map((contactMap) => EmergencyContact.fromMap(contactMap))
                .toList();
          });
        }
      }

      setState(() {
        _contactsLoaded = true;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        _contactsLoaded = true;
      });
    }
  }

  // Add emergency contact - store in user's document
  Future<void> _addEmergencyContactToFirestore(
    String name,
    String phoneNumber,
  ) async {
    final newContact = EmergencyContact(name: name, phoneNumber: phoneNumber);

    // Get current contacts and add new one
    final List<Map<String, dynamic>> updatedContacts = [
      ..._emergencyContacts.map((contact) => contact.toMap()),
      newContact.toMap(),
    ];

    // Update Firestore - document ID = userId
    await _firestore
        .collection('emergency_contacts')
        .doc(widget.userId) // Use userId as document ID
        .set({
          'contacts': updatedContacts,
          'userId': widget.userId,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    setState(() {
      _emergencyContacts.add(newContact);
    });
  }

  // Remove emergency contact
  Future<void> _removeEmergencyContactFromFirestore(int index) async {
    setState(() {
      _emergencyContacts.removeAt(index);
    });

    // Update Firestore with remaining contacts
    final List<Map<String, dynamic>> updatedContacts = _emergencyContacts
        .map((contact) => contact.toMap())
        .toList();

    await _firestore.collection('emergency_contacts').doc(widget.userId).set({
      'contacts': updatedContacts,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ... Rest of your UI methods remain exactly the same ...
  // _buildHeader, _buildEmergencySOSButton, _buildEmergencyContacts, etc.
  // Only the contact management methods above are changed

  // Add Emergency Contact
  Future<void> _addEmergencyContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isNotEmpty && phone.isNotEmpty) {
                Navigator.pop(context);

                try {
                  await _addEmergencyContactToFirestore(name, phone);
                  _showSuccessDialog('Contact added successfully!');
                } catch (e) {
                  _showErrorDialog('Failed to add contact');
                }
              } else {
                _showErrorDialog('Please enter both name and phone number');
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Remove Contact - updated to use index
  void _removeContact(int index) {
    final contact = _emergencyContacts[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Contact'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _removeEmergencyContactFromFirestore(index);
                _showSuccessDialog('Contact removed successfully!');
              } catch (e) {
                _showErrorDialog('Failed to remove contact');
              }
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Update the contact card to use index for removal
  Widget _buildContactCard(
    EmergencyContact contact,
    int index,
    double screenWidth,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.blue[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          contact.phoneNumber,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            fontFamily: 'Poppins',
            color: Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.phone, color: Colors.blue[700]),
              onPressed: () =>
                  _callEmergencyNumber(contact.phoneNumber, contact.name),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[400]),
              onPressed: () =>
                  _removeContact(index), // Pass index instead of contact
            ),
          ],
        ),
      ),
    );
  }

  // Update contacts list to pass index
  Widget _buildContactsList(double screenWidth) {
    return Column(
      children: _emergencyContacts.asMap().entries.map((entry) {
        final index = entry.key;
        final contact = entry.value;
        return _buildContactCard(contact, index, screenWidth);
      }).toList(),
    );
  }

  // Simple Success Dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Simple Error Dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Call Emergency Number
  void _callEmergencyNumber(String number, String serviceName) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanNumber.isEmpty) {
      _showErrorDialog('Invalid phone number for $serviceName');
      return;
    }

    final Uri phoneUrl = Uri.parse('tel:$cleanNumber');

    try {
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        _showErrorDialog('Cannot make phone calls on this device');
      }
    } catch (e) {
      _showErrorDialog('Failed to call $serviceName: $e');
    }
  }

  // ... Copy all your other existing UI methods here unchanged ...
  // _buildHeader, _buildEmergencySOSButton, _buildEmergencyContacts,
  // _buildMyEmergencyContacts, _buildAdditionalInfo, _showEmergencyOptions, etc.

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          _buildHeader(context, screenWidth),

          // Emergency SOS Button
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  _buildEmergencySOSButton(context, screenWidth, screenHeight),
                  SizedBox(height: screenHeight * 0.04),
                  _buildEmergencyContacts(screenWidth),
                  SizedBox(height: screenHeight * 0.03),
                  _buildMyEmergencyContacts(screenWidth),
                  SizedBox(height: screenHeight * 0.03),
                  _buildAdditionalInfo(screenWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header Section
  Widget _buildHeader(BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.only(
        top: screenWidth * 0.08,
        bottom: screenWidth * 0.05,
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(width: screenWidth * 0.02),
              const Text(
                'Emergency SOS',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            'Immediate assistance at your fingertips',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontFamily: 'Poppins',
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // Main SOS Button
  Widget _buildEmergencySOSButton(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    final buttonSize = screenWidth * 0.5;

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showEmergencyOptions(context),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                ...List.generate(3, (index) {
                  return Positioned.fill(
                    child: Container(
                      margin: EdgeInsets.all(20.0 * index),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue[300]!.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: buttonSize * 0.3,
                      ),
                      SizedBox(height: buttonSize * 0.05),
                      Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: buttonSize * 0.14,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: buttonSize * 0.02),
                      Text(
                        'EMERGENCY',
                        style: TextStyle(
                          fontSize: buttonSize * 0.05,
                          fontFamily: 'Poppins',
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Text(
          'Tap for emergency services',
          style: TextStyle(
            fontSize: screenWidth * 0.04,
            fontFamily: 'Poppins',
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Emergency Contacts Section
  Widget _buildEmergencyContacts(double screenWidth) {
    final crossAxisCount = screenWidth > 600 ? 4 : 2;
    final childAspectRatio = screenWidth > 600 ? 1.2 : 2.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Emergency Contacts',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: screenWidth * 0.03,
          mainAxisSpacing: screenWidth * 0.03,
          children: [
            _buildEmergencyContactCard(
              Icons.local_police,
              'Police',
              '119',
              Colors.blue[700]!,
              screenWidth,
            ),
            _buildEmergencyContactCard(
              Icons.medical_services,
              'Ambulance',
              '1990',
              Colors.blue[600]!,
              screenWidth,
            ),
            _buildEmergencyContactCard(
              Icons.fire_truck,
              'Fire Brigade',
              '110',
              Colors.blue[500]!,
              screenWidth,
            ),
            _buildEmergencyContactCard(
              Icons.car_repair,
              'Road Assistance',
              '131',
              Colors.blue[400]!,
              screenWidth,
            ),
          ],
        ),
      ],
    );
  }

  // My Emergency Contacts Section
  Widget _buildMyEmergencyContacts(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Emergency Contacts',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: Colors.blue[700]),
              onPressed: _addEmergencyContact,
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        _emergencyContacts.isEmpty
            ? _buildEmptyContactsState(screenWidth)
            : _buildContactsList(screenWidth),
      ],
    );
  }

  // Empty Contacts State
  Widget _buildEmptyContactsState(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.contacts,
            color: Colors.grey[400],
            size: screenWidth * 0.1,
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            'No Emergency Contacts',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Text(
            'Tap the + button to add emergency contacts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.033,
              fontFamily: 'Poppins',
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Emergency Contact Card
  Widget _buildEmergencyContactCard(
    IconData icon,
    String title,
    String number,
    Color color,
    double screenWidth,
  ) {
    return GestureDetector(
      onTap: () => _callEmergencyNumber(number, title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.15,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Icon(icon, color: color, size: screenWidth * 0.07),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: screenWidth * 0.03),
              child: Icon(Icons.phone, color: color, size: screenWidth * 0.05),
            ),
          ],
        ),
      ),
    );
  }

  // Additional Information Section
  Widget _buildAdditionalInfo(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: Colors.blue[700],
                size: screenWidth * 0.06,
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'Emergency Tips',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            '• Stay calm and speak clearly\n'
            '• Provide your exact location\n'
            '• Describe the emergency briefly\n'
            '• Follow operator instructions',
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontFamily: 'Poppins',
              color: Colors.blue[800]!.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Emergency Options Bottom Sheet
  void _showEmergencyOptions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emergency,
                    color: Colors.blue[700],
                    size: screenWidth * 0.07,
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Text(
                    "Select Emergency Service",
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenWidth * 0.03,
                ),
                children: [
                  _buildEmergencyOptionTile(
                    context,
                    Icons.local_police,
                    "Police Emergency",
                    "Report crimes, accidents, or security threats",
                    "119",
                    Colors.blue[700]!,
                  ),
                  _buildEmergencyOptionTile(
                    context,
                    Icons.medical_services,
                    "Ambulance & Medical",
                    "Medical emergencies, ambulance service",
                    "1990",
                    Colors.blue[600]!,
                  ),
                  _buildEmergencyOptionTile(
                    context,
                    Icons.fire_truck,
                    "Fire Brigade",
                    "Fire emergencies, rescue operations",
                    "110",
                    Colors.blue[500]!,
                  ),
                  _buildEmergencyOptionTile(
                    context,
                    Icons.car_repair,
                    "Road Assistance",
                    "Vehicle breakdown, towing service",
                    "131",
                    Colors.blue[400]!,
                  ),
                  if (_emergencyContacts.isNotEmpty)
                    ..._emergencyContacts.map((contact) {
                      return _buildEmergencyOptionTile(
                        context,
                        Icons.person,
                        contact.name,
                        "Emergency Contact",
                        contact.phoneNumber,
                        Colors.blue[300]!,
                      );
                    }).toList(),
                  if (_emergencyContacts.isEmpty)
                    _buildEmergencyOptionTile(
                      context,
                      Icons.person,
                      "Emergency Contact",
                      "Add your emergency contacts",
                      "Add Contact",
                      Colors.blue[300]!,
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Emergency Option Tile
  Widget _buildEmergencyOptionTile(
    BuildContext parentContext,
    IconData icon,
    String title,
    String subtitle,
    String number,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(parentContext).size.width;

    return Card(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.02,
        ),
        leading: Container(
          width: screenWidth * 0.12,
          height: screenWidth * 0.12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: screenWidth * 0.06),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: screenWidth * 0.04,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey[600],
            fontSize: screenWidth * 0.033,
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenWidth * 0.02,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            number.length > 10 ? '${number.substring(0, 10)}...' : number,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ),
        onTap: () {
          Navigator.pop(parentContext);
          if (number != "Add Contact" && number.isNotEmpty) {
            _callEmergencyNumber(number, title);
          } else if (number == "Add Contact") {
            _addEmergencyContact();
          }
        },
      ),
    );
  }
}
