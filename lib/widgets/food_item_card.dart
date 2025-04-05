import 'package:flutter/material.dart';
import 'package:read_the_label/logic.dart';
import 'package:read_the_label/main.dart';
import 'package:read_the_label/widgets/food_nutreint_tile.dart';
import '../models/food_item.dart';
import 'nutrient_tile.dart';
import '../utils/custom_colors.dart';
import '../widgets/health_score_badge.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final Function setState;
  final Logic logic;

  const FoodItemCard({
    super.key,
    required this.item,
    required this.setState,
    required this.logic,
  });

  @override
  Widget build(BuildContext context) {
    // Debug log to check health score
    debugPrint('FoodItemCard for ${item.name}: hasHealthScore=${item.hasHealthScore}');
    if (item.hasHealthScore) {
      debugPrint('  Score: ${item.healthScore!.score}, Rank: ${item.healthScore!.rankName}');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.quantity}${item.unit}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => _showEditDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Health Score Section (if available)
          if (item.hasHealthScore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Health Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showHealthScoreDetails(context),
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Compact badge
                      CompactHealthScoreBadge(score: item.healthScore!),
                      const SizedBox(width: 16),
                      // Score description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.healthScore!.rankName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _hexToColor(item.healthScore!.rankColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.healthScore!.shortDescription,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          // Nutrient grid
          GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.0,
            children: [
              FoodNutrientTile(
                label: 'Calories',
                value: item
                        .calculateTotalNutrients()['calories']
                        ?.toStringAsFixed(1) ??
                    '0',
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined,
              ),
              FoodNutrientTile(
                label: 'Protein',
                value: item
                        .calculateTotalNutrients()['protein']
                        ?.toStringAsFixed(1) ??
                    '0',
                unit: 'g',
                icon: Icons.fitness_center_outlined,
              ),
              FoodNutrientTile(
                label: 'Carbohydrates',
                value: item
                        .calculateTotalNutrients()['carbohydrates']
                        ?.toStringAsFixed(1) ??
                    '0',
                unit: 'g',
                icon: Icons.grain_outlined,
              ),
              FoodNutrientTile(
                label: 'Fat',
                value:
                    item.calculateTotalNutrients()['fat']?.toStringAsFixed(1) ??
                        '0',
                unit: 'g',
                icon: Icons.opacity_outlined,
              ),
              FoodNutrientTile(
                label: 'Fiber',
                value: item
                        .calculateTotalNutrients()['fiber']
                        ?.toStringAsFixed(1) ??
                    '0',
                unit: 'g',
                icon: Icons.grass_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Edit Quantity',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Poppins',
          ),
        ),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter quantity in ${item.unit}',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontFamily: 'Poppins',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Poppins',
          ),
          onChanged: (value) {
            double? newQuantity = double.tryParse(value);
            if (newQuantity != null) {
              setState(() {
                item.quantity = newQuantity;
                logic.updateTotalNutrients();
              });
            }
          },
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Poppins',
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              'Save',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              setState(() {
                logic.updateTotalNutrients();
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  
  void _showHealthScoreDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Health Score Badge
                HealthScoreBadge(
                  score: item.healthScore!,
                  size: 120,
                ),
                const SizedBox(height: 24),
                
                // Health Score Breakdown
                if (item.healthScore!.positiveFactors.isNotEmpty) ...[
                  _buildFactorList(
                    context, 
                    'Positive Factors', 
                    item.healthScore!.positiveFactors,
                    true,
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (item.healthScore!.negativeFactors.isNotEmpty) ...[
                  _buildFactorList(
                    context, 
                    'Negative Factors', 
                    item.healthScore!.negativeFactors,
                    false,
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (item.healthScore!.benefits.isNotEmpty ||
                    item.healthScore!.concerns.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.healthScore!.benefits.isNotEmpty)
                        Expanded(
                          child: _buildBulletList(
                            context,
                            'Benefits',
                            item.healthScore!.benefits,
                            Colors.green,
                          ),
                        ),
                      const SizedBox(width: 16),
                      if (item.healthScore!.concerns.isNotEmpty)
                        Expanded(
                          child: _buildBulletList(
                            context,
                            'Concerns',
                            item.healthScore!.concerns,
                            Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFactorList(BuildContext context, String title, Map<String, double> factors, bool isPositive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        ...factors.entries
            .toList()
            .where((e) => e.value > 0)
            .take(3) // Limit to top 3 factors
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${isPositive ? "+" : "-"}${e.value.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
      ],
    );
  }
  
  Widget _buildBulletList(BuildContext context, String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...items.take(3).map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color)),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            )),
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
