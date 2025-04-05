import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:rive/rive.dart' as rive;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/medicine_info.dart';
import '../services/medicine_service.dart';
import '../utils/custom_colors.dart';
import './medicine_details_screen.dart';
import './medication_reminders_screen.dart';
import 'add_reminder_screen.dart';

class MedicineScannerScreen extends StatefulWidget {
  const MedicineScannerScreen({Key? key}) : super(key: key);

  @override
  _MedicineScannerScreenState createState() => _MedicineScannerScreenState();
}

class _MedicineScannerScreenState extends State<MedicineScannerScreen> {
  final MedicineService _medicineService = MedicineService();
  Uint8List? _capturedImage;
  MedicineInfo? _analyzedMedicine;
  bool _isProcessing = false;
  bool _isAnalyzing = false;
  String _errorMessage = '';
  bool _isCameraActive = false;

  @override
  void dispose() {
    super.dispose();
  }

  // Open camera to capture medicine image
  Future<void> _captureMedicineImage() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'Camera capture is not supported in web browsers.';
      });
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = '';
        // Use direct camera from image_picker
        _takePicture();
      });
    } catch (e) {
      print('Exception during camera access: $e');
      setState(() {
        _errorMessage = 'Could not access camera: $e';
        _isProcessing = false;
        _isCameraActive = false;
      });
    }
  }

  // Process the captured image from camera
  Future<void> _processCapturedImage(Uint8List? imageBytes) async {
    if (imageBytes == null) {
      setState(() {
        _errorMessage = 'Failed to capture image';
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _capturedImage = imageBytes;
      _isProcessing = false;
      _isAnalyzing = true;
    });

    // Extract text using OCR
    final extractedText = await _medicineService.extractTextFromImage(imageBytes);
    if (extractedText == null) {
      setState(() {
        _errorMessage = 'Failed to extract text from image';
        _isAnalyzing = false;
      });
      return;
    }

    // Analyze the extracted text
    final medicineInfo = await _medicineService.analyzeMedicineText(extractedText);
    setState(() {
      _analyzedMedicine = medicineInfo;
      _isAnalyzing = false;
      if (medicineInfo == null) {
        _errorMessage = 'Failed to analyze medicine. Please try again with a clearer image.';
      }
    });
  }

  // Select image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _isProcessing = true;
          _errorMessage = '';
        });
        
        final Uint8List bytes = await image.readAsBytes();
        await _processCapturedImage(bytes);
      }
    } catch (e) {
      print('Exception during gallery pick: $e');
      setState(() {
        _errorMessage = 'Could not pick image: $e';
        _isProcessing = false;
      });
    }
  }

  // Reset the scanner
  void _resetScanner() {
    setState(() {
      _capturedImage = null;
      _analyzedMedicine = null;
      _isProcessing = false;
      _isAnalyzing = false;
      _errorMessage = '';
    });
  }

  // Take a photo when camera is active
  Future<void> _takePicture() async {
    try {
      // Use ImagePicker directly
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      setState(() => _isCameraActive = false);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processCapturedImage(bytes);
      } else {
        setState(() {
          _errorMessage = 'Failed to capture image';
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error taking picture: $e');
      setState(() {
        _errorMessage = 'Error taking picture: $e';
        _isProcessing = false;
        _isCameraActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Medicine Scanner',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: 'Medication Reminders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MedicationRemindersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Main content container
              Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.all(2),
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Scanner heading
                        const Text(
                          "Medicine Scanner",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Scanner description
                        const Text(
                          "Scan medicine packaging to get information about its usage and precautions",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Display based on state
                        if (_analyzedMedicine != null)
                          _buildMedicineInfo()
                        else if (_capturedImage != null && _isAnalyzing)
                          _buildAnalyzingState()
                        else if (_capturedImage != null)
                          _buildCapturedImage()
                        else if (_isProcessing)
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.medication,
                            size: 80,
                            color: Colors.grey,
                          ),
                        
                        const SizedBox(height: 30),
                        
                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        
                        // Action buttons
                        if (_analyzedMedicine == null)
                          _buildActionButtons()
                        else
                          _buildResetButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showOptions,
        backgroundColor: const Color(0xFF2DCCA7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Option",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOption(
                    icon: Icons.camera_alt,
                    label: "Take Photo",
                    onTap: () {
                      Navigator.pop(context);
                      _captureMedicineImage();
                    },
                  ),
                  _buildOption(
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  _buildOption(
                    icon: Icons.alarm_add,
                    label: "Add Reminder",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const AddReminderScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2DCCA7).withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF2DCCA7),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

  // Widget to show the medicine analysis results
  Widget _buildMedicineInfo() {
    final medicine = _analyzedMedicine!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DCCA7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF2DCCA7),
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  medicine.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            "Description",
            style: TextStyle(
              color: Color(0xFF2DCCA7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medicine.description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            "Common Uses",
            style: TextStyle(
              color: Color(0xFF2DCCA7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medicine.commonUses,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Important Information",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  medicine.criticalInfo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Text(
                  "⚠️ Disclaimer",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  "This information is for educational purposes only. "
                  "Always consult a healthcare professional before taking any medication.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Add View Details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                backgroundColor: const Color(0xFF2DCCA7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicineDetailsScreen(
                      medicine: medicine,
                    ),
                  ),
                );
              },
              child: const Text(
                "View Detailed Information",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget to show the captured image
  Widget _buildCapturedImage() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _capturedImage!,
            width: 250,
            height: 250,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            backgroundColor: const Color(0xFF2DCCA7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            setState(() => _isAnalyzing = true);
            await _processCapturedImage(_capturedImage);
          },
          child: const Text(
            "Analyze Medicine",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Widget to show the analyzing state with animation
  Widget _buildAnalyzingState() {
    return Column(
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Display captured image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _capturedImage!,
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.5),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
              // Show CircularProgressIndicator for loading
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Analyzing Medicine...",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Please wait while we analyze the medicine details",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // Widget for scan buttons
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: const Color(0xFF2DCCA7),
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              "Take Photo",
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
            onPressed: kIsWeb ? null : _captureMedicineImage,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: const Color(0xFF1A1A1A),
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            label: const Text(
              "Gallery",
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
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              elevation: 0,
            ),
            onPressed: _pickImageFromGallery,
          ),
        ),
      ],
    );
  }

  // Widget for reset button
  Widget _buildResetButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.refresh, color: Colors.white),
      label: const Text(
        "Scan Another Medicine",
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
      onPressed: _resetScanner,
    );
  }

  // Widget to show the camera for capturing medicine images
  Widget _buildCameraWidget() {
    return Column(
      children: [
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black,
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Guide overlay
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2DCCA7),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.camera_alt,
                    color: Color(0xFF2DCCA7),
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Position the medicine packaging clearly in the frame",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            backgroundColor: const Color(0xFF2DCCA7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _takePicture,
          child: const Text(
            "Capture Image",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
} 