import 'package:flutter/material.dart';
import '../models/health_score.dart';

/// A widget that displays a detailed breakdown of a health score
class HealthScoreBreakdown extends StatelessWidget {
  /// The health score to display
  final HealthScore score;
  
  /// Constructor
  const HealthScoreBreakdown({
    Key? key,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Convert hex color to Flutter color
    final Color rankColor = _hexToColor(score.rankColor);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rankColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: rankColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Health Score Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          
          const Divider(color: Colors.grey),
          
          // Primary recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: rankColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    score.primaryRecommendation,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Positive factors section
          if (score.positiveFactors.isNotEmpty) ...[
            _buildSectionHeader('Positive Factors', Icons.add_circle_outline, Colors.green),
            const SizedBox(height: 8),
            ...score.positiveFactors.entries
                .toList()
                .where((e) => e.value > 0)
                .map((e) => _buildFactorRow(e.key, e.value, true)),
            const SizedBox(height: 16),
          ],
          
          // Negative factors section
          if (score.negativeFactors.isNotEmpty) ...[
            _buildSectionHeader('Negative Factors', Icons.remove_circle_outline, Colors.red),
            const SizedBox(height: 8),
            ...score.negativeFactors.entries
                .toList()
                .where((e) => e.value > 0)
                .map((e) => _buildFactorRow(e.key, e.value, false)),
            const SizedBox(height: 16),
          ],
          
          // Benefits section
          if (score.benefits.isNotEmpty) ...[
            _buildSectionHeader('Health Benefits', Icons.favorite_border, Colors.green),
            const SizedBox(height: 8),
            ...score.benefits.map(_buildBulletPoint),
            const SizedBox(height: 16),
          ],
          
          // Concerns section
          if (score.concerns.isNotEmpty) ...[
            _buildSectionHeader('Health Concerns', Icons.warning_amber_outlined, Colors.orange),
            const SizedBox(height: 8),
            ...score.concerns.map(_buildBulletPoint),
          ],
        ],
      ),
    );
  }
  
  /// Builds a section header with icon and title
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
  
  /// Builds a factor row with name and value
  Widget _buildFactorRow(String name, double value, bool isPositive) {
    final Color valueColor = isPositive ? Colors.green : Colors.red;
    final String prefix = isPositive ? '+' : '-';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Text(
            '$prefix${value.toStringAsFixed(1)} pts',
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds a bullet point for benefits and concerns
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
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