import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_the_label/logic.dart';
import 'package:read_the_label/models/food_consumption.dart';
import 'package:read_the_label/models/health_score.dart';

class FoodHistoryScreen extends StatefulWidget {
  final Logic logic;

  const FoodHistoryScreen({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  State<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> {
  // Filter options
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  String _selectedHealthRank = 'All';
  List<String> _selectedAllergens = [];
  RangeValues _calorieRange = RangeValues(0, 1000);
  
  // Track filtered items
  List<FoodConsumption> _filteredItems = [];
  
  // Group options
  bool _groupByDate = true;
  
  @override
  void initState() {
    super.initState();
    // Set default date range to last 7 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    
    // Apply initial filtering
    _applyFilters();
  }
  
  void _applyFilters() {
    setState(() {
      _filteredItems = widget.logic.foodHistory.where((item) {
        // Filter by date range
        final inDateRange = _startDate == null || _endDate == null || 
            (item.dateConsumed.isAfter(_startDate!) && 
             item.dateConsumed.isBefore(_endDate!.add(const Duration(days: 1))));
        
        // Filter by search query
        final matchesSearch = _searchQuery.isEmpty || 
            item.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
        
        // Filter by health rank
        final matchesHealthRank = _selectedHealthRank == 'All' || 
            item.foodItem.healthScore?.rankName == _selectedHealthRank;
        
        // Filter by allergens
        final matchesAllergens = _selectedAllergens.isEmpty || 
            (_selectedAllergens.any((allergen) => 
                item.allergens?.any((a) => a.toLowerCase() == allergen.toLowerCase()) ?? false));
        
        // Filter by calorie range
        final calories = item.nutrients['calories'] ?? 
                        item.nutrients['Energy'] ?? 
                        item.nutrients['energy'] ?? 0.0;
        final inCalorieRange = calories >= _calorieRange.start && 
                              calories <= _calorieRange.end;
        
        return inDateRange && matchesSearch && matchesHealthRank && 
               (matchesAllergens || _selectedAllergens.isEmpty) && inCalorieRange;
      }).toList();
      
      // Sort by date (newest first)
      _filteredItems.sort((a, b) => b.dateConsumed.compareTo(a.dateConsumed));
    });
  }
  
  // Show date picker for filtering by date
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: _endDate ?? DateTime.now(),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }
  
  // Show modal for additional filters
  void _showFiltersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Filter Options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Health Rank Filter
                      Text(
                        'Health Rank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          'All', 'Amrit', 'Prana', 'Shakti', 'Santulit', 'Saadharan', 'Vishakt'
                        ].map((rank) => FilterChip(
                          label: Text(rank),
                          selected: _selectedHealthRank == rank,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedHealthRank = selected ? rank : 'All';
                            });
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Allergen Filter
                      Text(
                        'Allergens',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          'Dairy', 'Nuts', 'Eggs', 'Gluten', 'Soy', 'Seafood'
                        ].map((allergen) => FilterChip(
                          label: Text(allergen),
                          selected: _selectedAllergens.contains(allergen),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedAllergens.add(allergen);
                              } else {
                                _selectedAllergens.remove(allergen);
                              }
                            });
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Calorie Range Slider
                      Text(
                        'Calorie Range: ${_calorieRange.start.toInt()} - ${_calorieRange.end.toInt()} kcal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      RangeSlider(
                        values: _calorieRange,
                        min: 0,
                        max: 1000,
                        divisions: 20,
                        labels: RangeLabels(
                          _calorieRange.start.round().toString(),
                          _calorieRange.end.round().toString(),
                        ),
                        onChanged: (values) {
                          setModalState(() {
                            _calorieRange = values;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Apply Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _applyFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Apply Filters'),
                      ),
                      
                      // Reset Button
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedHealthRank = 'All';
                            _selectedAllergens = [];
                            _calorieRange = RangeValues(0, 1000);
                          });
                        },
                        child: Text(
                          'Reset Filters',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Map<String, List<FoodConsumption>> _groupItemsByDate() {
    final groups = <String, List<FoodConsumption>>{};
    
    for (var item in _filteredItems) {
      final dateKey = DateFormat('yyyy-MM-dd').format(item.dateConsumed);
      if (!groups.containsKey(dateKey)) {
        groups[dateKey] = [];
      }
      groups[dateKey]!.add(item);
    }
    
    return groups;
  }
  
  String _getFormattedDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    if (DateFormat('yyyy-MM-dd').format(now) == dateString) {
      return 'Today';
    } else if (DateFormat('yyyy-MM-dd').format(yesterday) == dateString) {
      return 'Yesterday';
    }
    
    return DateFormat('EEEE, MMMM d').format(date);
  }
  
  Widget _buildFoodItem(FoodConsumption item) {
    final healthScore = item.foodItem.healthScore;
    final healthColor = healthScore != null 
        ? Color(int.parse(healthScore.rankColor.replaceFirst('#', '0xff')))
        : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          item.foodName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('h:mm a').format(item.dateConsumed),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 8),
            if (healthScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: healthColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  healthScore.rankName,
                  style: TextStyle(
                    color: healthColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.nutrients['calories'] ?? item.nutrients['Energy'] ?? 0} kcal',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            if (item.allergens != null && item.allergens!.isNotEmpty)
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 16,
              ),
          ],
        ),
        onTap: () {
          // Show detailed view of the food item
          _showFoodItemDetails(item);
        },
      ),
    );
  }
  
  void _showFoodItemDetails(FoodConsumption item) {
    final healthScore = item.foodItem.healthScore;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  item.foodName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Consumed on ${DateFormat('MMMM d, yyyy at h:mm a').format(item.dateConsumed)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Health Score
                if (healthScore != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(int.parse(healthScore.rankColor.replaceFirst('#', '0xff'))),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            healthScore.score.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              healthScore.rankName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(int.parse(healthScore.rankColor.replaceFirst('#', '0xff'))),
                              ),
                            ),
                            Text(
                              healthScore.rankDescription,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Nutrient Information
                Text(
                  'Nutrient Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...item.nutrients.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(1)} ${_getNutrientUnit(entry.key)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                
                // Allergen Information
                if (item.allergens != null && item.allergens!.isNotEmpty) ...[
                  Text(
                    'Allergens',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.allergens!.map((allergen) {
                      final isUserAllergen = widget.logic.userAllergens.any(
                        (a) => a.toLowerCase() == allergen.toLowerCase()
                      );
                      
                      return Chip(
                        label: Text(allergen),
                        backgroundColor: isUserAllergen 
                          ? Theme.of(context).colorScheme.error.withOpacity(0.2) 
                          : Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: isUserAllergen 
                            ? Theme.of(context).colorScheme.error 
                            : Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Close Button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  String _getNutrientUnit(String nutrientName) {
    final name = nutrientName.toLowerCase();
    if (name.contains('energy') || name.contains('calories')) {
      return 'kcal';
    } else if (name.contains('sodium') || 
               name.contains('potassium') || 
               name.contains('calcium')) {
      return 'mg';
    } else if (name.contains('vitamin')) {
      return 'μg';
    } else {
      return 'g';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final groupedItems = _groupItemsByDate();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food History'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // Group/Ungroup Toggle
          IconButton(
            icon: Icon(_groupByDate ? Icons.view_list : Icons.view_agenda),
            onPressed: () {
              setState(() {
                _groupByDate = !_groupByDate;
              });
            },
            tooltip: _groupByDate ? 'Show as list' : 'Group by date',
          ),
          // Filter Icon
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFiltersModal,
            tooltip: 'Filter history',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Date Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search food items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Date Range Button
                ElevatedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Filter Chips Display
          if (_selectedHealthRank != 'All' || _selectedAllergens.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_selectedHealthRank != 'All')
                    Chip(
                      label: Text(_selectedHealthRank),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _selectedHealthRank = 'All';
                        });
                        _applyFilters();
                      },
                    ),
                  ..._selectedAllergens.map((allergen) => Chip(
                    label: Text(allergen),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _selectedAllergens.remove(allergen);
                      });
                      _applyFilters();
                    },
                  )).toList(),
                ],
              ),
            ),
          
          // Date Range Display
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          
          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredItems.length} food items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          
          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          
          // Food History List
          Expanded(
            child: _filteredItems.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.no_food,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No food items found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : _groupByDate 
                ? ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: groupedItems.length,
                    itemBuilder: (context, index) {
                      final dateKey = groupedItems.keys.elementAt(index);
                      final items = groupedItems[dateKey]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              _getFormattedDate(dateKey),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          ...items.map((item) => _buildFoodItem(item)).toList(),
                        ],
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildFoodItem(_filteredItems[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 