import 'package:flutter/material.dart';
import '../models/medicine_info.dart';
import '../models/medication_reminder.dart';
import '../services/notification_service.dart';
import 'add_reminder_screen.dart';
import 'medication_reminders_screen.dart';

class MedicineDetailsScreen extends StatelessWidget {
  final MedicineInfo medicine;

  const MedicineDetailsScreen({
    Key? key,
    required this.medicine,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          medicine.name,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Reminder button
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: 'View Reminders',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => const MedicationRemindersScreen(),
                ),
              );
            },
          ),
          // Trustworthiness indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildTrustworthinessIndicator(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with medicine icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DCCA7).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: Color(0xFF2DCCA7),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Add reminder button
                  ElevatedButton.icon(
                    onPressed: () => _createReminder(context),
                    icon: const Icon(Icons.alarm_add),
                    label: const Text(
                      'SET REMINDER',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: const Color(0xFF2DCCA7),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Description section
            _buildSection(
              title: "About This Medicine",
              content: medicine.description,
              icon: Icons.info_outline,
            ),
            
            // Common uses section
            _buildSection(
              title: "Common Uses",
              content: medicine.commonUses,
              icon: Icons.healing,
              iconColor: Colors.green,
            ),
            
            // Dosage section
            _buildSection(
              title: "Dosage Information",
              content: medicine.dosage,
              icon: Icons.schedule,
              iconColor: const Color(0xFF2DCCA7),
            ),
            
            // Warning section
            _buildSection(
              title: "Important Information",
              content: medicine.criticalInfo,
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            
            // Side effects section
            _buildSection(
              title: "Side Effects",
              content: medicine.sideEffects,
              icon: Icons.sick,
              iconColor: Colors.orange,
              backgroundColor: Colors.orange.withOpacity(0.1),
            ),
            
            // Interactions section
            _buildSection(
              title: "Drug Interactions",
              content: medicine.interactions,
              icon: Icons.sync_problem,
              iconColor: Colors.purple,
              backgroundColor: Colors.purple.withOpacity(0.1),
            ),
            
            // Disclaimer section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.medical_information,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Medical Disclaimer",
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "The information provided is for educational purposes only and is not intended as medical advice. Always consult a healthcare professional before taking any medication or making changes to your treatment regimen.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Do not use this information to diagnose or treat a health problem without consulting a qualified healthcare provider. Seek immediate medical attention if you think you may have a medical emergency.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Trustworthiness explanation
                  _buildTrustworthinessExplanation(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to build consistent section widgets
  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    Color iconColor = const Color(0xFF2DCCA7),
    Color? backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
  
  // Build trustworthiness indicator icon
  Widget _buildTrustworthinessIndicator() {
    if (medicine.isTrustworthy) {
      return Tooltip(
        message: 'Information likely reliable',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified,
            color: Colors.green,
            size: 24,
          ),
        ),
      );
    } else {
      return Tooltip(
        message: 'Information reliability uncertain',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.info,
            color: Colors.orange,
            size: 24,
          ),
        ),
      );
    }
  }
  
  // Build explanation for trustworthiness
  Widget _buildTrustworthinessExplanation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (medicine.isTrustworthy ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (medicine.isTrustworthy ? Colors.green : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            medicine.isTrustworthy ? Icons.verified : Icons.info,
            color: medicine.isTrustworthy ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              medicine.isTrustworthy 
                  ? "This medicine information appears to be reliable based on our analysis. However, always verify with a healthcare professional."
                  : "The reliability of this medicine information could not be fully verified. Please consult a healthcare professional or pharmacist for accurate information.",
              style: TextStyle(
                color: medicine.isTrustworthy ? Colors.green[200] : Colors.orange[200],
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createReminder(BuildContext context) {
    // Extract the dosage information from the medicine info
    final dosage = medicine.dosage.contains('Consult') 
        ? '1 dose' 
        : medicine.dosage.split('.').first;
    
    // Create a new reminder with pre-filled information from the medicine
    final reminder = MedicationReminder(
      id: NotificationService.instance.generateUniqueId(),
      medicineName: medicine.name,
      dosage: dosage,
      scheduledTime: DateTime.now().add(const Duration(minutes: 15)),
      notes: 'Based on scanned medicine: ${medicine.name}',
    );
    
    // Navigate to the add reminder screen with pre-filled data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          existingReminder: reminder,
        ),
      ),
    );
  }
} 