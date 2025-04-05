import '../models/food_item.dart';
import '../models/health_score.dart';

/// Service for calculating health scores for food items
class HealthScoreService {
  /// Singleton instance
  static final HealthScoreService instance = HealthScoreService._internal();

  /// Private constructor for singleton
  HealthScoreService._internal();

  /// Weight factors for positive nutrients (per unit)
  static const Map<String, double> _positiveWeights = {
    'protein': 5.0, // per 5g
    'fiber': 6.0, // per 5g
    'vitamin_a': 3.0, // per 10% DV
    'vitamin_c': 3.0, // per 10% DV
    'calcium': 3.0, // per 10% DV
    'iron': 3.0, // per 10% DV
    'potassium': 2.0, // per 10% DV
  };

  /// Weight factors for negative nutrients (per unit)
  static const Map<String, double> _negativeWeights = {
    'sugar': 10.0, // per 10g
    'sodium': 8.0, // per 100mg
    'fat': 7.0, // per 5g
    'saturated_fat': 12.0, // per 5g
    'trans_fat': 20.0, // per 1g
    'cholesterol': 5.0, // per 30mg
  };

  /// Penalty for ultra-processed foods
  static const double _ultraProcessedPenalty = 20.0;

  /// Penalty for artificial additives
  static const double _artificialAdditivesPenalty = 10.0;

  /// Calculate health score for a food item based on its nutritional content
  HealthScore calculateHealthScore(FoodItem foodItem) {
    // Base score starts at 100
    double score = 100.0;
    
    // Track positive and negative contributions for explanation
    final Map<String, double> positiveFactors = {};
    final Map<String, double> negativeFactors = {};
    final List<String> benefits = [];
    final List<String> concerns = [];
    
    // Process positive nutrients
    _positiveWeights.forEach((nutrient, weight) {
      if (foodItem.nutrientsPer100g.containsKey(nutrient) &&
          foodItem.nutrientsPer100g[nutrient] != null) {
        double value = foodItem.nutrientsPer100g[nutrient];
        
        // Calculate positive contribution based on nutrient type
        double contribution = 0.0;
        
        switch (nutrient) {
          case 'protein':
            contribution = (value / 5.0) * weight;
            if (value >= 10.0) {
              benefits.add('Good source of protein');
            }
            break;
          case 'fiber':
            contribution = (value / 5.0) * weight;
            if (value >= 5.0) {
              benefits.add('High in fiber');
            }
            break;
          case 'vitamin_a':
          case 'vitamin_c':
          case 'calcium':
          case 'iron':
          case 'potassium':
            // These are typically in % of daily value
            contribution = (value / 10.0) * weight;
            if (value >= 20.0) {
              benefits.add('Good source of ${_formatNutrientName(nutrient)}');
            }
            break;
          default:
            contribution = 0.0;
        }
        
        score += contribution;
        if (contribution > 0) {
          positiveFactors[_formatNutrientName(nutrient)] = contribution;
        }
      }
    });
    
    // Process negative nutrients
    _negativeWeights.forEach((nutrient, weight) {
      if (foodItem.nutrientsPer100g.containsKey(nutrient) &&
          foodItem.nutrientsPer100g[nutrient] != null) {
        double value = foodItem.nutrientsPer100g[nutrient];
        
        // Calculate negative contribution based on nutrient type
        double contribution = 0.0;
        
        switch (nutrient) {
          case 'sugar':
            contribution = (value / 10.0) * weight;
            if (value >= 15.0) {
              concerns.add('High in sugar');
            }
            break;
          case 'sodium':
            contribution = (value / 100.0) * weight;
            if (value >= 400.0) {
              concerns.add('High in sodium');
            }
            break;
          case 'fat':
            contribution = (value / 5.0) * weight;
            if (value >= 15.0) {
              concerns.add('High in fat');
            }
            break;
          case 'saturated_fat':
            contribution = (value / 5.0) * weight;
            if (value >= 5.0) {
              concerns.add('High in saturated fat');
            }
            break;
          case 'trans_fat':
            contribution = (value / 1.0) * weight;
            if (value > 0.0) {
              concerns.add('Contains trans fat');
            }
            break;
          case 'cholesterol':
            contribution = (value / 30.0) * weight;
            if (value >= 60.0) {
              concerns.add('High in cholesterol');
            }
            break;
          default:
            contribution = 0.0;
        }
        
        score -= contribution;
        if (contribution > 0) {
          negativeFactors[_formatNutrientName(nutrient)] = contribution;
        }
      }
    });
    
    // Apply penalties for processing and additives if ingredients are available
    if (foodItem.ingredients != null && foodItem.ingredients!.isNotEmpty) {
      final String ingredients = foodItem.ingredients!.toLowerCase();
      
      // Check for ultra-processed indicators
      bool isUltraProcessed = _isUltraProcessed(ingredients);
      
      // Check for artificial additives
      bool hasArtificialAdditives = _hasArtificialAdditives(ingredients);
      
      if (isUltraProcessed) {
        score -= _ultraProcessedPenalty;
        negativeFactors['Ultra-processed'] = _ultraProcessedPenalty;
        concerns.add('Ultra-processed food');
      }
      
      if (hasArtificialAdditives) {
        score -= _artificialAdditivesPenalty;
        negativeFactors['Artificial additives'] = _artificialAdditivesPenalty;
        concerns.add('Contains artificial additives');
      }
    }
    
    // Create and return the health score
    return HealthScore.fromNumericScore(
      numericScore: score,
      positiveFactors: positiveFactors,
      negativeFactors: negativeFactors,
      benefits: benefits,
      concerns: concerns,
    );
  }
  
  /// Format nutrient name for display
  String _formatNutrientName(String nutrient) {
    switch (nutrient) {
      case 'vitamin_a':
        return 'Vitamin A';
      case 'vitamin_c':
        return 'Vitamin C';
      case 'saturated_fat':
        return 'Saturated Fat';
      case 'trans_fat':
        return 'Trans Fat';
      default:
        return nutrient.split('_').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
    }
  }
  
  /// Check if food is ultra-processed based on ingredients
  bool _isUltraProcessed(String ingredients) {
    final List<String> ultraProcessedIndicators = [
      'high fructose corn syrup',
      'hydrogenated',
      'hydrolyzed',
      'modified starch',
      'interesterified',
      'maltodextrin',
      'invert sugar',
      'corn syrup',
      'artificial flavor',
      'artificial colour',
      'artificial color',
      'flavor enhancer',
      'emulsifier',
      'dextrose',
      'soy protein isolate',
    ];
    
    return ultraProcessedIndicators.any((indicator) => ingredients.contains(indicator));
  }
  
  /// Check if food has artificial additives based on ingredients
  bool _hasArtificialAdditives(String ingredients) {
    // Common artificial additives (E-numbers and specific names)
    final List<String> artificialAdditives = [
      'e102', 'e104', 'e110', 'e122', 'e124', 'e129', // Artificial colors
      'e211', 'e212', 'e213', // Benzoates
      'e621', // MSG
      'e951', // Aspartame
      'e950', // Acesulfame K
      'e955', // Sucralose
      'tartrazine',
      'aspartame',
      'sucralose',
      'acesulfame',
      'saccharin',
      'butylated hydroxyanisole',
      'butylated hydroxytoluene',
      'bha',
      'bht',
    ];
    
    return artificialAdditives.any((additive) => ingredients.contains(additive));
  }
} 