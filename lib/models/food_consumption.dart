import 'food_item.dart';

class FoodConsumption {
  final String foodName;
  final FoodItem foodItem;
  final DateTime dateConsumed;
  final Map<String, double> nutrients;
  final String source;
  final String imagePath;
  final List<String>? allergens;

  FoodConsumption({
    required this.foodItem,
    String? foodName,
    required this.dateConsumed,
    Map<String, double>? nutrients,
    this.source = "",
    this.imagePath = "",
    List<String>? allergens,
  })  : this.foodName = foodName ?? foodItem.name,
        this.nutrients = nutrients ?? foodItem.calculateTotalNutrients(),
        this.allergens = allergens ?? foodItem.allergens;

  Map<String, dynamic> toJson() => {
        'foodName': foodName,
        'dateTime': dateConsumed.toIso8601String(),
        'nutrients': nutrients,
        'source': source,
        'imagePath': imagePath,
        'allergens': allergens,
        // Store essential FoodItem properties for reconstruction
        'foodItemData': {
          'name': foodItem.name,
          'quantity': foodItem.quantity,
          'unit': foodItem.unit,
          'nutrientsPer100g': foodItem.nutrientsPer100g,
          'brand': foodItem.brand,
          'barcode': foodItem.barcode,
          'ingredients': foodItem.ingredients,
          'imageUrl': foodItem.imageUrl,
          'dateAdded': foodItem.dateAdded.toIso8601String(),
          'allergens': foodItem.allergens,
        },
      };

  factory FoodConsumption.fromJson(Map<String, dynamic> json) {
    // Convert nutrients to proper type
    Map<String, double> nutrients = {};
    if (json['nutrients'] != null) {
      (json['nutrients'] as Map<String, dynamic>).forEach((key, value) {
        nutrients[key] = (value as num).toDouble();
      });
    }

    // Extract allergens
    List<String>? allergens;
    if (json['allergens'] != null) {
      if (json['allergens'] is List) {
        allergens = List<String>.from(json['allergens']);
      } else if (json['allergens'] is String) {
        allergens = (json['allergens'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }

    // Reconstruct FoodItem from stored data
    final foodItemData = json['foodItemData'] as Map<String, dynamic>? ?? {};
    
    // Extract allergens from foodItemData
    List<String>? foodItemAllergens;
    if (foodItemData['allergens'] != null) {
      if (foodItemData['allergens'] is List) {
        foodItemAllergens = List<String>.from(foodItemData['allergens']);
      } else if (foodItemData['allergens'] is String) {
        foodItemAllergens = (foodItemData['allergens'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }
    
    final foodItem = FoodItem(
      name: foodItemData['name'] as String? ?? json['foodName'] as String? ?? '',
      quantity: (foodItemData['quantity'] as num?)?.toDouble() ?? 100.0,
      unit: foodItemData['unit'] as String? ?? 'g',
      nutrientsPer100g: (foodItemData['nutrientsPer100g'] as Map<String, dynamic>?) ?? {},
      brand: foodItemData['brand'] as String?,
      barcode: foodItemData['barcode'] as String?,
      ingredients: foodItemData['ingredients'] as String?,
      imageUrl: foodItemData['imageUrl'] as String?,
      dateAdded: foodItemData['dateAdded'] != null 
          ? DateTime.parse(foodItemData['dateAdded'] as String)
          : null,
      allergens: foodItemAllergens,
    );

    return FoodConsumption(
      foodItem: foodItem,
      foodName: json['foodName'] as String?,
      dateConsumed: DateTime.parse(json['dateTime'] as String? ?? DateTime.now().toIso8601String()),
      nutrients: nutrients,
      source: json['source'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      allergens: allergens,
    );
  }
}
