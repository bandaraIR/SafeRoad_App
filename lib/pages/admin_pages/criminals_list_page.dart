import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CriminalsListPage extends StatefulWidget {
  const CriminalsListPage({super.key});

  @override
  State<CriminalsListPage> createState() => _CriminalsListPageState();
}

class _CriminalsListPageState extends State<CriminalsListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDangerLevel = 'All';

  final List<String> _statusFilters = [
    'All',
    'wanted',
    'in custody',
    'released',
    'deceased',
  ];

  final List<String> _dangerFilters = [
    'All',
    'Low',
    'Medium',
    'High',
    'Extremely High',
  ];

  Color _getDangerColor(String level) {
    switch (level) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      case 'Extremely High':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'wanted':
        return Colors.red;
      case 'in custody':
        return Colors.orange;
      case 'released':
        return Colors.green;
      case 'deceased':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'wanted':
        return Icons.search;
      case 'in custody':
        return Icons.lock;
      case 'released':
        return Icons.lock_open;
      case 'deceased':
        return Icons.close;
      default:
        return Icons.info;
    }
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['fullName'] ?? '').toString().toLowerCase();
      final plate = (data['plateNumber'] ?? '').toString().toLowerCase();
      final reason = (data['reason'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? '').toString();
      final danger = (data['dangerLevel'] ?? '').toString();

      final matchesSearch =
          _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          plate.contains(_searchQuery.toLowerCase()) ||
          reason.contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatus == 'All' || status == _selectedStatus;

      final matchesDanger =
          _selectedDangerLevel == 'All' || danger == _selectedDangerLevel;

      return matchesSearch && matchesStatus && matchesDanger;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Criminal Records",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Search & manage suspects",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Search + Filters ──────────────────────
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by name, plate, or reason...",
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey[400],
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[400]!,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter chips row
                Row(
                  children: [
                    // Status filter
                    Expanded(
                      child: _buildFilterDropdown(
                        label: "Status",
                        value: _selectedStatus,
                        items: _statusFilters,
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                        colorMap: {
                          'wanted': Colors.red,
                          'in custody': Colors.orange,
                          'released': Colors.green,
                          'deceased': Colors.grey,
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Danger filter
                    Expanded(
                      child: _buildFilterDropdown(
                        label: "Danger",
                        value: _selectedDangerLevel,
                        items: _dangerFilters,
                        onChanged: (v) =>
                            setState(() => _selectedDangerLevel = v!),
                        colorMap: {
                          'Low': Colors.green,
                          'Medium': Colors.orange,
                          'High': Colors.red,
                          'Extremely High': Colors.purple,
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('criminals')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snapshot.error}",
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                final filtered = _applyFilters(allDocs);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    return _buildCriminalCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    Map<String, Color>? colorMap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey[500],
            size: 20,
          ),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.black87,
          ),
          onChanged: onChanged,
          items: items.map((item) {
            final color = colorMap?[item];
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  if (color != null && item != 'All') ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    item == 'All' ? "$label: All" : item,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: (item != 'All' && color != null)
                          ? color
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCriminalCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'unknown';
    final danger = data['dangerLevel'] ?? 'Medium';
    final statusColor = _getStatusColor(status);
    final dangerColor = _getDangerColor(danger);
    final statusIcon = _getStatusIcon(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top colored bar based on danger level
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: dangerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Status badge
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: dangerColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: dangerColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['fullName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ID: ${data['criminalId'] ?? 'N/A'}",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Info grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.directions_car,
                        label: "Plate",
                        value: data['plateNumber'] ?? 'N/A',
                        color: Colors.blue[600]!,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.warning_amber_rounded,
                        label: "Danger",
                        value: danger,
                        color: dangerColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Reason
                _buildInfoTile(
                  icon: Icons.report_outlined,
                  label: "Reason",
                  value: data['reason'] ?? 'N/A',
                  color: Colors.red[400]!,
                ),

                // Address (if available)
                if ((data['address'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoTile(
                    icon: Icons.location_on_outlined,
                    label: "Last Known Address",
                    value: data['address'],
                    color: Colors.teal,
                  ),
                ],

                // Description (if available)
                if ((data['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoTile(
                    icon: Icons.description_outlined,
                    label: "Description",
                    value: data['description'],
                    color: Colors.grey[600]!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            "No Records Found",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try adjusting your search or filters",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
