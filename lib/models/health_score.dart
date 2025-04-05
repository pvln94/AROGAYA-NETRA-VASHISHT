import 'dart:math';

/// Represents the health score for a food item using the "Netra Ranks" system
class HealthScore {
  /// Numerical score from 0 to 100
  final double score;
  
  /// Rank name based on the score range (Amrit, Prana, Shakti, etc.)
  final String rankName;
  
  /// Description of the rank
  final String rankDescription;
  
  /// Color representing the rank (in hex format)
  final String rankColor;
  
  /// Positive factors contributing to the score
  final Map<String, double> positiveFactors;
  
  /// Negative factors contributing to the score
  final Map<String, double> negativeFactors;
  
  /// Primary health benefits
  final List<String> benefits;
  
  /// Primary health concerns
  final List<String> concerns;

  const HealthScore({
    required this.score,
    required this.rankName,
    required this.rankDescription,
    required this.rankColor,
    required this.positiveFactors,
    required this.negativeFactors,
    required this.benefits,
    required this.concerns,
  });
  
  /// Returns the appropriate HealthScore based on the calculated numerical score
  factory HealthScore.fromNumericScore({
    required double numericScore,
    required Map<String, double> positiveFactors,
    required Map<String, double> negativeFactors,
    List<String> benefits = const [],
    List<String> concerns = const [],
  }) {
    // Ensure the score is between 0 and 100
    final normalizedScore = max(0, min(100, numericScore)).toDouble();
    
    String rankName;
    String rankDescription;
    String rankColor;
    
    // Determine rank based on score
    if (normalizedScore >= 90) {
      rankName = 'Amrit';
      rankDescription = 'Exceptionally healthy - "Nectar of life"';
      rankColor = '#4CAF50'; // Vibrant green
    } else if (normalizedScore >= 75) {
      rankName = 'Prana';
      rankDescription = 'Very healthy - "Life force"';
      rankColor = '#8BC34A'; // Light green
    } else if (normalizedScore >= 60) {
      rankName = 'Shakti';
      rankDescription = 'Good health value - "Energy"';
      rankColor = '#CDDC39'; // Lime
    } else if (normalizedScore >= 40) {
      rankName = 'Santulit';
      rankDescription = 'Moderate nutritional value - "Balanced"';
      rankColor = '#FFC107'; // Amber
    } else if (normalizedScore >= 20) {
      rankName = 'Saadharan';
      rankDescription = 'Below average nutrition - "Ordinary"';
      rankColor = '#FF9800'; // Orange
    } else {
      rankName = 'Vishakt';
      rankDescription = 'Poor nutritional value - "Toxic"';
      rankColor = '#F44336'; // Red
    }
    
    return HealthScore(
      score: normalizedScore,
      rankName: rankName,
      rankDescription: rankDescription,
      rankColor: rankColor,
      positiveFactors: positiveFactors,
      negativeFactors: negativeFactors,
      benefits: benefits,
      concerns: concerns,
    );
  }
  
  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'rankName': rankName,
      'rankDescription': rankDescription,
      'rankColor': rankColor,
      'positiveFactors': positiveFactors,
      'negativeFactors': negativeFactors,
      'benefits': benefits,
      'concerns': concerns,
    };
  }
  
  /// Create from JSON representation
  factory HealthScore.fromJson(Map<String, dynamic> json) {
    return HealthScore(
      score: json['score'] ?? 0.0,
      rankName: json['rankName'] ?? 'Unknown',
      rankDescription: json['rankDescription'] ?? '',
      rankColor: json['rankColor'] ?? '#CCCCCC',
      positiveFactors: Map<String, double>.from(json['positiveFactors'] ?? {}),
      negativeFactors: Map<String, double>.from(json['negativeFactors'] ?? {}),
      benefits: List<String>.from(json['benefits'] ?? []),
      concerns: List<String>.from(json['concerns'] ?? []),
    );
  }
  
  /// Get a shortened version of the rank description
  String get shortDescription {
    switch (rankName) {
      case 'Amrit':
        return 'Exceptional';
      case 'Prana':
        return 'Very Healthy';
      case 'Shakti':
        return 'Healthy';
      case 'Santulit':
        return 'Moderate';
      case 'Saadharan':
        return 'Below Average';
      case 'Vishakt':
        return 'Unhealthy';
      default:
        return 'Unknown';
    }
  }
  
  /// Get primary recommendation based on score
  String get primaryRecommendation {
    if (score >= 75) {
      return 'Great choice! This food is highly nutritious.';
    } else if (score >= 60) {
      return 'Good choice with decent nutritional value.';
    } else if (score >= 40) {
      return 'Acceptable in moderation, but look for healthier alternatives.';
    } else {
      return 'Consider healthier alternatives with less processed ingredients.';
    }
  }
} 