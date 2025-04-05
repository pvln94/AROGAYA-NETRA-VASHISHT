import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication_reminder.dart';
import '../services/notification_service.dart';

class AddReminderScreen extends StatefulWidget {
  final MedicationReminder? existingReminder;

  const AddReminderScreen({Key? key, this.existingReminder}) : super(key: key);

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  late TimeOfDay _selectedTime;
  bool _repeat = false;
  final List<bool> _selectedDays = List.generate(7, (_) => false);
  bool _isEditing = false;
  late int _reminderId;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingReminder != null) {
      _isEditing = true;
      final reminder = widget.existingReminder!;
      
      _medicineNameController.text = reminder.medicineName;
      _dosageController.text = reminder.dosage;
      _notesController.text = reminder.notes;
      _selectedTime = TimeOfDay(
        hour: reminder.scheduledTime.hour,
        minute: reminder.scheduledTime.minute,
      );
      _repeat = reminder.repeat;
      
      // Set selected days
      for (final day in reminder.daysOfWeek) {
        if (day >= 1 && day <= 7) {
          _selectedDays[day - 1] = true;
        }
      }
      
      _reminderId = reminder.id;
    } else {
      _selectedTime = TimeOfDay.now();
      _reminderId = NotificationService.instance.generateUniqueId();
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          _isEditing ? 'Edit Reminder' : 'Add Reminder',
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMedicineNameField(),
            const SizedBox(height: 16),
            _buildDosageField(),
            const SizedBox(height: 16),
            _buildTimeSelector(),
            const SizedBox(height: 16),
            _buildRepeatOption(),
            if (_repeat) ...[
              const SizedBox(height: 16),
              _buildDaySelector(),
            ],
            const SizedBox(height: 16),
            _buildNotesField(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineNameField() {
    return TextFormField(
      controller: _medicineNameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Medicine Name',
        labelStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2DCCA7)),
        ),
        prefixIcon: const Icon(Icons.medication, color: Color(0xFF2DCCA7)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter medicine name';
        }
        return null;
      },
    );
  }

  Widget _buildDosageField() {
    return TextFormField(
      controller: _dosageController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Dosage (e.g., "1 tablet", "5ml")',
        labelStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2DCCA7)),
        ),
        prefixIcon: const Icon(Icons.medication_liquid, color: Color(0xFF2DCCA7)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter dosage information';
        }
        return null;
      },
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Time',
          labelStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          prefixIcon: const Icon(Icons.access_time, color: Color(0xFF2DCCA7)),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
        ),
        child: Text(
          _formatTimeOfDay(_selectedTime),
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRepeatOption() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: SwitchListTile(
        title: const Text(
          'Repeat Reminder', 
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        subtitle: Text(
          _repeat ? 'Reminder will repeat on selected days' : 'Reminder will occur once',
          style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
        ),
        value: _repeat,
        activeColor: const Color(0xFF2DCCA7),
        onChanged: (value) {
          setState(() {
            _repeat = value;
          });
        },
      ),
    );
  }

  Widget _buildDaySelector() {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat on:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedDays[index] = !_selectedDays[index];
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _selectedDays[index] ? const Color(0xFF2DCCA7) : Colors.grey[800],
                child: Text(
                  dayLabels[index],
                  style: TextStyle(
                    color: _selectedDays[index] ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Notes (optional)',
        labelStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2DCCA7)),
        ),
        prefixIcon: const Icon(Icons.note, color: Color(0xFF2DCCA7)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
      ),
      maxLines: 3,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveReminder,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2DCCA7),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        _isEditing ? 'UPDATE REMINDER' : 'SAVE REMINDER',
        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2DCCA7),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF252525),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _saveReminder() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    // Get selected days if repeating
    final List<int> daysOfWeek = [];
    if (_repeat) {
      for (int i = 0; i < _selectedDays.length; i++) {
        if (_selectedDays[i]) {
          daysOfWeek.add(i + 1); // 1 = Monday, 7 = Sunday
        }
      }
    }
    
    // Create a DateTime for today with the selected time
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    
    // Create reminder object
    final reminder = MedicationReminder(
      id: _reminderId,
      medicineName: _medicineNameController.text.trim(),
      dosage: _dosageController.text.trim(),
      scheduledTime: scheduledTime,
      repeat: _repeat,
      daysOfWeek: daysOfWeek,
      notes: _notesController.text.trim(),
    );
    
    // Save reminder
    await NotificationService.instance.addReminder(reminder);
    
    // Show confirmation and return to previous screen
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_isEditing ? 'Updated' : 'Saved'} reminder for ${reminder.medicineName}',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: const Color(0xFF2DCCA7),
        ),
      );
      Navigator.pop(context, true);
    }
  }
} 