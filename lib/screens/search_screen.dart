import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:read_the_label/models/open_food_facts_product.dart';
import 'package:read_the_label/services/open_food_facts_service.dart';
import 'package:read_the_label/utils/custom_colors.dart';
import 'package:read_the_label/widgets/food_item_card.dart';
import 'package:read_the_label/logic.dart';

class SearchScreen extends StatefulWidget {
  final Logic logic;

  const SearchScreen({Key? key, required this.logic}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OpenFoodFactsService _service = OpenFoodFactsService();
  List<OpenFoodFactsProduct> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _service.searchProducts(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching products: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching products: $e')),
        );
      }
    }
  }

  void _viewProductDetails(OpenFoodFactsProduct product) {
    try {
      // Convert to FoodItem format
      final Map<String, dynamic> foodItem = product.toFoodItem();
      
      // Make sure we have the right structure required by Logic.addAnalyzedFoodItem
      if (!foodItem.containsKey('quantity')) {
        foodItem['quantity'] = 100;
      }
      
      if (!foodItem.containsKey('unit')) {
        foodItem['unit'] = 'g';
      }
      
      // Ensure the nutrients key in the converted format matches what Logic expects
      final nutrients = foodItem['nutrients'] as Map<String, dynamic>;
      if (nutrients.containsKey('calories')) {
        // Rename keys if needed to match expected format
        foodItem['nutrients'] = {
          'calories': nutrients['calories'] ?? 0,
          'protein': nutrients['protein'] ?? 0,
          'carbohydrates': nutrients['carbohydrates'] ?? 0,
          'fat': nutrients['total_fat'] ?? 0,
          'fiber': nutrients['fiber'] ?? 0,
        };
      }
      
      print('Adding food item to analyzed food items: ${foodItem['name']}');
      
      // Clear any previous analyzed food items to ensure only the selected product is shown
      widget.logic.analyzedFoodItems.clear();
      
      // Add to the logic's analyzed food items
      widget.logic.addAnalyzedFoodItem(foodItem);
      
      // Check for allergens
      widget.logic.checkForAllergens();
      
      // Debug log of the food items
      widget.logic.debugLogFoodItems();
      
      // Navigate back to the home page
      Navigator.pop(context, true);
      
      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${foodItem['name']} to analysis')),
      );
    } catch (e) {
      print('Error processing food item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing food item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Search Foods',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Poppins',
                ),
                decoration: InputDecoration(
                  hintText: 'Search for foods...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                onSubmitted: (value) => _searchProducts(value),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () => _searchProducts(_searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Search',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _hasSearched && _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : !_hasSearched
                        ? Center(
                            child: Text(
                              'Search for food products',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                fontFamily: 'Poppins',
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final product = _searchResults[index];
                              return _buildProductCard(product);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(OpenFoodFactsProduct product) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _viewProductDetails(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (product.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade300,
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.no_food,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName ?? 'Unknown Product',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (product.brands != null) 
                      Text(
                        product.brands!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    SizedBox(height: 8),
                    if (product.nutritionGrade != null)
                      Row(
                        children: [
                          _buildNutritionGradeBadge(product.nutritionGrade!),
                          SizedBox(width: 8),
                          if (product.novaGroup != null)
                            _buildNovaGroupBadge(product.novaGroup!),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionGradeBadge(String grade) {
    final gradeColors = {
      'a': Colors.green.shade700,
      'b': Colors.green,
      'c': Colors.yellow.shade700,
      'd': Colors.orange,
      'e': Colors.red,
    };

    final gradeColor = gradeColors[grade.toLowerCase()] ?? Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gradeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Nutri-Score ${grade.toUpperCase()}',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildNovaGroupBadge(String novaGroup) {
    final novaColors = {
      '1': Colors.green,
      '2': Colors.lightGreen,
      '3': Colors.orange,
      '4': Colors.red,
    };

    final novaColor = novaColors[novaGroup] ?? Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: novaColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'NOVA $novaGroup',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
} 