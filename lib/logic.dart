import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart'; // Add this import
import 'package:read_the_label/models/food_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:read_the_label/models/health_score.dart'; // Added import
import 'package:read_the_label/services/health_score_service.dart'; // Added import

import 'data/dv_values.dart';
import 'models/food_consumption.dart';

class Logic {
  String _generatedText = "";
  dynamic _frontImage;
  dynamic _nutritionLabelImage;
  dynamic get frontImage => _frontImage;
  dynamic get nutritionLabelImage => _nutritionLabelImage;
  List<Map<String, dynamic>> parsedNutrients = [];
  List<Map<String, dynamic>> goodNutrients = [];
  List<Map<String, dynamic>> badNutrients = [];
  dynamic foodImage;
  List<FoodItem> analyzedFoodItems = [];
  Map<String, dynamic> totalPlateNutrients = {};
  double _servingSize = 0.0;
  double sliderValue = 0.0;
  Map<String, double> dailyIntake = {};
  bool _isLoading = false;
  static final navKey = GlobalKey<NavigatorState>();
  Function(void Function())? _mySetState;
  String _productName = "";
  String get productName => _productName;
  Map<String, dynamic> _nutritionAnalysis = {};
  Map<String, dynamic> get nutritionAnalysis => _nutritionAnalysis;
  List<FoodConsumption> _foodHistory = [];
  List<FoodConsumption> get foodHistory => _foodHistory;
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> mealNameNotifier = ValueNotifier<String>("");
  final dailyIntakeNotifier = ValueNotifier<Map<String, double>>({});

  // For allergens
  List<String> _userAllergens = [];
  List<String> get userAllergens => _userAllergens;
  final ValueNotifier<List<String>> allergensNotifier = ValueNotifier<List<String>>([]);
  final ValueNotifier<bool> hasAllergenWarningNotifier = ValueNotifier<bool>(false);
  List<String> _detectedAllergens = [];
  List<String> get detectedAllergens => _detectedAllergens;

  // String _mealName = "";
  // String get mealName => _mealName;
  String get mealName => mealNameNotifier.value;
  set _mealName(String value) {
    mealNameNotifier.value = value;
  }

  @override
  void dispose() {
    mealNameNotifier.dispose();
    loadingNotifier.dispose();
  }

  bool get isAnalyzing => loadingNotifier.value;
  set _isAnalyzing(bool value) {
    loadingNotifier.value = value;
  }

  String? getApiKey() {
    try {
      if (kIsWeb) {
        // For web, return the hardcoded API key
        return 'AIzaSyA91Qu8C8xDq_cpr0zYIhT00UMlUWXD0Lc';
      } else {
        // For mobile, get from .env file
        final key = dotenv.env['GEMINI_API_KEY'];
        if (key == null || key.isEmpty) {
          throw Exception('GEMINI_API_KEY not found in .env file');
        }
        return key;
      }
    } catch (e) {
      debugPrint('Error loading API key: $e');
      return null;
    }
  }

  String getStorageKey(DateTime date) {
    // Standardize the storage key format
    return 'dailyIntake_${date.year}-${date.month}-${date.day}';
  }

  Future<void> debugCheckStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Get all keys
    final keys = prefs.getKeys();
    print("All SharedPreferences keys: $keys");

    // Print food history
    final foodHistoryData = prefs.getString('food_history');
    print("Stored food history: $foodHistoryData");

    // Print daily intakes for last 7 days
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final key = 'dailyIntake_${date.year}-${date.month}-${date.day}';
      final data = prefs.getString(key);
      print("Daily intake for ${date.toString().split(' ')[0]}: $data");
    }
  }

  Future<void> saveDailyIntake() async {
    try {
      print("✅Start of saveDailyIntake()");
      print("⚡Daily intake at the start of saveDailyIntake(): $dailyIntake");
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final storageKey = getStorageKey(today);

      // Get existing data first
      final existingData = prefs.getString(storageKey);
      Map<String, double> updatedIntake = {};

      if (existingData != null) {
        final decoded = jsonDecode(existingData) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          updatedIntake[key] = (value as num).toDouble();
        });
      }

      // Merge existing data with new data
      dailyIntake.forEach((key, value) {
        updatedIntake[key] = (updatedIntake[key] ?? 0.0) + value;
      });

      print("Saving daily intake with key: $storageKey");
      print("Data being saved: $updatedIntake");

      await prefs.setString(storageKey, jsonEncode(updatedIntake));
      dailyIntake = updatedIntake; // Update the current dailyIntake

      // Verify the save
      final savedData = prefs.getString(storageKey);
      print("Verification - Saved data: $savedData");
      print("⚡Daily intake at the end of saveDailyIntake(): $dailyIntake");
      print("✅End of saveDailyIntake()");
    } catch (e) {
      print("Error saving daily intake: $e");
    }
  }

  Future<void> addToFoodHistory({
    required String foodName,
    required Map<String, double> nutrients,
    required String source,
    required String imagePath,
  }) async {
    print("✅Start of addToFoodHistory()");
    print("⚡Daily intake at start of addToFoodHistory(): $dailyIntake");
    print("Adding to food history: $foodName");
    print("With nutrients: $nutrients");
    print("Source: $source");
    print("Image path: $imagePath");

    // Load existing history first
    await loadFoodHistory();

    try {
      // Create a basic FoodItem to be stored in the consumption
      final foodItem = FoodItem(
        name: foodName,
        quantity: 100.0,
        unit: "g",
        nutrientsPer100g: nutrients.map((key, value) => MapEntry(key, value)),
      );
      
      final consumption = FoodConsumption(
        foodItem: foodItem,
        foodName: foodName,
        dateConsumed: DateTime.now(),
        nutrients: nutrients,
        source: source,
        imagePath: '',
      );

      // Add new item to existing history
      _foodHistory.add(consumption);
      print("Updated food history length: ${_foodHistory.length}");

      await _saveFoodHistory();
      print("✅End of addToFoodHistory()");
      print("⚡Daily intake at end of addToFoodHistory(): $dailyIntake");
    } catch (e) {
      print("Error adding to food history: $e");
    }
  }

  Future<void> loadFoodHistory() async {
    print("✅Start of loadFoodHistory()");
    print("⚡Daily intake: $dailyIntake");
    print("Loading food history from storage...");
    final prefs = await SharedPreferences.getInstance();
    final String? storedHistory = prefs.getString('food_history');

    if (storedHistory != null) {
      print("Found stored food history");
      try {
        final List<dynamic> decoded = jsonDecode(storedHistory);
        print("Decoded food history items: ${decoded.length}");

        // Create new list instead of clearing existing one
        _foodHistory =
            decoded.map((item) => FoodConsumption.fromJson(item)).toList();

        print("Successfully loaded ${_foodHistory.length} food items");
        _foodHistory.forEach((item) {
          print("Loaded item: ${item.foodName} on ${item.dateConsumed}");
        });
        print("⚡Daily intake: $dailyIntake");
        print("✅End of loadFoodHistory()");
      } catch (e) {
        print("Error loading food history: $e");
        _foodHistory = [];
      }
    } else {
      print("No stored food history found");
      _foodHistory = [];
    }
  }

  Future<void> _saveFoodHistory() async {
    try {
      print("✅Start of _saveFoodHistory()");
      print("⚡Daily intake at start of _saveFoodHistory(): $dailyIntake");
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _foodHistory.map((item) => item.toJson()).toList();
      print("Saving food history with ${historyJson.length} items");

      await prefs.setString('food_history', jsonEncode(historyJson));

      // Verify the save
      final savedData = prefs.getString('food_history');
      final decodedSave =
          savedData != null ? jsonDecode(savedData) as List : [];
      print("Verification - Saved food history items: ${decodedSave.length}");
      print("⚡Daily intake at end of _saveFoodHIistory(): $dailyIntake");
      print("✅End of _saveFoodHistory()");
    } catch (e) {
      print("Error saving food history: $e");
    }
  }

  Future<void> addToDailyIntake(
      BuildContext context, Function(int) updateIndex, String source) async {
    dailyIntake = {};
    print("Adding to daily intake. Source: $source");
    print("Current daily intake before: $dailyIntake");
    print("✅Start of addToDailyIntake()");
    print("⚡Daily intake at start of addToDailyIntake(): $dailyIntake");

    Map<String, double> newNutrients = {};
    dynamic imageFile;

    if (source == 'label' && parsedNutrients.isNotEmpty) {
      for (var nutrient in parsedNutrients) {
        final name = nutrient['name'];
        final quantity = double.tryParse(
                nutrient['quantity'].replaceAll(RegExp(r'[^0-9\.]'), '')) ??
            0;
        double adjustedQuantity = quantity * (sliderValue / _servingSize);
        newNutrients[name] = adjustedQuantity;
      }
      imageFile = _frontImage;
    } else if (source == 'food' && totalPlateNutrients.isNotEmpty) {
      newNutrients = {
        'Energy': (totalPlateNutrients['calories'] ?? 0).toDouble(),
        'Protein': (totalPlateNutrients['protein'] ?? 0).toDouble(),
        'Carbohydrate': (totalPlateNutrients['carbohydrates'] ?? 0).toDouble(),
        'Fat': (totalPlateNutrients['fat'] ?? 0).toDouble(),
        'Fiber': (totalPlateNutrients['fiber'] ?? 0).toDouble(),
      };
      imageFile = foodImage;
    }

    // Save the image to the device storage
    String imagePath = '';
    if (imageFile != null) {
      if (!kIsWeb) {
        // File operations only work on mobile platforms
        final directory = await getApplicationDocumentsDirectory();
        final imageName = '${DateTime.now().millisecondsSinceEpoch}.png';
        
        // Make sure imageFile is a File before using copy method
        if (imageFile is File) {
          final savedImage = await imageFile.copy('${directory.path}/$imageName');
          imagePath = savedImage.path;
        } else {
          debugPrint('Warning: imageFile is not a File object on mobile platform');
          imagePath = 'unknown_image_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else {
        // For web, we can't save files to local storage in the same way
        // We could use browser storage APIs if needed, but for now just skip this step
        imagePath = 'web_image_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('Skipping file save operation on web platform');
      }
    }

    // Update dailyIntake with new nutrients
    newNutrients.forEach((key, value) {
      dailyIntake[key] = (dailyIntake[key] ?? 0.0) + value;
    });

    await addToFoodHistory(
      foodName: source == 'label' ? _productName : mealName,
      nutrients: newNutrients,
      source: source,
      imagePath: imagePath,
    );

    await saveDailyIntake();
    dailyIntakeNotifier.value = Map.from(dailyIntake);
    print("⚡Daily intake at end of addToDailyIntake(): $dailyIntake");
    print("✅End of addToDailyIntake()");

    updateIndex(2);
  }

  double getServingSize() => _servingSize;
  List<Map<String, dynamic>> getGoodNutrients() => goodNutrients;
  List<Map<String, dynamic>> getBadNutrients() => badNutrients;

  bool getIsLoading() => _isLoading;

  void setSetState(Function(void Function()) setState) {
    _mySetState = setState;
  }

  void setState(Function() callback) {
    if (_mySetState != null) {
      _mySetState!(callback);
    }
  }

  void updateSliderValue(double newValue, Function(void Function()) setState) {
    sliderValue = newValue;
    setState(() {});
  }

  static GlobalKey<NavigatorState> getNavKey() => navKey;

  String? getInsights(Map<String, double> dailyIntake) {
    for (var nutrient in nutrientData) {
      String nutrientName = nutrient['Nutrient'];
      if (dailyIntake.containsKey(nutrientName)) {
        try {
          double dvValue = double.parse(nutrient['Current Daily Value']
              .replaceAll(RegExp(r'[^0-9\.]'), ''));
          double percent = dailyIntake[nutrientName]! / dvValue;
          if (percent > 1.0) {
            return "You have exceeded the recommended daily intake of $nutrientName";
          }
        } catch (e) {
          print("Error parsing to double: $e");
        }
      }
    }
    return null;
  }

  void updateServingSize(double newSize) {
    _servingSize = newSize;
    // Reset slider value when serving size changes
    sliderValue = 0.0;
    setState(() {});
  }

  double getCalories() {
    var energyNutrient = parsedNutrients.firstWhere(
      (nutrient) => nutrient['name'] == 'Energy',
      orElse: () => {'quantity': '0.0'},
    );
    // Parse the quantity string to remove any non-numeric characters except decimal points
    var quantity = energyNutrient['quantity']
        .toString()
        .replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(quantity) ?? 0.0;
  }

  String getUnit(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'energy':
        return ' kcal';
      case 'protein':
      case 'carbohydrate':
      case 'fat':
      case 'fiber':
      case 'sugar':
        return 'g';
      case 'sodium':
      case 'potassium':
      case 'calcium':
      case 'iron':
        return 'mg';
      default:
        return '';
    }
  }

  IconData getNutrientIcon(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'energy':
        return Icons.bolt;
      case 'protein':
        return Icons.fitness_center;
      case 'carbohydrate':
        return Icons.grain;
      case 'fat':
        return Icons.opacity;
      case 'fiber':
        return Icons.grass;
      case 'sodium':
        return Icons.water_drop;
      case 'calcium':
        return Icons.shield;
      case 'iron':
        return Icons.architecture;
      case 'vitamin':
        return Icons.brightness_high;
      default:
        return Icons.science;
    }
  }

  Color getColorForPercent(double percent, BuildContext context) {
    if (percent > 1.0) return Colors.red; // Exceeded daily value
    if (percent > 0.8) return Colors.green; // High but not exceeded
    if (percent > 0.6) return Colors.yellow; // Moderate
    if (percent > 0.4) return Colors.yellow; // Low to moderate
    return Colors.green; // Low
  }

  Future<String> analyzeImages(
      {required Function(void Function()) setState}) async {
    _isLoading = true;
    setState(() {});

    final apiKey = getApiKey();

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey!);

    // Handle image bytes differently for web and mobile
    late final Uint8List frontImageBytes;
    late final Uint8List labelImageBytes;
    
    if (kIsWeb) {
      try {
        // For web, we need to use a different approach
        final frontHtmlFile = _frontImage as dynamic;
        final labelHtmlFile = _nutritionLabelImage as dynamic;
        
        if (frontHtmlFile != null && frontHtmlFile.readAsBytes != null &&
            labelHtmlFile != null && labelHtmlFile.readAsBytes != null) {
          frontImageBytes = await frontHtmlFile.readAsBytes();
          labelImageBytes = await labelHtmlFile.readAsBytes();
        } else {
          throw Exception('Unable to read image bytes on web platform');
        }
      } catch (e) {
        debugPrint('Error reading image bytes on web: $e');
        _isLoading = false;
        setState(() {});
        return 'Error: Unable to process images on web. Please try again or use a different image.';
      }
    } else {
      // For mobile platforms, we can use the standard File API
      frontImageBytes = await _frontImage!.readAsBytes();
      labelImageBytes = await _nutritionLabelImage!.readAsBytes();
    }

    final imageParts = [
      DataPart('image/jpeg', frontImageBytes),
      DataPart('image/jpeg', labelImageBytes),
    ];

    // Add user allergens to the prompt context
    String allergensContext = "";
    if (_userAllergens.isNotEmpty) {
      allergensContext = "The user has the following allergens: ${_userAllergens.join(', ')}. ";
      allergensContext += "Please specifically check if the product contains any of these allergens or traces of them.";
    }

    final nutrientParts = nutrientData
        .map((nutrient) => TextPart(
            "${nutrient['Nutrient']}: ${nutrient['Current Daily Value']}"))
        .toList();
    final prompt = TextPart(
        """Analyze the food product, product name and its nutrition label. $allergensContext Provide response in this strict JSON format:
{
  "product": {
    "name": "Product name from front image",
    "category": "Food category (e.g., snack, beverage, etc.)"
  },
  "nutrition_analysis": {
    "serving_size": "Serving size with unit",
    "allergens": ["List of allergens found in the product", "or empty array if none found"],
    "ingredients": "Ingredients list from the product",
    "nutrients": [
      {
        "name": "Nutrient name",
        "quantity": "Quantity with unit",
        "daily_value": "Percentage of daily value",
        "status": "High/Moderate/Low based on DV%",
        "health_impact": "Good/Bad/Moderate"
      }
    ],
    "primary_concerns": [
      {
        "issue": "Primary nutritional concern",
        "explanation": "Brief explanation of health impact",
        "recommendations": [
          {
            "food": "Complementary food suitable to add to this product, consider product name for determining suitability for complementary food additions",
            "quantity": "Recommended quantity to add",
            "reasoning": "How this addition helps balance the nutrition (e.g., slows sugar absorption, adds fiber, reduces glycemic index)"
          }
        ]
      }
    ]
  }
}

Strictly follow these rules:
1. Mention Quantity with units in the label
2. Do not include any extra characters or formatting outside of the JSON object
3. Use accurate escape sequences for any special characters
4. Avoid including nutrients that aren't mentioned in the label
5. For primary_concerns, focus on major nutritional imbalances
6. For recommendations:
   - Suggest foods that can be added to or consumed with the product to improve its nutritional balance
   - Focus on practical additions that complement the main product
   - Explain how each addition helps balance the nutrition (e.g., adding fiber to slow sugar absorption)
   - Consider cultural context and common food pairings
   - Provide specific quantities for the recommended additions
7. Use %DV to determine if a serving is high or low in an individual nutrient:
   5% DV or less is considered low
   20% DV or more is considered high
   5% < DV < 20% is considered moderate
8. For health_impact determination:
   For "At least" nutrients (like fiber, protein):
     High status → Good health_impact
     Moderate status → Moderate health_impact
     Low status → Bad health_impact
   For "Less than" nutrients (like sodium, saturated fat):
     Low status → Good health_impact
     Moderate status → Moderate health_impact
     High status → Bad health_impact
9. For allergens:
   - List all allergens found in the ingredients list
   - Consider common allergens like dairy, nuts, soy, gluten, eggs, shellfish, and wheat
   - Include warnings like "may contain traces of" allergens
""");

    final response = await model.generateContent([
      Content.multi([prompt, ...nutrientParts, ...imageParts])
    ]);

    _generatedText = response.text!;
    print("This is response content: $_generatedText");
    try {
      final jsonString = _generatedText.substring(
          _generatedText.indexOf('{'), _generatedText.lastIndexOf('}') + 1);
      final jsonResponse = jsonDecode(jsonString);

      _productName = jsonResponse['product']['name'];
      _nutritionAnalysis = jsonResponse['nutrition_analysis'];

      if (_nutritionAnalysis.containsKey("serving_size")) {
        _servingSize = double.tryParse(_nutritionAnalysis["serving_size"]
                .replaceAll(RegExp(r'[^0-9\.]'), '')) ??
            0.0;
      }

      parsedNutrients = (_nutritionAnalysis['nutrients'] as List)
          .cast<Map<String, dynamic>>();

      parsedNutrients = (_nutritionAnalysis['nutrients'] as List)
          .cast<Map<String, dynamic>>()
          .map((nutrient) {
        // Handle null values by providing default values
        return {
          'name': nutrient['name'] ?? 'Unknown',
          'quantity': nutrient['quantity'] ?? '0',
          'daily_value': nutrient['daily_value'] ?? '0%',
          'status': nutrient['status'] ?? 'Moderate',
          'health_impact': nutrient['health_impact'] ?? 'Moderate',
        };
      }).toList();

      // Clear and update good/bad nutrients
      goodNutrients.clear();
      badNutrients.clear();
      for (var nutrient in parsedNutrients) {
        if (nutrient["health_impact"] == "Good" ||
            nutrient["health_impact"] == "Moderate") {
          goodNutrients.add(nutrient);
        } else {
          badNutrients.add(nutrient);
        }
      }
      
      // Check for allergens
      checkForAllergens();
      
      // Create a FoodItem and calculate health score
      await _createFoodItemFromAnalysis();
    } catch (e) {
      print("Error parsing JSON: $e");
      _isLoading = false;
      setState(() {});
      return 'Error: Failed to parse analysis. Please try again with a clearer image.';
    }

    _isLoading = false;
    setState(() {});
    return _generatedText;
  }
  
  /// Creates a FoodItem from the analyzed nutrition data and calculates health score
  Future<void> _createFoodItemFromAnalysis() async {
    try {
      // Extract nutrients from parsedNutrients
      Map<String, dynamic> standardizedNutrients = {
        'calories': 0.0,
        'protein': 0.0,
        'carbohydrates': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 0.0,
        'saturated_fat': 0.0,
      };
      
      for (var nutrient in parsedNutrients) {
        String name = nutrient['name'].toString().toLowerCase();
        String quantityStr = nutrient['quantity'].toString();
        double quantity = 0.0;
        
        // Extract numeric value from quantity string
        RegExp regExp = RegExp(r'([-+]?\d*\.?\d+)');
        var match = regExp.firstMatch(quantityStr);
        if (match != null) {
          quantity = double.tryParse(match.group(0) ?? '0') ?? 0.0;
        }
        
        // Map common nutrient names to standardized ones
        if (name.contains('calorie')) {
          standardizedNutrients['calories'] = quantity;
        } else if (name.contains('protein')) {
          standardizedNutrients['protein'] = quantity;
        } else if (name.contains('carb')) {
          standardizedNutrients['carbohydrates'] = quantity;
        } else if (name.contains('fat') && !name.contains('saturated')) {
          standardizedNutrients['fat'] = quantity;
        } else if (name.contains('fiber')) {
          standardizedNutrients['fiber'] = quantity;
        } else if (name.contains('sugar')) {
          standardizedNutrients['sugar'] = quantity;
        } else if (name.contains('sodium')) {
          standardizedNutrients['sodium'] = quantity;
        } else if (name.contains('saturated fat')) {
          standardizedNutrients['saturated_fat'] = quantity;
        }
      }
      
      // Create the food item
      FoodItem foodItem = FoodItem(
        name: _productName,
        quantity: _servingSize > 0 ? _servingSize : 100.0,
        unit: 'g',
        nutrientsPer100g: standardizedNutrients,
        ingredients: _nutritionAnalysis['ingredients'],
        allergens: _nutritionAnalysis['allergens'] is List 
            ? List<String>.from(_nutritionAnalysis['allergens']) 
            : null,
      );
      
      // Calculate and set health score
      await calculateHealthScore(foodItem);
      
      // Add to analyzed food items and clear any previous items
      analyzedFoodItems.clear();
      analyzedFoodItems.add(foodItem);
      
      debugPrint('Created food item with health score: ${foodItem.healthScore?.score.round()} - ${foodItem.healthScore?.rankName}');
    } catch (e) {
      debugPrint('Error creating food item from analysis: $e');
    }
  }

  Future<String> logMealViaText({
    required String foodItemsText,
  }) async {
    try {
      _isAnalyzing = true;

      print("Processing logging food items via text: \n$foodItemsText");
      final apiKey = getApiKey();
      print("Apikey is: ");
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey!,
      );

      final prompt = TextPart(
          """You are a nutrition expert. Analyze these food items and their quantities:\n$foodItemsText\n. Generate nutritional info for each of the mentioned food items and their respective quantities and respond using this JSON schema: 
{
  "meal_analysis": {
  "meal_name": "Name of the meal",
    "items": [
      {
        "food_name": "Name of the food item",
        "mentioned_quantity": {
          "amount": 0,
          "unit": "g",
        },
        "nutrients_per_100g": {
          "calories": 0,
          "protein": {"value": 0, "unit": "g"},
          "carbohydrates": {"value": 0, "unit": "g"},
          "fat": {"value": 0, "unit": "g"},
          "fiber": {"value": 0, "unit": "g"}
        },
        "nutrients_in_mentioned_quantity": {
          "calories": 0,
          "protein": {"value": 0, "unit": "g"},
          "carbohydrates": {"value": 0, "unit": "g"},
          "fat": {"value": 0, "unit": "g"},
          "fiber": {"value": 0, "unit": "g"}
        },
      }
    ],
    "total_nutrients": {
      "calories": 0,
      "protein": {"value": 0, "unit": "g"},
      "carbohydrates": {"value": 0, "unit": "g"},
      "fat": {"value": 0, "unit": "g"},
      "fiber": {"value": 0, "unit": "g"}
    }
  }
}

Important considerations:
1. Use standard USDA database values when available
2. Account for common preparation methods
3. Convert all measurements to standard units
4. Consider regional variations in portion sizes
5. Round values to one decimal place
6. Account for density and volume-to-weight conversions

Provide accurate nutritional data based on the most reliable food databases and scientific sources.
""");
      final response = await model.generateContent([
        Content.multi([prompt])
      ]);
      if (response.text == null) {
        throw Exception("Empty response from model");
      }
      print("\n\nGot response from model!");

      try {
        // Extract JSON from response
        final jsonString = response.text!.substring(
          response.text!.indexOf('{'),
          response.text!.lastIndexOf('}') + 1,
        );
        final jsonResponse = jsonDecode(jsonString);
        final plateAnalysis = jsonResponse['meal_analysis'];
        _mealName = plateAnalysis['meal_name'] ?? 'Unknown Meal';
        // Clear previous analysis
        analyzedFoodItems.clear();

        // Process each food item
        if (plateAnalysis['items'] != null) {
          for (var item in plateAnalysis['items']) {
            // Extract allergens
            List<String> allergens = [];
            if (item['potential_allergens'] != null) {
              if (item['potential_allergens'] is List) {
                allergens = List<String>.from(item['potential_allergens']);
              } else if (item['potential_allergens'] is String) {
                allergens = (item['potential_allergens'] as String)
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
              }
            }
            
            // Create food item
            FoodItem foodItem = FoodItem(
              name: item['food_name'],
              quantity: item['mentioned_quantity']['amount'].toDouble(),
              unit: item['mentioned_quantity']['unit'],
              ingredients: item['ingredients'],
              allergens: allergens,
              nutrientsPer100g: {
                'calories': item['nutrients_per_100g']['calories'],
                'protein': item['nutrients_per_100g']['protein']['value'],
                'carbohydrates': item['nutrients_per_100g']['carbohydrates']['value'],
                'fat': item['nutrients_per_100g']['fat']['value'],
                'fiber': item['nutrients_per_100g']['fiber']['value'],
              },
            );
            
            // Calculate health score for this food item
            await calculateHealthScore(foodItem);
            
            // Add food item to the list
            analyzedFoodItems.add(foodItem);
          }
        }

        // Store total nutrients
        totalPlateNutrients = {
          'calories': plateAnalysis['total_nutrients']['calories'],
          'protein': plateAnalysis['total_nutrients']['protein']['value'],
          'carbohydrates': plateAnalysis['total_nutrients']['carbohydrates']
              ['value'],
          'fat': plateAnalysis['total_nutrients']['fat']['value'],
          'fiber': plateAnalysis['total_nutrients']['fiber']['value'],
        };

        // Print statements to check values
        print("Total Plate Nutrients:");
        print("Calories: ${totalPlateNutrients['calories']}");
        print("Protein: ${totalPlateNutrients['protein']}");
        print("Carbohydrates: ${totalPlateNutrients['carbohydrates']}");
        print("Fat: ${totalPlateNutrients['fat']}");
        print("Fiber: ${totalPlateNutrients['fiber']}");
        _isAnalyzing = false;
        print("\n\nsetting _isLoading to false\n\n");
        return response.text!;
      } catch (e) {
        print("Error analyzing food: $e");
        _isAnalyzing = false;
        return "Error";
      }
    } catch (e) {
      print("Error: $e");
      return "Unexpected error";
    }
  }

  void resetImages() {
    _frontImage = null;
    _nutritionLabelImage = null;
    foodImage = null;
    _productName = "";
    _nutritionAnalysis = {};
    parsedNutrients = [];
    goodNutrients = [];
    badNutrients = [];
    analyzedFoodItems.clear();
    _detectedAllergens = [];
    hasAllergenWarningNotifier.value = false;
    
    if (_mySetState != null) {
      _mySetState!(() {});
    }
  }

  Future<void> processLabel(BuildContext context) async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture an image first')),
      );
      return;
    }

    _isLoading = true;
    if (_mySetState != null) {
      _mySetState!(() {});
    }

    try {
      // Use existing analyzeImages logic or simplified for just label processing
      if (_mySetState != null) {
        await analyzeImages(setState: _mySetState!);
      } else {
        await analyzeImages(setState: (_) {});
      }
    } catch (e) {
      print('Error processing label: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing label: $e')),
      );
    } finally {
      _isLoading = false;
      if (_mySetState != null) {
        _mySetState!(() {});
      }
    }
  }

  // Method to capture images from camera or gallery
  Future<void> captureImage({
    required ImageSource source, 
    required bool isFrontImage,
    required Function setState
  }) async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          if (isFrontImage) {
            _frontImage = kIsWeb ? image : File(image.path);
          } else {
            _nutritionLabelImage = kIsWeb ? image : File(image.path);
          }
        });
      }
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  void addFoodItem(FoodItem foodItem) {
    if (analyzedFoodItems.any((item) => item.name == foodItem.name)) {
      print('Food item already exists: ${foodItem.name}');
      return;
    }

    if (_mySetState != null) {
      _mySetState!(() {
        analyzedFoodItems.add(foodItem);
        _updateTotalNutrients();
      });
    } else {
      analyzedFoodItems.add(foodItem);
      _updateTotalNutrients();
    }
    
    // Save the food consumption to history with current date
    final consumption = FoodConsumption(
      foodItem: foodItem,
      dateConsumed: DateTime.now(),
    );
    _saveFoodConsumption(consumption);
  }

  // Check if both images are available for analysis
  bool canAnalyze() {
    return _frontImage != null && _nutritionLabelImage != null;
  }

  ImageProvider getImageProvider(dynamic imageSource) {
    if (imageSource == null) {
      return const AssetImage('assets/images/placeholder.png');
    }

    if (kIsWeb) {
      // Handle web platform special case
      try {
        final htmlFile = imageSource as dynamic;
        if (htmlFile != null && htmlFile.readAsBytes != null) {
          return MemoryImage(Uint8List.fromList([])); // Placeholder, should be replaced with actual implementation
        } else {
          return const AssetImage('assets/images/placeholder.png');
        }
      } catch (e) {
        print('Error creating image provider for web: $e');
        return const AssetImage('assets/images/placeholder.png');
      }
    } else {
      // Handle mobile platforms
      if (imageSource is File) {
        return FileImage(imageSource);
      } else if (imageSource is XFile) {
        return FileImage(File(imageSource.path));
      } else if (imageSource is Uint8List) {
        return MemoryImage(imageSource);
      } else {
        return const AssetImage('assets/images/placeholder.png');
      }
    }
  }

  Future<String> analyzeFoodImage({
    required dynamic imageFile,
    required Function(void Function()) setState,
    required bool mounted,
  }) async {
    _isAnalyzing = true;
    setState(() {});

    try {
      // Store the image for later reference
      foodImage = imageFile;
      
      // Get API key
      final apiKey = getApiKey();
      if (apiKey == null) {
        throw Exception('Failed to get API key');
      }

      // Create Gemini model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Prepare image data
      late final Uint8List imageBytes;
      
      if (kIsWeb) {
        // For web, we need to handle XFile differently
        try {
          final htmlFile = imageFile as dynamic;
          if (htmlFile != null && htmlFile.readAsBytes != null) {
            imageBytes = await htmlFile.readAsBytes();
          } else {
            throw Exception('Unable to read image bytes on web platform');
          }
        } catch (e) {
          debugPrint('Error reading image bytes on web: $e');
          throw Exception('Failed to process image on web: $e');
        }
      } else {
        // For mobile platforms
        if (imageFile is File) {
          imageBytes = await imageFile.readAsBytes();
        } else if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else if (imageFile is Uint8List) {
          imageBytes = imageFile;
        } else {
          throw Exception('Unsupported image format');
        }
      }

      // Create image part for the model
      final imagePart = DataPart('image/jpeg', imageBytes);
      
      // Add user allergens to the prompt
      String allergensContext = "";
      if (_userAllergens.isNotEmpty) {
        allergensContext = "The user has the following allergens: ${_userAllergens.join(', ')}. ";
        allergensContext += "Please specifically check if any of the food items contain these allergens.";
      }
      
      // Create prompt for food analysis
      final prompt = TextPart('''You are a nutrition expert. Analyze this food image and identify the meal and its components. $allergensContext
Respond using this exact JSON schema:
{
  "meal_analysis": {
    "meal_name": "Name of the meal or dish",
    "items": [
      {
        "food_name": "Name of food item 1",
        "mentioned_quantity": {
          "amount": 100,
          "unit": "g"
        },
        "potential_allergens": ["List of potential allergens in this food", "or empty array if none detected"],
        "ingredients": "Main ingredients in this food item",
        "nutrients_per_100g": {
          "calories": 250,
          "protein": {"value": 10, "unit": "g"},
          "carbohydrates": {"value": 30, "unit": "g"},
          "fat": {"value": 12, "unit": "g"},
          "fiber": {"value": 3, "unit": "g"}
        }
      }
    ],
    "total_nutrients": {
      "calories": 250,
      "protein": {"value": 10, "unit": "g"},
      "carbohydrates": {"value": 30, "unit": "g"},
      "fat": {"value": 12, "unit": "g"},
      "fiber": {"value": 3, "unit": "g"}
    },
    "allergen_warning": "Warning about allergens if any detected, or empty string if none"
  }
}

Important rules to follow:
1. Identify all visible food items in the image
2. Provide accurate standard nutritional values based on reliable food databases
3. Make reasonable estimates of portion sizes if not clearly visible
4. Calculate total nutrients as the sum of all identified food items
5. Use standard units (g for solid foods, ml for liquids)
6. Provide a descriptive name for the overall meal
7. Only respond with the JSON - no additional text
8. For allergens:
   - Check each food item for common allergens (dairy, nuts, gluten, soy, eggs, shellfish, fish, wheat)
   - If the user has specified allergens, pay special attention to those
   - Include an allergen warning summarizing all detected allergens
''');

      // Make request to the model
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);
      
      if (response.text == null) {
        throw Exception('Empty response from model');
      }

      // Process the response
      try {
        // Extract JSON from response
        final jsonString = response.text!.substring(
          response.text!.indexOf('{'),
          response.text!.lastIndexOf('}') + 1,
        );
        
        final jsonResponse = jsonDecode(jsonString);
        final plateAnalysis = jsonResponse['meal_analysis'];
        
        // Set meal name
        _mealName = plateAnalysis['meal_name'] ?? 'Unknown Meal';
        
        // Clear previous analysis
        analyzedFoodItems.clear();
        _detectedAllergens = [];

        // Process each food item
        if (plateAnalysis['items'] != null) {
          for (var item in plateAnalysis['items']) {
            // Extract allergens
            List<String> allergens = [];
            if (item['potential_allergens'] != null) {
              if (item['potential_allergens'] is List) {
                allergens = List<String>.from(item['potential_allergens']);
              } else if (item['potential_allergens'] is String) {
                allergens = (item['potential_allergens'] as String)
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
              }
            }
            
            // Create food item
            FoodItem foodItem = FoodItem(
              name: item['food_name'],
              quantity: item['mentioned_quantity']['amount'].toDouble(),
              unit: item['mentioned_quantity']['unit'],
              ingredients: item['ingredients'],
              allergens: allergens,
              nutrientsPer100g: {
                'calories': item['nutrients_per_100g']['calories'],
                'protein': item['nutrients_per_100g']['protein']['value'],
                'carbohydrates': item['nutrients_per_100g']['carbohydrates']['value'],
                'fat': item['nutrients_per_100g']['fat']['value'],
                'fiber': item['nutrients_per_100g']['fiber']['value'],
              },
            );
            
            // Calculate health score for this food item
            await calculateHealthScore(foodItem);
            
            // Add food item to the list
            analyzedFoodItems.add(foodItem);
          }
        }

        // Store total nutrients
        totalPlateNutrients = {
          'calories': plateAnalysis['total_nutrients']['calories'],
          'protein': plateAnalysis['total_nutrients']['protein']['value'],
          'carbohydrates': plateAnalysis['total_nutrients']['carbohydrates']['value'],
          'fat': plateAnalysis['total_nutrients']['fat']['value'],
          'fiber': plateAnalysis['total_nutrients']['fiber']['value'],
        };

        // Check allergen warning
        if (plateAnalysis['allergen_warning'] != null && 
            plateAnalysis['allergen_warning'] is String &&
            plateAnalysis['allergen_warning'].isNotEmpty) {
          _detectedAllergens.add(plateAnalysis['allergen_warning']);
        }
        
        // Check for user's specific allergens
        checkForAllergens();

        // Debug output
        print("🍽️ Analyzed meal: ${mealNameNotifier.value}");
        print("🥗 Found ${analyzedFoodItems.length} food items");
        print("📊 Total nutrients: $totalPlateNutrients");
        if (_detectedAllergens.isNotEmpty) {
          print("⚠️ Allergen warning: $_detectedAllergens");
        }

      return "Food image analyzed successfully";
    } catch (e) {
        print("Error parsing analysis response: $e");
        throw Exception('Failed to parse analysis results: $e');
      }
    } catch (e) {
      print('Error analyzing food image: $e');
      // Make sure the allergen notifier is reset when there's an error
      hasAllergenWarningNotifier.value = false;
      return 'Error analyzing food image: $e';
    } finally {
      _isAnalyzing = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Method to update total nutrients based on all analyzed food items
  void _updateTotalNutrients() {
    // Reset total nutrients
    totalPlateNutrients = {
      'calories': 0,
      'protein': 0,
      'carbohydrates': 0,
      'fat': 0,
      'fiber': 0,
    };
    
    // Debug log
    print('Updating total nutrients for ${analyzedFoodItems.length} food items');
    
    // Sum up all nutrients from all food items
    for (var item in analyzedFoodItems) {
      final nutrients = item.calculateTotalNutrients();
      
      totalPlateNutrients['calories'] = (totalPlateNutrients['calories'] ?? 0) + (nutrients['calories'] ?? 0);
      totalPlateNutrients['protein'] = (totalPlateNutrients['protein'] ?? 0) + (nutrients['protein'] ?? 0);
      totalPlateNutrients['carbohydrates'] = (totalPlateNutrients['carbohydrates'] ?? 0) + (nutrients['carbohydrates'] ?? 0);
      totalPlateNutrients['fat'] = (totalPlateNutrients['fat'] ?? 0) + (nutrients['fat'] ?? 0);
      totalPlateNutrients['fiber'] = (totalPlateNutrients['fiber'] ?? 0) + (nutrients['fiber'] ?? 0);
    }
    
    print('Updated total nutrients: $totalPlateNutrients');
  }
  
  // Debug method to log the current state of analyzedFoodItems
  void debugLogFoodItems() {
    print('========= DEBUG: ANALYZED FOOD ITEMS =========');
    print('Number of items: ${analyzedFoodItems.length}');
    
    for (int i = 0; i < analyzedFoodItems.length; i++) {
      final item = analyzedFoodItems[i];
      print('Item $i: ${item.name}');
      print('  Quantity: ${item.quantity} ${item.unit}');
      print('  Nutrients: ${item.nutrientsPer100g}');
      print('  Total Nutrients: ${item.calculateTotalNutrients()}');
    }
    
    print('Total Plate Nutrients: $totalPlateNutrients');
    print('===============================================');
  }
  
  Future<void> _saveFoodConsumption(FoodConsumption consumption) async {
    try {
      // Add to in-memory list
      _foodHistory.add(consumption);
      
      // Save to SharedPreferences
      await saveFoodHistory();
      
      // Update daily intake totals
      _updateDailyIntake(consumption);
    } catch (e) {
      print('Error saving food consumption: $e');
    }
  }

  void _updateDailyIntake(FoodConsumption consumption) {
    final nutrients = consumption.foodItem.calculateTotalNutrients();
    nutrients.forEach((key, value) {
      dailyIntake[key] = (dailyIntake[key] ?? 0) + value;
    });
    
    // Update the notifier to trigger UI updates
    dailyIntakeNotifier.value = Map.from(dailyIntake);
    
    // Save updated daily intake
    _saveDailyIntake();
  }

  Future<void> saveFoodHistory() async {
    try {
      print("✅Start of saveFoodHistory()");
      print("⚡Daily intake at start of saveFoodHistory(): $dailyIntake");
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _foodHistory.map((item) => item.toJson()).toList();
      print("Saving food history with ${historyJson.length} items");

      await prefs.setString('food_history', jsonEncode(historyJson));

      // Verify the save
      final savedData = prefs.getString('food_history');
      final decodedSave =
          savedData != null ? jsonDecode(savedData) as List : [];
      print("Verification - Saved food history items: ${decodedSave.length}");
      print("⚡Daily intake at end of saveFoodHistory(): $dailyIntake");
      print("✅End of saveFoodHistory()");
    } catch (e) {
      print("Error saving food history: $e");
    }
  }

  Future<void> _saveDailyIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key = getStorageKey(now);
      await prefs.setString(key, jsonEncode(dailyIntake));
    } catch (e) {
      print('Error saving daily intake: $e');
    }
  }

  // Method to update total nutrients (called when food quantities are changed)
  void updateTotalNutrients() {
    _updateTotalNutrients();
  }

  // Check if app is opened for the first time
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey('user_allergens_set');
  }
  
  // Save user allergens
  Future<void> saveUserAllergens(List<String> allergens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save allergens list
      await prefs.setStringList('user_allergens', allergens);
      
      // Set flag indicating user has set allergens
      await prefs.setBool('user_allergens_set', true);
      
      _userAllergens = allergens;
      allergensNotifier.value = List.from(allergens);
      
      print("✅ Saved user allergens: $allergens");
    } catch (e) {
      print("Error saving user allergens: $e");
    }
  }
  
  // Load user allergens
  Future<void> loadUserAllergens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allergens = prefs.getStringList('user_allergens') ?? [];
      
      _userAllergens = allergens;
      allergensNotifier.value = List.from(allergens);
      
      print("✅ Loaded user allergens: $allergens");
    } catch (e) {
      print("Error loading user allergens: $e");
    }
  }
  
  // Check for allergens in analyzed food items
  void checkForAllergens() {
    if (_userAllergens.isEmpty) {
      hasAllergenWarningNotifier.value = false;
      return;
    }
    
    _detectedAllergens = [];
    bool hasAllergens = false;
    
    // Check nutrition label analysis
    if (_nutritionAnalysis.containsKey('allergens')) {
      final allergens = _nutritionAnalysis['allergens'];
      if (allergens is List) {
        for (var allergen in allergens) {
          if (_userAllergens.any((a) => 
              allergen.toString().toLowerCase().contains(a.toLowerCase()))) {
            _detectedAllergens.add("Found in product: $allergen");
            hasAllergens = true;
          }
        }
      }
    }
    
    // Check ingredients for potential allergens
    if (_nutritionAnalysis.containsKey('ingredients')) {
      final ingredients = _nutritionAnalysis['ingredients'];
      if (ingredients is String) {
        for (var allergen in _userAllergens) {
          if (ingredients.toLowerCase().contains(allergen.toLowerCase())) {
            _detectedAllergens.add("Found in ingredients: $allergen");
            hasAllergens = true;
          }
        }
      }
    }
    
    // Check analyzed food items
    for (var item in analyzedFoodItems) {
      if (item.allergens != null && item.allergens!.isNotEmpty) {
        for (var allergen in item.allergens!) {
          if (_userAllergens.any((a) => 
              allergen.toLowerCase().contains(a.toLowerCase()))) {
            _detectedAllergens.add("Found in ${item.name}: $allergen");
            hasAllergens = true;
          }
        }
      }
      
      // Check ingredients as well
      if (item.ingredients != null && item.ingredients!.isNotEmpty) {
        for (var allergen in _userAllergens) {
          if (item.ingredients!.toLowerCase().contains(allergen.toLowerCase())) {
            _detectedAllergens.add("Found in ${item.name} ingredients: $allergen");
            hasAllergens = true;
          }
        }
      }
    }
    
    hasAllergenWarningNotifier.value = hasAllergens;
    if (hasAllergens) {
      print("⚠️ Allergen warning! Detected: $_detectedAllergens");
    } else {
      print("✅ No allergens detected");
    }
  }

  // Add a food item from Open Food Facts to analyzed food items
  void addAnalyzedFoodItem(Map<String, dynamic> foodItem) {
    // Convert to the right format if needed
    if (!foodItem.containsKey('quantity')) {
      foodItem['quantity'] = 1;
    }
    
    if (!foodItem.containsKey('unit')) {
      foodItem['unit'] = 'serving';
    }
    
    if (!foodItem.containsKey('calories_per_serving')) {
      // If calories exists in nutrients, use that
      if (foodItem.containsKey('nutrients') && 
          foodItem['nutrients'] is Map &&
          foodItem['nutrients'].containsKey('calories')) {
        foodItem['calories_per_serving'] = foodItem['nutrients']['calories'];
      } else {
        foodItem['calories_per_serving'] = 0;
      }
    }
    
    // Set a default meal name if not already set
    if (mealNameNotifier.value.isEmpty) {
      _mealName = foodItem['name'] ?? 'Analyzed Product';
    }
    
    // Convert the Map to a FoodItem
    final foodItemObj = FoodItem(
      name: foodItem['name'] ?? 'Unknown Product',
      brand: foodItem['brand'],
      barcode: foodItem['barcode'],
      quantity: (foodItem['quantity'] as num?)?.toDouble() ?? 100.0,
      unit: foodItem['unit'] ?? 'g',
      ingredients: foodItem['ingredients'],
      imageUrl: foodItem['imageUrl'],
      nutrientsPer100g: {
        'calories': foodItem['nutrients']?['calories'] ?? 0,
        'protein': foodItem['nutrients']?['protein'] ?? 0,
        'carbohydrates': foodItem['nutrients']?['carbohydrates'] ?? 0,
        'fat': foodItem['nutrients']?['fat'] ?? 0,
        'fiber': foodItem['nutrients']?['fiber'] ?? 0,
      },
    );
    
    print('Adding FoodItem: ${foodItemObj.name} with calories: ${foodItemObj.nutrientsPer100g['calories']}');
    
    // Add to analyzed food items
    analyzedFoodItems.add(foodItemObj);
    
    // Update the total nutrients
    _updateTotalNutrients();
    
    // Convert nutrients to Map<String, double> for addToFoodHistory
    Map<String, double> nutrientsAsDouble = {};
    foodItemObj.nutrientsPer100g.forEach((key, value) {
      nutrientsAsDouble[key] = (value is num) ? value.toDouble() : 0.0;
    });
    
    // Add to food history - using the proper parameters
    addToFoodHistory(
      foodName: foodItem['name'] ?? 'Unknown Product',
      nutrients: nutrientsAsDouble,
      source: 'search',
      imagePath: foodItem['imageUrl'] ?? '',
    );
    
    // Force UI update
    setState(() {});
  }

  /// Calculates health score for a food item
  Future<void> calculateHealthScore(FoodItem foodItem) async {
    try {
      // Calculate health score using the HealthScoreService
      final healthScore = HealthScoreService.instance.calculateHealthScore(foodItem);
      
      // Set the health score on the food item
      foodItem.setHealthScore(healthScore);
      
      debugPrint('Health score calculated for ${foodItem.name}: ${healthScore.score.round()} - ${healthScore.rankName}');
    } catch (e) {
      debugPrint('Error calculating health score: $e');
    }
  }

  /// Process nutrition data from OCR or API and calculate health score
  Future<void> processNutritionData(Map<String, dynamic> nutritionData) async {
    final productName = nutritionData['product']['name'] ?? 'Unknown Food';
    final nutrients = nutritionData['nutrients'] ?? {};
    
    // Create a standardized nutrients map
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
      'saturated_fat': nutrients['saturated_fat'] ?? 0,
      'trans_fat': nutrients['trans_fat'] ?? 0,
      'cholesterol': nutrients['cholesterol'] ?? 0,
    };
    
    // Create the food item
    final foodItem = FoodItem(
      name: productName,
      quantity: 100.0,
      unit: 'g',
      nutrientsPer100g: standardizedNutrients,
      ingredients: nutritionData['ingredients'],
    );
    
    // Calculate and set the health score
    await calculateHealthScore(foodItem);
    
    // Add to analyzed food items
    analyzedFoodItems.add(foodItem);
    
    // Update total nutrients
    updateTotalNutrients();
  }
}
