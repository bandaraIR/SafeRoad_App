import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({super.key});

  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedCategory;
  String? selectedArea;
  List<String> areas = [];
  List<Map<String, dynamic>> policeList = [];
  List<dynamic> selectedPoliceIds = [];

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final Map<String, String> categoryLabels = {
    "training": "Training",
    "task": "Task",
    "meeting": "Meeting",
    "emergency": "Emergency",
  };

  final Map<String, IconData> categoryIcons = {
    "training": Icons.school,
    "task": Icons.assignment,
    "meeting": Icons.people,
    "emergency": Icons.warning,
  };

  @override
  void initState() {
    super.initState();
    fetchAreas();
  }

  Future<void> fetchAreas() async {
    final snapshot = await _firestore.collection('police').get();
    final uniqueAreas = snapshot.docs
        .map((doc) => doc['area'])
        .where((area) => area != null)
        .map((area) => area.toString().toLowerCase())
        .toSet()
        .toList();
    setState(() {
      areas = uniqueAreas;
    });
  }

  Future<void> fetchPoliceByArea(String area) async {
    setState(() {
      isLoading = true;
      policeList = [];
    });

    final snapshot = await _firestore
        .collection('police')
        .where('area', isEqualTo: area)
        .get();

    setState(() {
      policeList = snapshot.docs.map((doc) {
        return {'name': doc['name'], 'policeId': doc['policeId']};
      }).toList();
      isLoading = false;
    });
  }

  Future<void> postAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      if (selectedCategory == null ||
          selectedArea == null ||
          selectedPoliceIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill all fields."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      try {
        await _firestore.collection('announcements').add({
          'category': selectedCategory,
          'area': selectedArea,
          'eligiblePoliceIds': selectedPoliceIds,
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'adminName': 'Admin',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Announcement posted successfully!"),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          selectedCategory = null;
          selectedArea = null;
          selectedPoliceIds = [];
          policeList = [];
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildSelectedChips() {
    if (selectedPoliceIds.isEmpty) return Container();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectedPoliceIds.map((policeId) {
        final police = policeList.firstWhere(
          (p) => p['policeId'] == policeId,
          orElse: () => {'name': 'Unknown', 'policeId': policeId},
        );

        return Chip(
          label: Text(
            police['name'],
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.blue[700],
          deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
          onDeleted: () {
            setState(() {
              selectedPoliceIds.remove(policeId);
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          "Create Announcement",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small Top Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 40),
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign,
                            size: 24,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 12, height: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "New Announcement",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  "Create and share important information",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Category Dropdown
                    _buildCategoryDropdown(),
                    const SizedBox(height: 10),

                    // Area & Location
                    if (!isMobile)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAreaDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildLocationField()),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildAreaDropdown(),
                          const SizedBox(height: 16),
                          _buildLocationField(),
                        ],
                      ),
                    const SizedBox(height: 15),

                    // Police Selection
                    _buildPoliceSelection(),

                    // Selected Chips
                    if (selectedPoliceIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSelectedChips(),
                    ],

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      "Description *",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter announcement description';
                        return null;
                      },
                      style: const TextStyle(fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Enter detailed announcement information...",
                        hintStyle: const TextStyle(fontFamily: 'Poppins'),
                        border: OutlineInputBorder(
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
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF90CAF9),
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Post Button
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
                          onTap: isLoading ? null : postAnnouncement,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text(
                                        "POST ANNOUNCEMENT",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category *",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF1565C0),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF90CAF9)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            value: selectedCategory,
            style: const TextStyle(fontFamily: 'Poppins'),
            items: categoryLabels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(
                          categoryIcons[entry.key],
                          color: const Color(0xFF1565C0),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value;
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a category';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAreaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Area *",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF1565C0),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF90CAF9)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            value: selectedArea,
            style: const TextStyle(fontFamily: 'Poppins'),
            items: areas
                .map(
                  (area) => DropdownMenuItem(
                    value: area,
                    child: Text(
                      area.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedArea = value;
                selectedPoliceIds.clear();
              });
              if (value != null) fetchPoliceByArea(value);
            },
            validator: (value) {
              if (value == null) return 'Please select an area';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Location *",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _locationController,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter location';
            return null;
          },
          style: const TextStyle(fontFamily: 'Poppins'),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: "Enter location (e.g., Town Hall, Police Station)",
            hintStyle: const TextStyle(fontFamily: 'Poppins'),
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1565C0)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF90CAF9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFF90CAF9)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoliceSelection() {
    double width = MediaQuery.of(context).size.width;
    double fontSmall = width < 360 ? 12 : 14;
    double fontMedium = width < 360 ? 14 : 16;
    double paddingBox = width < 360 ? 12 : 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Eligible Policemen *",
          style: TextStyle(
            fontSize: fontMedium,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),

        /// --- If no area selected ---
        if (selectedArea == null)
          Container(
            width: width,
            padding: EdgeInsets.all(paddingBox),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Please select an area first to view available policemen",
                    style: TextStyle(
                      fontSize: fontSmall,
                      color: Colors.grey[700],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          )
        /// --- Loading State ---
        else if (isLoading)
          const Center(child: CircularProgressIndicator())
        /// --- No Police Found ---
        else if (policeList.isEmpty)
          Container(
            width: width,
            padding: EdgeInsets.all(paddingBox),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: Color(0xFFFF9800)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No policemen found for this area",
                    style: TextStyle(
                      fontSize: fontSmall,
                      color: Colors.orange[700],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          )
        /// --- Multi-select Dropdown ---
        else
          Container(
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: width < 360 ? 8 : 12,
              vertical: width < 360 ? 4 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: MultiSelectDialogField(
              items: policeList
                  .map(
                    (p) => MultiSelectItem<String>(
                      p['policeId'],
                      "${p['name']} (${p['policeId']})",
                    ),
                  )
                  .toList(),
              title: Text(
                "Select Policemen",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  fontSize: fontMedium,
                ),
              ),
              selectedColor: const Color(0xFF1565C0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              buttonIcon: const Icon(
                Icons.people,
                color: Colors.grey,
                size: 20,
              ),
              buttonText: Text(
                selectedPoliceIds.isEmpty
                    ? "Select Policemen"
                    : "${selectedPoliceIds.length} selected",
                style: TextStyle(
                  color: Colors.grey[800],
                  fontFamily: 'Poppins',
                  fontSize: fontSmall,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              onConfirm: (values) {
                setState(() {
                  selectedPoliceIds = values;
                });
              },
              chipDisplay: MultiSelectChipDisplay(
                textStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: fontSmall,
                ),
                items: selectedPoliceIds.map((id) {
                  final police = policeList.firstWhere(
                    (p) => p['policeId'] == id,
                    orElse: () => {'name': 'Unknown', 'policeId': id},
                  );
                  return MultiSelectItem<String>(id, police['name']);
                }).toList(),
                onTap: (value) {
                  setState(() {
                    selectedPoliceIds.remove(value);
                  });
                },
              ),
              listType: MultiSelectListType.CHIP,
              searchable: true,
              searchHint: "Search policemen...",
              searchHintStyle: const TextStyle(fontFamily: 'Poppins'),
              itemsTextStyle: const TextStyle(fontFamily: 'Poppins'),
              selectedItemsTextStyle: const TextStyle(
                color: Colors.black,
                fontFamily: 'Poppins',
              ),
            ),
          ),
      ],
    );
  }
}
