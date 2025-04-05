import 'dart:convert';

class MedicineInfo {
  final String name;
  final String description;
  final String commonUses;
  final String criticalInfo;
  final String? imageUrl;
  final String dosage;
  final String interactions;
  final String sideEffects;
  final bool isTrustworthy;

  MedicineInfo({
    required this.name,
    required this.description,
    required this.commonUses,
    required this.criticalInfo,
    this.imageUrl,
    this.dosage = 'Consult a healthcare professional for proper dosage.',
    this.interactions = 'Information not available on packaging.',
    this.sideEffects = 'Not specified on packaging.',
    this.isTrustworthy = false,
  });

  factory MedicineInfo.fromJson(Map<String, dynamic> json) {
    return MedicineInfo(
      name: json['medicine_name'] ?? 'Unknown Medicine',
      description: json['brief_description'] ?? 'No description available',
      commonUses: json['common_uses'] ?? 'Not specified',
      criticalInfo: json['critical_information'] ?? 'No critical information available',
      imageUrl: json['image_url'],
      dosage: json['dosage'] ?? 'Consult a healthcare professional for proper dosage.',
      interactions: json['interactions'] ?? 'Information not available on packaging.',
      sideEffects: json['side_effects'] ?? 'Not specified on packaging.',
      isTrustworthy: json['is_trustworthy'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': name,
      'brief_description': description,
      'common_uses': commonUses,
      'critical_information': criticalInfo,
      'image_url': imageUrl,
      'dosage': dosage,
      'interactions': interactions,
      'side_effects': sideEffects,
      'is_trustworthy': isTrustworthy,
    };
  }

  // Helper method for saving to shared preferences
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Helper method for loading from shared preferences
  static MedicineInfo fromJsonString(String jsonString) {
    return MedicineInfo.fromJson(jsonDecode(jsonString));
  }
} 