import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/medication_reminder.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();
  final String _remindersStorageKey = 'medication_reminders';

  List<MedicationReminder> _reminders = [];

  NotificationService._();

  Future<void> init() async {
    // Load saved reminders
    await _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = prefs.getString(_remindersStorageKey);
    
    if (remindersJson != null) {
      try {
        final List<dynamic> remindersList = jsonDecode(remindersJson);
        _reminders = remindersList
            .map((json) => MedicationReminder.fromJson(json))
            .toList();
      } catch (e) {
        debugPrint('Error loading reminders: $e');
        _reminders = [];
      }
    }
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = jsonEncode(_reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_remindersStorageKey, remindersJson);
  }

  Future<List<MedicationReminder>> getReminders() async {
    await _loadReminders();
    return _reminders;
  }

  Future<void> addReminder(MedicationReminder reminder) async {
    // Add to list, overwriting if it already exists
    final existingIndex = _reminders.indexWhere((r) => r.id == reminder.id);
    if (existingIndex >= 0) {
      _reminders[existingIndex] = reminder;
    } else {
      _reminders.add(reminder);
    }
    
    // Save
    await _saveReminders();
  }

  Future<void> removeReminder(int id) async {
    _reminders.removeWhere((r) => r.id == id);
    await _saveReminders();
  }

  Future<void> toggleReminderEnabled(int id, bool enabled) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index >= 0) {
      // Update the reminder
      final updatedReminder = _reminders[index].copyWith(enabled: enabled);
      _reminders[index] = updatedReminder;
      await _saveReminders();
    }
  }
  
  // Generate a unique ID for new reminders
  int generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }
  
  // Check if a reminder is due
  bool isReminderDue(MedicationReminder reminder) {
    if (!reminder.enabled) {
      return false;
    }
    
    final now = DateTime.now();
    final scheduledTime = reminder.scheduledTime;
    
    // For non-repeating reminders
    if (!reminder.repeat) {
      // If the scheduled time is in the past and within the last hour
      return scheduledTime.isBefore(now) && 
             now.difference(scheduledTime).inHours < 1;
    }
    
    // For repeating reminders
    if (reminder.daysOfWeek.isEmpty || reminder.daysOfWeek.contains(now.weekday)) {
      // Check if current time is within 1 hour of the scheduled time
      final todayScheduledTime = DateTime(
        now.year, now.month, now.day,
        scheduledTime.hour, scheduledTime.minute
      );
      
      final diff = now.difference(todayScheduledTime);
      return diff.inHours.abs() < 1 && diff.isNegative == false;
    }
    
    return false;
  }
  
  // Get due reminders
  List<MedicationReminder> getDueReminders() {
    return _reminders.where((reminder) => isReminderDue(reminder)).toList();
  }
} 