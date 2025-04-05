import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dotted_border/dotted_border.dart';
import '../services/food_facts_service.dart';
import '../models/open_food_facts_product.dart';
import '../models/food_item.dart';
import '../logic.dart';
import '../utils/custom_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final FoodFactsService _foodFactsService = FoodFactsService();
  final Logic _logic = Logic();
  String _scanBarcode = '';
  OpenFoodFactsProduct? _scannedProduct;
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _barcodeController = TextEditingController();
  bool _showManualEntry = false;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScannerActive = false;

  @override
  void initState() {
    super.initState();
    // Automatically show manual entry when running on web
    if (kIsWeb) {
      _showManualEntry = true;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // Method to handle camera scanning (for mobile devices)
  Future<void> _scanBarcodeWithCamera() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'Camera scanning is not supported in web browsers. Please use manual entry.';
        _showManualEntry = true;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _isScannerActive = true;
      });
    } on PlatformException catch (e) {
      print('Platform exception during barcode scan: $e');
      setState(() {
        _errorMessage = 'Could not access camera: ${e.message}';
        _isLoading = false;
        _isScannerActive = false;
      });
    } catch (e) {
      print('Exception during barcode scan: $e');
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
        _isScannerActive = false;
      });
    }
  }

  // Handle barcode detection
  void _onDetect(BarcodeCapture capture) {
    if (!_isScannerActive) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null) return;

    _scannerController.stop();
    
    setState(() {
      _scanBarcode = barcode;
      _isScannerActive = false;
    });

    _lookupProductByBarcode(barcode);
  }

  // Method to handle manual barcode entry
  Future<void> _searchManualBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a barcode number';
      });
      return;
    }

    setState(() {
      _scanBarcode = barcode;
      _isLoading = true;
      _errorMessage = '';
    });

    await _lookupProductByBarcode(barcode);
  }

  // Common method to lookup product data by barcode
  Future<void> _lookupProductByBarcode(String barcode) async {
    try {
      print('Fetching product data for barcode: $barcode');
      final product = await _foodFactsService.getProductByBarcode(barcode);
      print('Product data received: ${product != null ? 'Found' : 'Not found'}');

      setState(() {
        _scannedProduct = product;
        _isLoading = false;
        if (product == null) {
          _errorMessage = 'Product not found. Try a different barcode or search by name.';
        }
      });
    } catch (e) {
      print('Exception during barcode lookup: $e');
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _addProductToLog() {
    if (_scannedProduct != null) {
      try {
        print('Converting product to food item format');
        // Convert to food item format and add to log
        final foodItemData = _scannedProduct!.toFoodItem();
        print('Food item data: $foodItemData');
        final foodItem = FoodItem.fromJson(foodItemData);
        print('Adding food item to log: ${foodItem.name}');
        _logic.addFoodItem(foodItem);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added to your food log'),
            backgroundColor: Color(0xFF2DCCA7),
          ),
        );

        // Navigate back to home
        Navigator.pop(context);
      } catch (e) {
        print('Error adding product to log: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Main content container with dotted border
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.transparent),
                ),
                child: DottedBorder(
                  borderPadding: const EdgeInsets.all(-20),
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(20),
                  color: Colors.grey.withOpacity(0.4),
                  strokeWidth: 1,
                  dashPattern: const [6, 4],
        child: Column(
                    children: [
                      SizedBox(height: 40),
                      // Display product image if found, else display barcode icon or scanner
                      if (_scannedProduct != null && _scannedProduct!.imageUrl != null && !_isLoading)
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
                            child: CachedNetworkImage(
                              imageUrl: _scannedProduct!.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.black45,
                                highlightColor: Colors.black26,
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported,
                                size: 70,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else if (_isLoading && !_isScannerActive)
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      else if (_isScannerActive)
                        // Mobile scanner widget
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                        )
                      else
                        Icon(
                          Icons.qr_code_scanner,
                          size: 80,
                          color: Colors.grey,
                        ),
                      
                      const SizedBox(height: 30),
                      
                      // Instruction text
                      Text(
                        "Scan a product barcode or choose from gallery",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Scan buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
          children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: const Color(0xFF2DCCA7),
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt, color: Colors.white),
                              label: const Text("Take Photo",
                                  style: TextStyle(
                                    fontFamily: 'Poppins', 
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  )
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                backgroundColor: const Color(0xFF2DCCA7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: kIsWeb ? null : _scanBarcodeWithCamera,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: const Color(0xFF1A1A1A),
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library, color: Colors.white),
                              label: const Text("Gallery",
                                  style: TextStyle(
                                    fontFamily: 'Poppins', 
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  )
                              ),
                style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                backgroundColor: const Color(0xFF1A1A1A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _errorMessage = 'Gallery barcode scanning coming soon!';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Manual entry section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _showManualEntry = !_showManualEntry;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "Manual Entry",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 16
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Manual entry field (shown when _showManualEntry is true)
              if (_showManualEntry)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Barcode Manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                    ),
                        child: TextField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        hintText: 'e.g., 5000112637922',
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                        ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _searchManualBarcode,
                        ),
                      ),
                          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _searchManualBarcode(),
                    ),
                      ),
                      const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2DCCA7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _searchManualBarcode,
                          child: const Text('Search Product', style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    ),
                  ],
              ),
            ),
              
            // Display scan status
              if (_scanBarcode.isNotEmpty && !_isLoading)
              Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  'Barcode: $_scanBarcode',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Poppins'),
                    textAlign: TextAlign.center,
                ),
              ),
              
            // Show error message
            if (_errorMessage.isNotEmpty && !_isLoading)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Text(
                  _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 16, fontFamily: 'Poppins'),
                  textAlign: TextAlign.center,
                ),
              ),
              
            // Show product details if found
            if (_scannedProduct != null && !_isLoading)
                Container(
                  margin: const EdgeInsets.all(20),
                  child: Card(
                    color: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name and brand
                          Text(
                            _scannedProduct!.productName ?? 'Unknown Product',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (_scannedProduct!.brands != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                _scannedProduct!.brands!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF2D2D2D)),
                          const SizedBox(height: 16),
                          
                          // Nutrition facts
                          const Text(
                            'Nutrition Facts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          if (_scannedProduct!.nutriments != null) ...[
                            _buildNutrientRow('Calories', '${_scannedProduct!.nutriments!['energy-kcal'] ?? (_scannedProduct!.nutriments!['energy-kj'] != null ? ((_scannedProduct!.nutriments!['energy-kj'] / 4.184).round()) : 'N/A')}${_scannedProduct!.nutriments!.containsKey('energy-kcal') ? ' kcal' : ' kcal*'}'),
                            _buildNutrientRow('Fat', '${_scannedProduct!.nutriments!['fat'] ?? 'N/A'} g'),
                            _buildNutrientRow('Saturated Fat', '${_scannedProduct!.nutriments!['saturated-fat'] ?? 'N/A'} g'),
                            _buildNutrientRow('Carbohydrates', '${_scannedProduct!.nutriments!['carbohydrates'] ?? 'N/A'} g'),
                            _buildNutrientRow('Sugars', '${_scannedProduct!.nutriments!['sugars'] ?? 'N/A'} g'),
                            _buildNutrientRow('Fiber', '${_scannedProduct!.nutriments!['fiber'] ?? 'N/A'} g'),
                            _buildNutrientRow('Proteins', '${_scannedProduct!.nutriments!['proteins'] ?? 'N/A'} g'),
                            _buildNutrientRow('Salt', '${_scannedProduct!.nutriments!['salt'] ?? 'N/A'} g'),
                          ] else
                            const Text(
                              'No nutrition information available',
                              style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
                            ),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF2D2D2D)),
                          const SizedBox(height: 16),
                          
                          // Ingredients
                          const Text(
                            'Ingredients',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            _scannedProduct!.ingredientsText ?? 'No ingredients information available',
                            style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
                          ),
                          
                          if (_scannedProduct!.allergens != null && _scannedProduct!.allergens!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Allergens',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _scannedProduct!.allergens!.map((allergen) => Chip(
                                label: Text(allergen),
                                backgroundColor: Colors.red.shade800,
                                labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                              )).toList(),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Add to log button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2DCCA7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _addProductToLog,
                              child: const Text('Add to Food Log', style: TextStyle(fontFamily: 'Poppins')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
              // Add padding at the bottom
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
              ),
        ),
      ),
    );
  }
  
  Widget _buildNutrientRow(String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }
} 