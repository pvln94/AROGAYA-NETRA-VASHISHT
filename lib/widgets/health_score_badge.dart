import 'package:flutter/material.dart';
import '../models/health_score.dart';

/// A widget that displays a health score badge with rank and color based on the Netra Ranks system
class HealthScoreBadge extends StatelessWidget {
  /// The health score to display
  final HealthScore score;
  
  /// The size of the badge (default is 120)
  final double size;
  
  /// Whether to show the details description (default is true)
  final bool showDetails;
  
  /// Constructor
  const HealthScoreBadge({
    Key? key,
    required this.score,
    this.size = 120,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Convert hex color to Flutter color
    Color rankColor = _hexToColor(score.rankColor);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Circular progress indicator
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: score.score / 100,
                strokeWidth: size / 10,
                backgroundColor: Colors.grey.shade800,
                color: rankColor,
              ),
            ),
            
            // Center content with score and rank
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Numerical score
                Text(
                  score.score.round().toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size / 3,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                
                // Rank name
                Text(
                  score.rankName,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: size / 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // Description (optional)
        if (showDetails) ...[
          const SizedBox(height: 8),
          Text(
            score.rankDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ],
    );
  }
  
  /// Converts a hex color string to a Flutter Color
  Color _hexToColor(String hexColor) {
    // Remove # if present
    final String colorString = hexColor.replaceAll('#', '');
    
    // Parse the hex color
    try {
      return Color(int.parse('0xFF$colorString'));
    } catch (e) {
      // Default to green if parsing fails
      return const Color(0xFF4CAF50);
    }
  }
}

/// A smaller version of the health score badge for more compact displays
class CompactHealthScoreBadge extends StatelessWidget {
  /// The health score to display
  final HealthScore score;
  
  /// The size of the badge (default is 60)
  final double size;
  
  /// Constructor
  const CompactHealthScoreBadge({
    Key? key,
    required this.score,
    this.size = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Convert hex color to Flutter color
    Color rankColor = _hexToColor(score.rankColor);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        shape: BoxShape.circle,
        border: Border.all(
          color: rankColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.score.round().toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size / 3,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            score.rankName,
            style: TextStyle(
              color: rankColor,
              fontSize: size / 8,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
  
  /// Converts a hex color string to a Flutter Color
  Color _hexToColor(String hexColor) {
    // Remove # if present
    final String colorString = hexColor.replaceAll('#', '');
    
    // Parse the hex color
    try {
      return Color(int.parse('0xFF$colorString'));
    } catch (e) {
      // Default to green if parsing fails
      return const Color(0xFF4CAF50);
    }
  }
} 