import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication_reminder.dart';
import '../services/notification_service.dart';
import 'add_reminder_screen.dart';
import 'medicine_scanner_screen.dart';

class MedicationRemindersScreen extends StatefulWidget {
  const MedicationRemindersScreen({Key? key}) : super(key: key);

  @override
  State<MedicationRemindersScreen> createState() => _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState extends State<MedicationRemindersScreen> {
  List<MedicationReminder> _reminders = [];
  List<MedicationReminder> _dueReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reminders = await NotificationService.instance.getReminders();
      final dueReminders = reminders.where((reminder) => 
          NotificationService.instance.isReminderDue(reminder)).toList();
      
      setState(() {
        _reminders = reminders;
        _dueReminders = dueReminders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Medication Reminders', 
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.medication, color: Colors.white),
            tooltip: 'Medicine Scanner',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MedicineScannerScreen(),
                ),
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFF2DCCA7),
            ))
          : _reminders.isEmpty
              ? _buildEmptyState()
              : _buildRemindersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOptions,
        backgroundColor: const Color(0xFF2DCCA7),
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Option",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOption(
                    icon: Icons.add_alarm,
                    label: "Add Reminder",
                    onTap: () {
                      Navigator.pop(context);
                      _addReminder();
                    },
                  ),
                  _buildOption(
                    icon: Icons.medication,
                    label: "Scan Medicine",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MedicineScannerScreen(),
                        ),
                      );
                    },
                  ),
                  _buildOption(
                    icon: Icons.refresh,
                    label: "Refresh",
                    onTap: () {
                      Navigator.pop(context);
                      _loadReminders();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2DCCA7).withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF2DCCA7),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No medication reminders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first reminder',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList() {
    // Sort reminders by time
    _reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_dueReminders.isNotEmpty) _buildDueRemindersSection(),
        
        const SizedBox(height: 16),
        
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'All Reminders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        
        ..._reminders.map((reminder) => _buildReminderCard(reminder)),
      ],
    );
  }

  Widget _buildDueRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Due Now',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2DCCA7),
              fontFamily: 'Poppins',
            ),
          ),
        ),
        
        ..._dueReminders.map((reminder) => 
          _buildReminderCard(reminder, isDue: true),
        ),
      ],
    );
  }

  Widget _buildReminderCard(MedicationReminder reminder, {bool isDue = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isDue ? const Color(0xFF1A1A1A) : const Color(0xFF252525),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDue ? const Color(0xFF2DCCA7) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reminder.medicineName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: reminder.enabled,
                  activeColor: const Color(0xFF2DCCA7),
                  onChanged: (value) => _toggleReminder(reminder.id, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.medication, color: const Color(0xFF2DCCA7).withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  reminder.dosage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: const Color(0xFF2DCCA7).withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  reminder.getFormattedTime(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.repeat, color: const Color(0xFF2DCCA7).withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  reminder.getFrequencyText(),
                  style: const TextStyle(
                    fontSize: 16, 
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            if (reminder.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: const Color(0xFF2DCCA7).withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminder.notes,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                isDue ? 
                TextButton.icon(
                  icon: const Icon(Icons.check_circle, color: Color(0xFF2DCCA7)),
                  label: const Text(
                    'MARK AS TAKEN',
                    style: TextStyle(
                      color: Color(0xFF2DCCA7),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  onPressed: () {
                    // For now, just tell the user it's marked
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Marked ${reminder.medicineName} as taken!'),
                        backgroundColor: const Color(0xFF2DCCA7),
                      ),
                    );
                    _loadReminders(); // Reload to refresh the due list
                  },
                )
                : const SizedBox(),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _editReminder(reminder),
                  child: const Text(
                    'EDIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _deleteReminder(reminder.id),
                  child: Text(
                    'DELETE',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReminder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddReminderScreen(),
      ),
    );

    if (result == true) {
      _loadReminders();
    }
  }

  Future<void> _editReminder(MedicationReminder reminder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          existingReminder: reminder,
        ),
      ),
    );

    if (result == true) {
      _loadReminders();
    }
  }

  Future<void> _toggleReminder(int id, bool enabled) async {
    await NotificationService.instance.toggleReminderEnabled(id, enabled);
    _loadReminders();
  }

  Future<void> _deleteReminder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'Delete Reminder',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        content: const Text(
          'Are you sure you want to delete this reminder?',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: TextStyle(color: Colors.red[400], fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationService.instance.removeReminder(id);
      _loadReminders();
    }
  }
} 