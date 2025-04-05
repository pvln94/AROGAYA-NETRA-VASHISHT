import 'package:flutter/material.dart';
import 'package:read_the_label/logic.dart';

class AllergenSection extends StatelessWidget {
  final Logic logic;
  
  const AllergenSection({
    Key? key,
    required this.logic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: logic.allergensNotifier,
      builder: (context, userAllergens, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: logic.hasAllergenWarningNotifier,
          builder: (context, hasWarning, _) {
            // Only show section if user has allergens configured or there are detected allergens
            if (userAllergens.isEmpty && logic.detectedAllergens.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: hasWarning ? const Color(0xFFFF5252) : const Color(0xFFFFAB40),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Allergen Information",
                          style: TextStyle(
                            color: Theme.of(context).textTheme.titleLarge!.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Display allergen information content
                  _buildAllergenContent(context, userAllergens, hasWarning),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildAllergenContent(BuildContext context, List<String> userAllergens, bool hasWarning) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hasWarning ? Colors.red.shade700 : Colors.orange.shade700,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Row(
                children: [
                  Icon(
                    hasWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: hasWarning ? Colors.red.shade500 : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasWarning 
                          ? "Allergens Detected" 
                          : "Your Allergen Profile",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Detected allergens
              if (hasWarning && logic.detectedAllergens.isNotEmpty)
                _buildAllergenList(
                  context, 
                  "Detected allergens:", 
                  logic.detectedAllergens, 
                  Colors.red.shade500
                ),
              
              // User's allergen list
              if (userAllergens.isNotEmpty)
                _buildAllergenList(
                  context, 
                  hasWarning ? "Your allergen sensitivities:" : "You're sensitive to:",
                  userAllergens,
                  Colors.orange.shade400
                ),
              
              // Action button
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _showAllergenDetails(context);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text(
                    "More Details",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAllergenList(
    BuildContext context, 
    String title, 
    List<String> allergens, 
    Color iconColor
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        ...allergens.map((allergen) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.arrow_right,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  allergen,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
  
  void _showAllergenDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              "Allergen Information",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This section shows information about allergens that you've set in your profile and any allergens detected in the food items you scan.",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "You can update your allergen profile at any time by tapping the allergen icon in the app bar.",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Close",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 