import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:saferoad/pages/login_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  File? _profileImage;
  bool _isUploading = false;
  String? _profileImageUrl;

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(User currentUser) async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  Navigator.of(context).pop(); // pop AFTER picking
                  if (pickedFile != null) {
                    await _uploadImage(File(pickedFile.path), currentUser);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () async {
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                    maxWidth: 512,
                    maxHeight: 512,
                  );
                  Navigator.of(context).pop(); // pop AFTER picking
                  if (pickedFile != null) {
                    await _uploadImage(File(pickedFile.path), currentUser);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(File imageFile, User currentUser) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${currentUser.uid}.jpg');

      await storageRef.putFile(imageFile);
      final downloadURL = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .get()
          .then((querySnapshot) {
            for (var doc in querySnapshot.docs) {
              doc.reference.update({'profilePictureUrl': downloadURL});
            }
          });

      setState(() {
        _profileImageUrl = downloadURL;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  Widget _buildProfileImage(Map<String, dynamic>? userData, User currentUser) {
    final String? imageUrl = userData?['profilePictureUrl'] ?? _profileImageUrl;

    if (_isUploading) {
      return Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.blue[700]!.withOpacity(0.1),
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null || imageUrl.isEmpty
                ? Text(
                    userData?['name'] != null && userData!['name'] != ''
                        ? userData['name'][0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 42,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploading ? null : () => _pickImage(currentUser),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                "User not logged in",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final userQuery = FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: currentUser.email)
        .limit(1);

    return FutureBuilder<QuerySnapshot>(
      future: userQuery.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading profile: ${snapshot.error}",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No user data found for: ${currentUser.email}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _createUserDocument(currentUser);
                    },
                    child: const Text('Create User Profile'),
                  ),
                ],
              ),
            ),
          );
        }

        final userDoc = snapshot.data!.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;

        if (userData['profilePictureUrl'] != null &&
            userData['profilePictureUrl'].isNotEmpty &&
            _profileImageUrl == null) {
          _profileImageUrl = userData['profilePictureUrl'];
        }

        String expiryDateString = '';
        if (userData['expiryDate'] != null &&
            userData['expiryDate'] is Timestamp) {
          final Timestamp expiryTimestamp = userData['expiryDate'];
          final expiryDate = expiryTimestamp.toDate();
          expiryDateString =
              "${expiryDate.day.toString().padLeft(2, '0')}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.year}";
        }

        Widget buildInfoCard(String title, String value, IconData icon) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A86D8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFF0A86D8), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.isNotEmpty ? value : 'Not provided',
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 170,
                      width: double.infinity,
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
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              "My Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                              ),
                              onPressed: () => _showLogoutDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isUploading
                              ? null
                              : () => _pickImage(currentUser),
                          child: _buildProfileImage(userData, currentUser),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),
                Text(
                  userData['name'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userData['email'] ?? currentUser.email ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      buildInfoCard(
                        'Full Name',
                        userData['name'] ?? '',
                        Icons.person_outline,
                      ),
                      buildInfoCard(
                        'Address',
                        userData['address'] ?? '',
                        Icons.location_on_outlined,
                      ),
                      buildInfoCard(
                        'Phone Number',
                        userData['phoneNumber'] ?? '',
                        Icons.phone_outlined,
                      ),
                      buildInfoCard(
                        'ID Number',
                        userData['idNumber'] ?? '',
                        Icons.badge_outlined,
                      ),
                      buildInfoCard(
                        'License Number',
                        userData['licenseNumber'] ?? '',
                        Icons.drive_eta_outlined,
                      ),
                      buildInfoCard(
                        'License Expiry Date',
                        expiryDateString,
                        Icons.calendar_today_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createUserDocument(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'address': '',
        'phoneNumber': '',
        'idNumber': '',
        'licenseNumber': '',
        'expiryDate': null,
        'profilePictureUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User profile created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating user profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
