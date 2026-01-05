import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:saferoad/pages/login_page.dart';

class PoliceProfilePage extends StatefulWidget {
  const PoliceProfilePage({super.key});

  @override
  State<PoliceProfilePage> createState() => _PoliceProfilePageState();
}

class _PoliceProfilePageState extends State<PoliceProfilePage> {
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
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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

  Future<void> _pickImage(String docId) async {
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
                  Navigator.of(context).pop();
                  if (pickedFile != null) {
                    await _uploadImage(File(pickedFile.path), docId);
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
                  Navigator.of(context).pop();
                  if (pickedFile != null) {
                    await _uploadImage(File(pickedFile.path), docId);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(File imageFile, String docId) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('police_profile_pictures')
          .child('$docId.jpg');

      await storageRef.putFile(imageFile);
      final downloadURL = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('police').doc(docId).update({
        'profilePictureUrl': downloadURL,
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
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProfileImage(Map<String, dynamic> data, String docId) {
    final String? imageUrl = data['profilePictureUrl'] ?? _profileImageUrl;

    if (_isUploading) {
      return const CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color.fromARGB(255, 255, 255, 255),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            backgroundColor: Colors.blue[50], // Light blue background
            child: imageUrl == null || imageUrl.isEmpty
                ? Text(
                    data['name'] != null && data['name'] != ''
                        ? data['name'][0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      fontSize: 42,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700], // Letter blue
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => _pickImage(docId),
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

  Widget buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("No police logged in")));
    }

    final policeQuery = FirebaseFirestore.instance
        .collection('police')
        .where('email', isEqualTo: currentUser.email)
        .limit(1);

    return FutureBuilder<QuerySnapshot>(
      future: policeQuery.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Police profile not found")),
          );
        }

        final policeDoc = snapshot.data!.docs.first;
        final data = policeDoc.data() as Map<String, dynamic>;

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
                              "Police Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Poppins',
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
                        child: _buildProfileImage(data, policeDoc.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),
                Text(
                  data['name'] ?? 'Unknown Officer',
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['email'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      buildInfoCard(
                        'Police ID',
                        data['policeId'] ?? '',
                        Icons.badge_outlined,
                      ),
                      buildInfoCard(
                        'Phone Number',
                        data['phoneNumber'] ?? '',
                        Icons.phone_outlined,
                      ),
                      buildInfoCard(
                        'Address',
                        data['address'] ?? '',
                        Icons.location_on_outlined,
                      ),
                      buildInfoCard(
                        'Area',
                        data['area'] ?? '',
                        Icons.map_outlined,
                      ),
                      buildInfoCard(
                        'Online Status',
                        (data['onlineStatus'] ?? false) ? 'Online' : 'Offline',
                        Icons.circle,
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
}
