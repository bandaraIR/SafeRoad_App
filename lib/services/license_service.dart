// lib/services/license_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream that combines user data, license data, and unpaid fines with due date checking
  Stream<Map<String, dynamic>> licenseStatusStream(String email) {
    return _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .snapshots()
        .asyncExpand((userSnapshot) {
          if (userSnapshot.docs.isEmpty) {
            return Stream.value({
              'status': 'unknown',
              'licenseNumber': '',
              'userData': {},
              'licenseData': {},
              'unpaidFinesCount': 0,
              'totalUnpaidAmount': 0,
              'hasOverdueFines': false,
              'unpaidFines': [],
            });
          }

          final userDoc = userSnapshot.docs.first;
          final userData = userDoc.data() as Map<String, dynamic>;
          final licenseNumber = userData['licenseNumber'] ?? '';

          // If no license number, return basic data
          if (licenseNumber.isEmpty) {
            return Stream.value({
              'status': userData['status'] ?? 'active',
              'licenseNumber': licenseNumber,
              'userData': userData,
              'licenseData': {},
              'unpaidFinesCount': 0,
              'totalUnpaidAmount': 0,
              'hasOverdueFines': false,
              'unpaidFines': [],
            });
          }

          // Stream of license data
          final licenseStream = _firestore
              .collection('licenses')
              .doc(licenseNumber)
              .snapshots();

          // Stream of fines for status checking
          final finesStream = _firestore
              .collection('fines')
              .where('licenseNumber', isEqualTo: licenseNumber)
              .snapshots();

          return licenseStream.asyncExpand((licenseDoc) {
            Map<String, dynamic> licenseData = {};

            if (licenseDoc.exists) {
              licenseData = licenseDoc.data() as Map<String, dynamic>? ?? {};
            }

            return finesStream.asyncMap((finesSnapshot) async {
              final now = DateTime.now();
              bool hasOverdueUnpaidFines = false;
              int unpaidFinesCount = 0;
              double totalUnpaidAmount = 0;
              List<Map<String, dynamic>> unpaidFines = [];

              // Check each fine for status and due dates
              for (var fineDoc in finesSnapshot.docs) {
                final fineData = fineDoc.data() as Map<String, dynamic>;
                final status = fineData['status'] ?? 'Unpaid';
                final dueDateString = fineData['dueDate'];
                final amount = (fineData['amount'] ?? 0).toDouble();

                if (status == 'Unpaid') {
                  unpaidFinesCount++;
                  totalUnpaidAmount += amount;
                  unpaidFines.add(fineData);

                  // Check if this unpaid fine is overdue
                  if (dueDateString != null) {
                    try {
                      final dueDate = DateTime.parse(dueDateString);
                      if (dueDate.isBefore(now)) {
                        hasOverdueUnpaidFines = true;
                      }
                    } catch (e) {
                      print('Error parsing due date: $e');
                      hasOverdueUnpaidFines = true;
                    }
                  }
                }
              }

              // Determine final status - deactive if ANY unpaid fines are overdue
              final status = hasOverdueUnpaidFines ? 'deactive' : 'active';

              // Update user status in Firestore if changed
              final currentUserStatus = userData['status'] ?? 'active';
              if (currentUserStatus != status) {
                try {
                  await _firestore.collection('users').doc(userDoc.id).update({
                    'status': status,
                    'lastStatusUpdate': FieldValue.serverTimestamp(),
                  });
                  print('Updated user status to: $status');
                } catch (e) {
                  print('Error updating user status: $e');
                  // Continue with calculated status even if update fails
                }
              }

              return {
                'status': status,
                'unpaidFinesCount': unpaidFinesCount,
                'totalUnpaidAmount': totalUnpaidAmount,
                'licenseNumber': licenseNumber,
                'userData': userData,
                'licenseData': licenseData,
                'unpaidFines': unpaidFines,
                'hasOverdueFines': hasOverdueUnpaidFines,
              };
            });
          });
        });
  }

  /// Helper method to manually check and update status
  Future<void> manuallyCheckAndUpdateStatus(String email) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final licenseNumber = userData['licenseNumber'] ?? '';

      if (licenseNumber.isEmpty) return;

      final finesQuery = await _firestore
          .collection('fines')
          .where('licenseNumber', isEqualTo: licenseNumber)
          .get();

      final now = DateTime.now();
      bool hasOverdueUnpaidFines = false;

      for (var fineDoc in finesQuery.docs) {
        final fineData = fineDoc.data() as Map<String, dynamic>;
        final status = fineData['status'] ?? 'Unpaid';
        final dueDateString = fineData['dueDate'];

        if (status == 'Unpaid' && dueDateString != null) {
          try {
            final dueDate = DateTime.parse(dueDateString);
            if (dueDate.isBefore(now)) {
              hasOverdueUnpaidFines = true;
              break;
            }
          } catch (e) {
            print('Error parsing due date: $e');
            hasOverdueUnpaidFines = true;
          }
        }
      }

      final newStatus = hasOverdueUnpaidFines ? 'deactive' : 'active';
      final currentStatus = userData['status'] ?? 'active';

      if (currentStatus != newStatus) {
        try {
          await _firestore.collection('users').doc(userDoc.id).update({
            'status': newStatus,
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          });
          print('Manually updated status to: $newStatus');
        } catch (e) {
          print('Error in manual status update: $e');
        }
      }
    } catch (e) {
      print('Error in manual status check: $e');
    }
  }

  /// Get fines count for the license
  Stream<int> getUnpaidFinesCount(String licenseNumber) {
    if (licenseNumber.isEmpty) {
      return Stream.value(0);
    }

    return _firestore
        .collection('fines')
        .where('licenseNumber', isEqualTo: licenseNumber)
        .where('status', isEqualTo: 'Unpaid')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Check if license has overdue fines
  Stream<bool> hasOverdueFines(String licenseNumber) {
    if (licenseNumber.isEmpty) {
      return Stream.value(false);
    }

    return _firestore
        .collection('fines')
        .where('licenseNumber', isEqualTo: licenseNumber)
        .where('status', isEqualTo: 'Unpaid')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();

          for (var doc in snapshot.docs) {
            final fineData = doc.data() as Map<String, dynamic>;
            final dueDateString = fineData['dueDate'];

            if (dueDateString != null) {
              try {
                final dueDate = DateTime.parse(dueDateString);
                if (dueDate.isBefore(now)) {
                  return true;
                }
              } catch (e) {
                print('Error parsing due date: $e');
              }
            }
          }
          return false;
        });
  }
}
