import 'dart:convert';

class MedicationReminder {
  final int id;
  final String medicineName;
  final String dosage;
  final DateTime scheduledTime;
  final bool repeat;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final String notes;
  final bool enabled;

  MedicationReminder({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.scheduledTime,
    this.repeat = false,
    this.daysOfWeek = const [],
    this.notes = '',
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime.toIso8601String(),
      'repeat': repeat,
      'daysOfWeek': daysOfWeek,
      'notes': notes,
      'enabled': enabled,
    };
  }

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'],
      medicineName: json['medicineName'],
      dosage: json['dosage'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      repeat: json['repeat'] ?? false,
      daysOfWeek: List<int>.from(json['daysOfWeek'] ?? []),
      notes: json['notes'] ?? '',
      enabled: json['enabled'] ?? true,
    );
  }

  MedicationReminder copyWith({
    int? id,
    String? medicineName,
    String? dosage,
    DateTime? scheduledTime,
    bool? repeat,
    List<int>? daysOfWeek,
    String? notes,
    bool? enabled,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      repeat: repeat ?? this.repeat,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
    );
  }

  String getFormattedTime() {
    final hour = scheduledTime.hour;
    final minute = scheduledTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
  
  String getFormattedDate() {
    return '${scheduledTime.day}/${scheduledTime.month}/${scheduledTime.year}';
  }
  
  String getFrequencyText() {
    if (!repeat) return 'Once on ${getFormattedDate()}';
    
    if (daysOfWeek.length == 7) return 'Daily';
    
    if (daysOfWeek.length == 0) return 'Once';
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDays = daysOfWeek.map((day) => dayNames[day - 1]).join(', ');
    
    return 'Every $selectedDays';
  }
} 