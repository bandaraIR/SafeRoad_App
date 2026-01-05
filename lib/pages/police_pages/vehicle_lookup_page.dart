import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleLookupPage extends StatefulWidget {
  const VehicleLookupPage({super.key});

  @override
  State<VehicleLookupPage> createState() => _VehicleLookupPageState();
}

class _VehicleLookupPageState extends State<VehicleLookupPage> {
  final TextEditingController _vehicleController = TextEditingController();
  bool isLoading = false;
  Map<String, dynamic>? vehicleData;

  Future<void> _searchVehicle() async {
    final vehicleNumber = _vehicleController.text.trim();
    if (vehicleNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a vehicle number"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      vehicleData = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('vehicleNumber', isEqualTo: vehicleNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          vehicleData = {
            "name": data['name'] ?? 'N/A',
            "idNumber": data['idNumber'] ?? 'N/A',
            "licenseNumber": data['licenseNumber'] ?? 'N/A',
          };
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vehicle not found"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error searching vehicle"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLarge = size.width > 768;

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
        title: Text(
          "Vehicle Lookup",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 100 : 24,
          vertical: 40,
        ),
        child: Column(
          children: [
            // 🔍 Search Bar
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  SizedBox(width: 20),
                  Icon(Icons.car_rental, color: Colors.blue),
                  SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _vehicleController,
                      decoration: InputDecoration(
                        hintText: "Enter vehicle number...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      style: TextStyle(fontSize: 16),
                      onSubmitted: (_) => _searchVehicle(),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                    ),
                    child: isLoading
                        ? Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _searchVehicle,
                            icon: Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            // ✅ Results Section
            if (vehicleData != null)
              AnimatedContainer(
                duration: Duration(milliseconds: 600),
                padding: EdgeInsets.all(isLarge ? 30 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Vehicle Found",
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildInfoCard(
                      "Owner Name",
                      vehicleData!['name'],
                      Icons.person,
                    ),
                    SizedBox(height: 12),
                    _buildInfoCard(
                      "User ID",
                      vehicleData!['idNumber'],
                      Icons.badge,
                    ),
                    SizedBox(height: 12),
                    _buildInfoCard(
                      "License Number",
                      vehicleData!['licenseNumber'],
                      Icons.card_membership,
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            vehicleData = null;
                            _vehicleController.clear();
                          });
                        },
                        icon: Icon(Icons.refresh),
                        label: Text(
                          "Search Again",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 🚗 Empty State
            if (vehicleData == null && !isLoading)
              Container(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.car_repair, size: 60, color: Colors.grey[300]),
                    SizedBox(height: 10),
                    Text(
                      "Search for a vehicle to begin",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontFamily: 'Poppins',
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

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
