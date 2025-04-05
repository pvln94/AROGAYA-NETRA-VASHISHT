import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:read_the_label/main.dart';
import 'package:read_the_label/models/food_item.dart';
import 'package:read_the_label/screens/ask_AI_page.dart';
import 'package:read_the_label/screens/barcode_scanner_screen.dart';
import 'package:read_the_label/screens/food_features_screen.dart';
import 'package:read_the_label/screens/food_history_screen.dart';
import 'package:read_the_label/screens/medicine_scanner_screen.dart';
import 'package:read_the_label/screens/medication_reminders_screen.dart';
import 'package:read_the_label/screens/search_screen.dart';
import 'package:read_the_label/widgets/allergen_section.dart';
import 'package:read_the_label/widgets/allergen_selection_dialog.dart';
import 'package:read_the_label/widgets/allergen_warning_card.dart';
import 'package:read_the_label/widgets/ask_ai_widget.dart';
import 'package:read_the_label/widgets/food_item_card_shimmer.dart';
import 'package:read_the_label/widgets/nutrient_info_shimmer.dart';
import 'package:read_the_label/widgets/total_nutrients_card_shimmer.dart';
import 'package:read_the_label/widgets/date_selector.dart';
import 'package:read_the_label/widgets/detailed_nutrients_card.dart';
import 'package:read_the_label/widgets/food_history_card.dart';
import 'package:read_the_label/widgets/food_item_card.dart';
import 'package:read_the_label/widgets/header_widget.dart';
import 'package:read_the_label/widgets/macronutrien_summary_card.dart';
import 'package:read_the_label/widgets/nutrient_balance_card.dart';
import 'package:read_the_label/widgets/nutrient_tile.dart';
import 'package:read_the_label/data/nutrient_insights.dart';
import 'package:read_the_label/widgets/total_nutrients_card.dart';
import 'package:rive/rive.dart' as rive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:read_the_label/logic.dart';
import 'widgets/portion_buttons.dart';
import 'package:read_the_label/utils/custom_colors.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _selectedFile;
  final ImagePicker imagePicker = ImagePicker();
  final Logic _logic = Logic();
  int _currentIndex = 0;
  int _scanTypeIndex = 0; // 0: Label, 1: Food, 2: Barcode
  final _duration = const Duration(milliseconds: 300);
  bool _initialSetupComplete = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _logic.loadFoodHistory();
    await _logic.loadUserAllergens();
    
    // Check if it's the first app launch
    final isFirstLaunch = await _logic.isFirstLaunch();
    if (isFirstLaunch) {
      // Delay to ensure the UI is fully built
      Future.delayed(Duration(milliseconds: 500), () {
        _showAllergenSelectionDialog();
      });
    } else {
      setState(() {
        _initialSetupComplete = true;
      });
    }
  }

  void _showAllergenSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must select an option
      builder: (BuildContext context) {
        return AllergenSelectionDialog(
          logic: _logic,
          onComplete: () {
            Navigator.of(context).pop();
            setState(() {
              _initialSetupComplete = true;
            });
          },
        );
      },
    );
  }

  // Show scan options modal sheet
  void _showScanOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // Allow the sheet to adapt to its content
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Choose Scan Type",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScanOption(
                        icon: Icons.document_scanner,
                        label: "Label Scan",
                        index: 0,
                      ),
                      _buildScanOption(
                        icon: Icons.restaurant,
                        label: "Food Scan",
                        index: 1,
                      ),
                      _buildScanOption(
                        icon: Icons.qr_code_scanner,
                        label: "Barcode Scan",
                        index: 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScanOption(
                        icon: Icons.medication,
                        label: "Medicine Scan",
                        index: 3,
                      ),
                      _buildScanOption(
                        icon: Icons.alarm,
                        label: "Med Reminders",
                        index: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build individual scan option button
  Widget _buildScanOption({
    required IconData icon, 
    required String label, 
    required int index
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        _openScanType(index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Open the selected scan type
  void _openScanType(int index) {
    // Clear the previous scan data before switching
    if (_scanTypeIndex != index) {
      _logic.resetImages();
      _logic.analyzedFoodItems.clear();
      _logic.goodNutrients.clear();
      _logic.badNutrients.clear();
    }
    
    setState(() {
      _scanTypeIndex = index;
      _currentIndex = 0; // Always set to the first tab which is Scan
    });
    
    // Handle different scan types
    if (index == 0) {
      // Label Scan - already handled by default view
    } else if (index == 1) {
      // Food Scan
      setState(() {
        _currentIndex = 0; // Show in the scan tab
      });
    } else if (index == 2) {
      // Barcode Scan - Open the barcode scanner directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      ).then((_) {
        // When returning from the barcode scanner, refresh the UI
        setState(() {});
      });
    } else if (index == 3) {
      // Medicine Scan - Open the medicine scanner directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MedicineScannerScreen(),
        ),
      ).then((_) {
        // When returning from the medicine scanner, refresh the UI
        setState(() {});
      });
    } else if (index == 4) {
      // Medication Reminders - Open the medication reminders screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MedicationRemindersScreen(),
        ),
      ).then((_) {
        // When returning from the reminders screen, refresh the UI
        setState(() {});
      });
    }
  }

  void _handleImageCapture(ImageSource source) async {
    // First, capture front image
    await _logic.captureImage(
      source: source,
      isFrontImage: true,
      setState: setState,
    );

    if (_logic.frontImage != null) {
      // Show dialog for nutrition label
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Now capture nutrition label',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Poppins'),
            ),
            content: Text(
              'Please capture or select the nutrition facts label of the product',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontFamily: 'Poppins'),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _logic.captureImage(
                    source: source,
                    isFrontImage: false,
                    setState: setState,
                  );
                  if (_logic.canAnalyze()) {
                    _analyzeImages();
                  }
                },
                child: const Text('Continue',
                    style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
        );
      }
    }
  }

  void _analyzeImages() {
    if (_logic.canAnalyze()) {
      _logic.analyzeImages(setState: setState);
    }
  }

  // Switch between main tabs (Scan, Daily Intake, Search)
  void _switchMainTab(int index) {
    if (index == 0) {
      // If Scan tab is tapped, show scan options
      _showScanOptionsSheet();
      return;
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  // Get the title for the current view
  String get _currentTitle {
    if (_currentIndex == 0) {
      // Scan tab
      return ['Label Scan', 'Food Scan', 'Barcode Scan', 'Medicine Scan', 'Med Reminders'][_scanTypeIndex];
    } else if (_currentIndex == 1) {
      return 'Daily Intake';
    } else if (_currentIndex == 2) {
      return 'Food History';
    } else {
      return 'Search';
    }
  }

  // Get the current body content
  Widget _getCurrentBody() {
    if (_currentIndex == 0) {
      // Scan tab - show the appropriate scan type
      if (_scanTypeIndex == 0) {
        return _buildHomePage(context); // Label Scan
      } else if (_scanTypeIndex == 1) {
        return FoodScanPage(logic: _logic); // Food Scan
      } else if (_scanTypeIndex == 2) {
        // Fallback to Label Scan if barcode scan is selected
        // (Barcode scan uses a separate screen)
        return _buildHomePage(context);
      } else if (_scanTypeIndex == 3) {
        // For Medicine Scan, show label scan as the content (Medicine scanner is opened in a separate screen)
        return _buildHomePage(context);
      } else {
        // For Med Reminders, show label scan as the content (Reminders are opened in a separate screen)
        return _buildHomePage(context);
      }
    } else if (_currentIndex == 1) {
      // Daily Intake tab
      return DailyIntakePage(dailyIntake: _logic.dailyIntake);
    } else if (_currentIndex == 2) {
      // Food History tab
      return FoodHistoryScreen(logic: _logic);
    } else {
      // Search tab - navigate to SearchScreen
      return SearchScreen(logic: _logic);
    }
  }

  @override
  Widget build(BuildContext context) {
    _logic.setSetState(setState);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          _currentTitle,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500),
        ),
        actions: [
          // Add settings icon for allergen management
          IconButton(
            icon: Icon(Icons.warning_amber),
            tooltip: 'Manage Allergens',
            onPressed: _showAllergenManagementDialog,
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        color: Theme.of(context).colorScheme.surface,
        child: AnimatedSwitcher(
          duration: _duration,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _getCurrentBody(),
        ),
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.cardBackground,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: BottomNavigationBar(
              elevation: 0,
              selectedLabelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Colors.grey,
              currentIndex: _currentIndex,
              onTap: _switchMainTab,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.document_scanner),
                  label: 'Scan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: 'Daily Intake',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: _showScanOptionsSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
  
  // New method to show allergen management dialog
  void _showAllergenManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Manage Allergens',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your allergens:',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<List<String>>(
                valueListenable: _logic.allergensNotifier,
                builder: (context, allergens, child) {
                  if (allergens.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No allergens set. Tap "Edit" to add allergens.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Poppins',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }
                  
                  return Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: allergens.map((allergen) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 10,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    allergen,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
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
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAllergenSelectionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              "Edit",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Rename these methods to avoid conflicts with our new methods
  
  Widget _buildLabelScanContent() {
    // Original content of the label scan page
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... existing content ...
      ],
    );
  }
  
  Widget _buildFoodScanContent() {
    // Original content of the food scan page
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... existing content ...
      ],
    );
  }

  Widget _buildHomePage(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 100),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.transparent),
              ),
              child: DottedBorder(
                borderPadding: const EdgeInsets.all(-20),
                borderType: BorderType.RRect,
                radius: const Radius.circular(20),
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                strokeWidth: 1,
                dashPattern: const [6, 4],
                child: Column(
                  children: [
                    if (_logic.frontImage != null)
                      Stack(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: kIsWeb && _logic.frontImage.runtimeType.toString().contains('XFile')
                                  ? FutureBuilder<Uint8List>(
                                      future: _logic.frontImage.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        } else if (snapshot.hasError || !snapshot.hasData) {
                                          return Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 70,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          );
                                        } else {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            width: 200,
                                            height: 200,
                                          );
                                        }
                                      },
                                    )
                                  : Image(
                                      image: _logic.getImageProvider(_logic.frontImage),
                                      fit: BoxFit.cover,
                                      width: 200,
                                      height: 200,
                                    ),
                            ),
                          ),
                          if (_logic.getIsLoading())
                            Positioned.fill(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Center(
                                  child: rive.RiveAnimation.asset(
                                    'assets/riveAssets/qr_code_scanner.riv',
                                    fit: BoxFit.contain,
                                    artboard: 'scan_board',
                                    animations: ['anim1'],
                                    stateMachines: ['State Machine 1'],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Icon(
                        Icons.document_scanner,
                        size: 70,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      "To get started, scan product front or choose from gallery!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 20),
                    _buildImageCaptureButtons(),
                  ],
                ),
              ),
            ),
            if (_logic.getIsLoading()) const NutrientInfoShimmer(),

            //Good/Moderate nutrients
            if (_logic.getGoodNutrients().isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _logic.productName,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 24),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    // Health Score Section for Label Scan
                    if (_logic.analyzedFoodItems.isNotEmpty && _logic.analyzedFoodItems.first.hasHealthScore)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                                  onTap: () => _showHealthScoreDetails(_logic.analyzedFoodItems.first),
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
                                // Health Score Badge
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(_logic.analyzedFoodItems.first.healthScore!.rankColor.replaceFirst('#', '0xff'))),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _logic.analyzedFoodItems.first.healthScore!.score.toInt().toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Health Score Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _logic.analyzedFoodItems.first.healthScore!.rankName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(int.parse(_logic.analyzedFoodItems.first.healthScore!.rankColor.replaceFirst('#', '0xff'))),
                                        ),
                                      ),
                                      Text(
                                        _logic.analyzedFoodItems.first.healthScore!.shortDescription,
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
                            const SizedBox(height: 12),
                            // Health score recommendation
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(int.parse(_logic.analyzedFoodItems.first.healthScore!.rankColor.replaceFirst('#', '0xff'))).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _logic.analyzedFoodItems.first.healthScore!.primaryRecommendation,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Optimal Nutrients",
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.titleLarge!.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _logic
                            .getGoodNutrients()
                            .map((nutrient) => NutrientTile(
                                  nutrient: nutrient['name'],
                                  healthSign: nutrient['health_impact'],
                                  quantity: nutrient['quantity'],
                                  insight: nutrientInsights[nutrient['name']],
                                  dailyValue: nutrient['daily_value'],
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),

            // Add the AllergenSection right after the Optimal Nutrients section
            if (_logic.getGoodNutrients().isNotEmpty)
              AllergenSection(logic: _logic),

            //Bad nutrients
            if (_logic.getBadNutrients().isNotEmpty)
              Container(
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
                              color: const Color(0xFFFF5252), // Red accent bar
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Watch Out",
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.titleLarge!.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _logic
                            .getBadNutrients()
                            .map((nutrient) => NutrientTile(
                                  nutrient: nutrient['name'],
                                  healthSign: nutrient['health_impact'],
                                  quantity: nutrient['quantity'],
                                  insight: nutrientInsights[nutrient['name']],
                                  dailyValue: nutrient['daily_value'],
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            if (_logic.getBadNutrients().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                            255, 94, 255, 82), // Red accent bar
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Recommendations",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge!.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            if (_logic.nutritionAnalysis != null &&
                _logic.nutritionAnalysis['primary_concerns'] != null)
              ..._logic.nutritionAnalysis['primary_concerns'].map(
                (concern) => NutrientBalanceCard(
                  issue: concern['issue'] ?? '',
                  explanation: concern['explanation'] ?? '',
                  recommendations: (concern['recommendations'] as List?)
                          ?.map((rec) => {
                                'food': rec['food'] ?? '',
                                'quantity': rec['quantity'] ?? '',
                                'reasoning': rec['reasoning'] ?? '',
                              })
                          .toList() ??
                      [],
                ),
              ),

            if (_logic.getServingSize() > 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          "Serving Size: ${_logic.getServingSize().round()} g",
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                              fontSize: 16,
                              fontFamily: 'Poppins'),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit,
                              color:
                                  Theme.of(context).textTheme.titleSmall!.color,
                              size: 20),
                          onPressed: () {
                            // Show edit dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .cardBackground,
                                title: Text('Edit Serving Size',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .color,
                                        fontFamily: 'Poppins')),
                                content: TextField(
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .color),
                                  decoration: InputDecoration(
                                    hintText: 'Enter serving size in grams',
                                    hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .color,
                                        fontFamily: 'Poppins'),
                                  ),
                                  onChanged: (value) {
                                    _logic.updateServingSize(
                                        double.tryParse(value) ?? 0.0);
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    child: Text('OK',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .color)),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "How much did you consume?",
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium!.color,
                            fontSize: 16,
                            fontFamily: 'Poppins'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        PortionButton(
                          context: context,
                          portion: 0.25,
                          label: "¼",
                          logic: _logic,
                          setState: setState,
                        ),
                        PortionButton(
                          context: context,
                          portion: 0.5,
                          label: "½",
                          logic: _logic,
                          setState: setState,
                        ),
                        PortionButton(
                          context: context,
                          portion: 0.75,
                          label: "¾",
                          logic: _logic,
                          setState: setState,
                        ),
                        PortionButton(
                          context: context,
                          portion: 1.0,
                          label: "1",
                          logic: _logic,
                          setState: setState,
                        ),
                        // CustomPortionButton(
                        //   logic: _logic,
                        //   setState: setState,
                        // ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            minimumSize: const Size(
                                200, 50), // Set minimum width and height
                          ),
                          onPressed: () {
                            _logic.addToDailyIntake(context, (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                            }, 'label');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Added to today\'s intake!'), // Updated message
                                action: SnackBarAction(
                                  label:
                                      'VIEW', // Changed from 'SHOW' to 'VIEW'
                                  onPressed: () {
                                    setState(() {
                                      _currentIndex = 2;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add to today's intake",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "${_logic.sliderValue.toStringAsFixed(0)} grams, ${(_logic.getCalories() * (_logic.sliderValue / _logic.getServingSize())).toStringAsFixed(0)} calories",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (_logic.getServingSize() == 0 &&
                _logic.parsedNutrients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Serving size not found, please enter it manually',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _logic.updateSliderValue(
                              double.tryParse(value) ?? 0.0, setState);
                        });
                      },
                      decoration: const InputDecoration(
                          hintText: "Enter serving size in grams or ml",
                          hintStyle: TextStyle(color: Colors.white54)),
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (_logic.getServingSize() > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Slider(
                            value: _logic.sliderValue,
                            min: 0,
                            max: _logic.getServingSize(),
                            onChanged: (newValue) {
                              _logic.updateSliderValue(newValue, setState);
                            }),
                      ),
                    if (_logic.getServingSize() > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Serving Size: ${_logic.getServingSize().round()} g",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                    if (_logic.getServingSize() > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Builder(
                          builder: (context) {
                            return ElevatedButton(
                                style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                        Colors.white10)),
                                onPressed: () {
                                  _logic.addToDailyIntake(context, (index) {
                                    setState(() {
                                      _currentIndex = index;
                                    });
                                  }, 'label');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Added to today\'s intake!',
                                          style:
                                              TextStyle(fontFamily: 'Poppins')),
                                      action: SnackBarAction(
                                        label: 'SHOW',
                                        onPressed: () {
                                          setState(() {
                                            _currentIndex = 1;
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("Add to today's intake",
                                    style: TextStyle(fontFamily: 'Poppins')));
                          },
                        ),
                      ),
                  ],
                ),
              ),
            if (_logic.getServingSize() > 0)
              InkWell(
                onTap: () {
                  print("Tap detected!");
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AskAiPage(
                        mealName: _logic.productName,
                        foodImage: _logic.frontImage!,
                        logic: _logic,
                      ),
                    ),
                  );
                },
                child: const AskAiWidget(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptureButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt, color: Colors.white),
          label: const Text("Take Photo",
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w400)),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => _handleImageCapture(ImageSource.camera),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          icon: Icon(Icons.photo_library,
              color: Theme.of(context).colorScheme.onSurface),
          label: const Text("Gallery",
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w400)),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Theme.of(context).colorScheme.cardBackground,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => _handleImageCapture(ImageSource.gallery),
        ),
      ],
    );
  }

  void _showHealthScoreDetails(FoodItem foodItem) {
    final healthScore = foodItem.healthScore!;
    
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
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(int.parse(healthScore.rankColor.replaceFirst('#', '0xff'))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          healthScore.score.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                        Text(
                          healthScore.rankName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  healthScore.rankDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Health Score Breakdown
                if (healthScore.positiveFactors.isNotEmpty) ...[
                  _buildFactorList(
                    context, 
                    'Positive Factors', 
                    healthScore.positiveFactors,
                    true,
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (healthScore.negativeFactors.isNotEmpty) ...[
                  _buildFactorList(
                    context, 
                    'Negative Factors', 
                    healthScore.negativeFactors,
                    false,
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (healthScore.benefits.isNotEmpty ||
                    healthScore.concerns.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (healthScore.benefits.isNotEmpty)
                        Expanded(
                          child: _buildBulletList(
                            context,
                            'Benefits',
                            healthScore.benefits,
                            Colors.green,
                          ),
                        ),
                      const SizedBox(width: 16),
                      if (healthScore.concerns.isNotEmpty)
                        Expanded(
                          child: _buildBulletList(
                            context,
                            'Concerns',
                            healthScore.concerns,
                            Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
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
}

class FoodScanPage extends StatefulWidget {
  final Logic logic;

  const FoodScanPage({
    required this.logic,
    super.key,
  });

  @override
  State<FoodScanPage> createState() => _FoodScanPageState();
}

class _FoodScanPageState extends State<FoodScanPage> {
  int _currentIndex = 1;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            // Scanning Section
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.transparent),
              ),
              child: DottedBorder(
                borderPadding: const EdgeInsets.all(-20),
                borderType: BorderType.RRect,
                radius: const Radius.circular(20),
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                strokeWidth: 1,
                dashPattern: const [6, 4],
                child: Column(
                  children: [
                    if (widget.logic.isAnalyzing)
                      const CircularProgressIndicator()
                    else if (widget.logic.foodImage != null)
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb && widget.logic.foodImage.runtimeType.toString().contains('XFile')
                              ? FutureBuilder<Uint8List>(
                                  future: widget.logic.foodImage.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    } else if (snapshot.hasError || !snapshot.hasData) {
                                      return Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 70,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      );
                                    } else {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        width: 200,
                                        height: 200,
                                      );
                                    }
                                  },
                                )
                              : Image(
                                  image: widget.logic.getImageProvider(widget.logic.foodImage),
                                  fit: BoxFit.cover,
                                  width: 200,
                                  height: 200,
                                ),
                        ),
                      )
                    else
                      Icon(
                        Icons.restaurant_outlined,
                        size: 70,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      "Snap a picture of your meal or pick one from your gallery",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildImageCaptureButtons(),
                  ],
                ),
              ),
            ),

            //Loading animation
            if (widget.logic.getIsLoading())
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Analysis Results',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                  const FoodItemCardShimmer(),
                  const FoodItemCardShimmer(),
                  const TotalNutrientsCardShimmer(),
                ],
              ),
            // Results Section
            if (widget.logic.analyzedFoodItems.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Analysis Results',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.logic.analyzedFoodItems.map((item) => FoodItemCard(
                      item: item, setState: setState, logic: widget.logic)),
                  
                  // Add the AllergenSection after the food item cards
                  AllergenSection(logic: widget.logic),
                  
                  TotalNutrientsCard(
                    logic: widget.logic,
                    updateIndex: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                  // Only show Ask AI widget if there's a food image
                  if (widget.logic.foodImage != null)
                    InkWell(
                      onTap: () {
                        print("Tap detected!");
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => AskAiPage(
                              mealName: widget.logic.mealName,
                              foodImage: widget.logic.foodImage!,
                              logic: widget.logic,
                            ),
                          ),
                        );
                      },
                      child: const AskAiWidget(),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptureButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: Icon(Icons.camera_alt_outlined,
              color: Theme.of(context).colorScheme.onPrimary),
          label: const Text(
            "Take Photo",
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          ),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => _handleFoodImageCapture(ImageSource.camera),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          icon: Icon(Icons.photo_library,
              color: Theme.of(context).colorScheme.onPrimary),
          label: const Text(
            "Gallery",
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400),
          ),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Theme.of(context).colorScheme.cardBackground,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => _handleFoodImageCapture(ImageSource.gallery),
        ),
      ],
    );
  }

  void _handleFoodImageCapture(ImageSource source) async {
    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: source);

    if (image != null) {
      if (mounted) {
        setState(() {
          if (kIsWeb) {
            // On web, store the XFile directly
            widget.logic.foodImage = image as dynamic;
          } else {
            // On mobile, create a File object
            widget.logic.foodImage = File(image.path);
          }
        });
      }
      await widget.logic.analyzeFoodImage(
        imageFile: widget.logic.foodImage!,
        setState: (fn) {
          if (mounted) {
            setState(fn);
          }
        },
        mounted: mounted,
      );
    }
  }
}

class DailyIntakePage extends StatefulWidget {
  final Map<String, double> dailyIntake;
  const DailyIntakePage({super.key, required this.dailyIntake});

  @override
  State<DailyIntakePage> createState() => _DailyIntakePageState();
}

class _DailyIntakePageState extends State<DailyIntakePage> {
  late Map<String, double> _dailyIntake;
  DateTime _selectedDate = DateTime.now();
  final Logic logic = Logic();
  final int _currentIndex = 2;

  @override
  void initState() {
    super.initState();
    _dailyIntake = widget.dailyIntake;
    _initializeData();
    logic.dailyIntakeNotifier.addListener(_onDailyIntakeChanged);
  }

  void _onDailyIntakeChanged() {
    if (mounted) {
      setState(() {
        _dailyIntake = Map.from(logic.dailyIntakeNotifier.value);
      });
    }
  }

  @override
  void dispose() {
    logic.dailyIntakeNotifier.removeListener(_onDailyIntakeChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    print("Initializing DailyIntakePage data...");

    // Debug check storage
    await logic.debugCheckStorage();

    // Load food history first
    print("Loading food history...");
    await logic.loadFoodHistory();

    // Then load daily intake for selected date
    print("Loading daily intake for selected date...");
    await _loadDailyIntake(DateTime.now());

    if (mounted) {
      setState(() {
        print("State updated after initialization");
        print("Current daily intake: $_dailyIntake");
        print("Current food history: ${logic.foodHistory}");
      });
    }
  }

  Future<void> _loadDailyIntake(DateTime date) async {
    print("Loading daily intake for date: ${date.toString()}");
    final String storageKey = logic.getStorageKey(date);
    print("Storage key: $storageKey");

    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString(storageKey);
    print("Stored data from SharedPreferences: $storedData");

    if (storedData != null) {
      print("Found stored data, processing...");
      final Map<String, dynamic> decoded = jsonDecode(storedData);
      final Map<String, double> dailyIntake = {};

      decoded.forEach((key, value) {
        print("Converting $key: $value (${value.runtimeType}) to double");
        dailyIntake[key] = (value as num).toDouble();
      });

      if (mounted) {
        setState(() {
          _selectedDate = date;
          _dailyIntake = dailyIntake;
          logic.dailyIntake = dailyIntake;
          print("State updated with dailyIntake: $_dailyIntake");
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedDate = date;
          _dailyIntake = {};
          logic.dailyIntake = {};
          print("Reset to empty dailyIntake");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          top: MediaQuery.of(context).padding.top + 10,
        ),
        child: Column(
          children: [
            HeaderCard(context, _selectedDate),
            DateSelector(
              context,
              _selectedDate,
              (DateTime newDate) {
                setState(() {
                  _selectedDate = newDate;
                  _loadDailyIntake(newDate);
                });
              },
            ),
            MacronutrientSummaryCard(context, _dailyIntake),
            FoodHistoryCard(
                context: context,
                currentIndex: _currentIndex,
                logic: logic,
                selectedDate: _selectedDate),
            DetailedNutrientsCard(context, _dailyIntake),
          ],
        ),
      ),
    );
  }
}
