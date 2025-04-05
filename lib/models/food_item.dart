import 'health_score.dart';

class FoodItem {
  final String name;
  final String? brand;
  final String? barcode;
  double quantity;
  final String unit;
  final Map<String, dynamic> nutrientsPer100g;
  final String? ingredients;
  final String? imageUrl;
  final DateTime dateAdded;
  final List<String>? allergens;
  HealthScore? healthScore;

  FoodItem({
    required this.name,
    this.brand,
    this.barcode,
    required this.quantity,
    required this.unit,
    required this.nutrientsPer100g,
    this.ingredients,
    this.imageUrl,
    DateTime? dateAdded,
    this.allergens,
    this.healthScore,
  }) : this.dateAdded = dateAdded ?? DateTime.now();

  Map<String, double> calculateTotalNutrients() {
    final factor = quantity / 100; // Convert to 100g basis
    return {
      'calories': (nutrientsPer100g['calories'] ?? 0) * factor,
      'protein': (nutrientsPer100g['protein'] ?? 0) * factor,
      'carbohydrates': (nutrientsPer100g['carbohydrates'] ?? 0) * factor,
      'fat': (nutrientsPer100g['fat'] ?? 0) * factor,
      'fiber': (nutrientsPer100g['fiber'] ?? 0) * factor,
    };
  }

  void updateQuantity(double newQuantity) {
    quantity = newQuantity;
  }

  void setHealthScore(HealthScore score) {
    healthScore = score;
  }

  bool get hasHealthScore => healthScore != null;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final nutrients = json['nutrients'] ?? {};
    
    final Map<String, dynamic> standardizedNutrients = {
      'calories': nutrients['calories'] ?? 0,
      'protein': nutrients['protein'] ?? 0,
      'carbohydrates': nutrients['carbohydrates'] ?? 0,
      'fat': nutrients['total_fat'] ?? 0,
      'fiber': nutrients['fiber'] ?? 0,
      'sugar': nutrients['sugars'] ?? 0,
      'sodium': nutrients['sodium'] ?? 0,
      'potassium': nutrients['potassium'] ?? 0,
      'calcium': nutrients['calcium'] ?? 0,
      'vitamin_a': nutrients['vitamin_a'] ?? 0,
      'vitamin_c': nutrients['vitamin_c'] ?? 0,
      'iron': nutrients['iron'] ?? 0,
    };

    DateTime? parsedDate;
    if (json['dateAdded'] != null) {
      try {
        parsedDate = DateTime.parse(json['dateAdded']);
      } catch (e) {
        print('Error parsing date: $e');
        parsedDate = DateTime.now();
      }
    }

    List<String>? allergensList;
    if (json['allergens'] != null) {
      if (json['allergens'] is List) {
        allergensList = List<String>.from(json['allergens']);
      } else if (json['allergens'] is String) {
        allergensList = (json['allergens'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }
    
    HealthScore? healthScore;
    if (json['healthScore'] != null) {
      try {
        healthScore = HealthScore.fromJson(json['healthScore']);
      } catch (e) {
        print('Error parsing health score: $e');
      }
    }

    return FoodItem(
      name: json['name'] ?? 'Unknown Product',
      brand: json['brand'],
      barcode: json['barcode'],
      quantity: 100.0,
      unit: json['unit'] ?? 'g',
      nutrientsPer100g: standardizedNutrients,
      ingredients: json['ingredients'],
      imageUrl: json['imageUrl'],
      dateAdded: parsedDate,
      allergens: allergensList,
      healthScore: healthScore,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'barcode': barcode,
      'quantity': quantity,
      'unit': unit,
      'nutrientsPer100g': nutrientsPer100g,
      'ingredients': ingredients,
      'imageUrl': imageUrl,
      'dateAdded': dateAdded.toIso8601String(),
      'allergens': allergens,
      'healthScore': healthScore?.toJson(),
    };
  }
}
