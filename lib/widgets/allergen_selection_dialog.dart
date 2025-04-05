import 'package:flutter/material.dart';
import 'package:read_the_label/logic.dart';

class AllergenSelectionDialog extends StatefulWidget {
  final Logic logic;
  final Function onComplete;

  const AllergenSelectionDialog({
    Key? key,
    required this.logic,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<AllergenSelectionDialog> createState() => _AllergenSelectionDialogState();
}

class _AllergenSelectionDialogState extends State<AllergenSelectionDialog> {
  final List<String> commonAllergens = [
    'Dairy',
    'Eggs',
    'Peanuts',
    'Tree nuts',
    'Soy',
    'Wheat',
    'Gluten',
    'Fish',
    'Shellfish',
    'Sesame',
    'Mustard',
    'Celery',
    'Lupin',
    'Sulphites',
  ];

  final List<String> selectedAllergens = [];
  final TextEditingController _customAllergenController = TextEditingController();

  @override
  void dispose() {
    _customAllergenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Do you have any food allergies?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "We'll notify you if any food you scan contains your allergens.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: commonAllergens.map((allergen) {
                    final isSelected = selectedAllergens.contains(allergen);
                    return FilterChip(
                      label: Text(allergen),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedAllergens.add(allergen);
                          } else {
                            selectedAllergens.remove(allergen);
                          }
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                        fontFamily: 'Poppins',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customAllergenController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add other allergen...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final newAllergen = _customAllergenController.text.trim();
                    if (newAllergen.isNotEmpty && !selectedAllergens.contains(newAllergen)) {
                      setState(() {
                        selectedAllergens.add(newAllergen);
                        _customAllergenController.clear();
                      });
                    }
                  },
                  icon: Icon(
                    Icons.add_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Skip allergen selection
                    widget.logic.saveUserAllergens([]);
                    widget.onComplete();
                  },
                  child: Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save selected allergens
                    await widget.logic.saveUserAllergens(selectedAllergens);
                    widget.onComplete();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 