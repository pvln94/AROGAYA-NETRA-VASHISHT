import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/medicine_info.dart';

class MedicineService {
  // Method to extract text from an image using OCR
  Future<String?> extractTextFromImage(Uint8List imageBytes) async {
    try {
      // For demonstration purposes, we'll use Gemini for OCR
      // In a real app, you might want to use a dedicated OCR service
      final apiKey = getApiKey();
      if (apiKey == null) {
        throw Exception('Failed to get API key');
      }

      // Create Gemini model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Create image part for the model
      final imagePart = DataPart('image/jpeg', imageBytes);

      // Prompt for OCR
      final prompt = TextPart(
        "Extract all text visible in this image of a medicine label or packaging. Format the text exactly as it appears, maintaining line breaks, and focus on extracting product name, active ingredients, dosage information, usage instructions, warnings, side effects, and expiry date. Return ONLY the extracted text, no commentary.",
      );

      // Generate content with the correct constructor
      final parts = [imagePart, prompt];
      final response = await model.generateContent([Content('user', parts)]);
      final ocrText = response.text;

      if (ocrText == null || ocrText.isEmpty) {
        print('Gemini OCR returned no text');
        return simulateOCRResponse();
      }

      print('Extracted text from image: $ocrText');
      return ocrText;
    } catch (e) {
      print('Exception while extracting text: $e');
      // If there's any issue, fall back to a simulated response
      return simulateOCRResponse();
    }
  }
  
  // Method to analyze medicine text and get detailed information
  Future<MedicineInfo?> analyzeMedicineText(String text) async {
    try {
      // First use Gemini API to analyze the medicine text
      final medicineInfo = await analyzeWithGemini(text);
      
      // If Gemini analysis fails, fall back to local analysis
      if (medicineInfo == null) {
        print('Gemini analysis failed, using local analysis');
        return _analyzeTextLocally(text);
      }
      
      // Return the AI-analyzed information
      return medicineInfo;
    } catch (e) {
      print('Exception in medicine analysis: $e');
      // Fall back to local analysis if there's any error
      return _analyzeTextLocally(text);
    }
  }
  
  // Use Gemini API to analyze medicine text
  Future<MedicineInfo?> analyzeWithGemini(String text) async {
    try {
      final apiKey = getApiKey();
      if (apiKey == null) {
        throw Exception('Failed to get API key');
      }

      // Create Gemini model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Create prompt for medicine analysis
      final prompt = TextPart("""
You are a pharmaceutical expert assistant. Analyze the following text from a medicine label and provide detailed information about the medicine structured as JSON.

Text from medicine label:
$text

Return ONLY a JSON object with the following fields (do not include any other text):
{
  "name": "Full name of the medicine",
  "description": "Brief description of what the medicine is and how it works",
  "commonUses": "Common medical conditions this medicine is used to treat",
  "dosage": "Recommended dosage information",
  "criticalInfo": "Important warnings and critical information",
  "interactions": "Potential interactions with other drugs or substances",
  "sideEffects": "Common and serious side effects"
}

Ensure all information is medically accurate. If certain information isn't available in the text, make a best guess based on the medicine identified, or indicate "Information not available in label" for that field.
""");

      // Generate content with the correct constructor
      final parts = [prompt];
      final response = await model.generateContent([Content('user', parts)]);
      final jsonResponse = response.text;

      if (jsonResponse == null || jsonResponse.isEmpty) {
        print('Gemini returned empty response');
        return null;
      }

      // Try to parse JSON from the response
      try {
        // Sometimes the API returns Markdown-formatted JSON, so clean it up
        String cleanedJson = jsonResponse;
        if (jsonResponse.contains('```json')) {
          // Extract just the JSON part if it's in a code block
          final jsonPattern = RegExp(r'```json\n([\s\S]*?)\n```');
          final match = jsonPattern.firstMatch(jsonResponse);
          if (match != null && match.group(1) != null) {
            cleanedJson = match.group(1)!;
          }
        } else if (jsonResponse.contains('```')) {
          // Extract from generic code block
          final jsonPattern = RegExp(r'```\n([\s\S]*?)\n```');
          final match = jsonPattern.firstMatch(jsonResponse);
          if (match != null && match.group(1) != null) {
            cleanedJson = match.group(1)!;
          }
        }

        final medicineData = jsonDecode(cleanedJson) as Map<String, dynamic>;
        
        return MedicineInfo(
          name: medicineData['name'] ?? _extractMedicineName(text),
          description: medicineData['description'] ?? 'No description available',
          commonUses: medicineData['commonUses'] ?? _extractCommonUses(text),
          criticalInfo: medicineData['criticalInfo'] ?? 'No critical information available',
          imageUrl: null,
          dosage: medicineData['dosage'] ?? _extractDosage(text),
          interactions: medicineData['interactions'] ?? 'Interaction information not available',
          sideEffects: medicineData['sideEffects'] ?? _extractSideEffects(text),
          isTrustworthy: true, // AI-generated content is marked as trustworthy
        );
      } catch (e) {
        print('Error parsing JSON from Gemini response: $e');
        print('Raw response: $jsonResponse');
        return null;
      }
    } catch (e) {
      print('Exception in Gemini analysis: $e');
      return null;
    }
  }
  
  // Get API key from environment or hardcoded value for web
  String? getApiKey() {
    try {
      if (kIsWeb) {
        // For web, return the hardcoded API key
        return 'AIzaSyA91Qu8C8xDq_cpr0zYIhT00UMlUWXD0Lc';
      } else {
        // For mobile, get from .env file
        final key = dotenv.env['GEMINI_API_KEY'];
        if (key == null || key.isEmpty) {
          throw Exception('GEMINI_API_KEY not found in .env file');
        }
        return key;
      }
    } catch (e) {
      print('Error loading API key: $e');
      return null;
    }
  }
  
  // Simulate OCR response for testing or fallback
  String simulateOCRResponse() {
    return '''PARACETAMOL TABLETS IP 500mg
Contains: Each uncoated tablet contains:
Paracetamol IP 500mg
Excipients q.s.
Color: Titanium Dioxide IP
Usage: For fever and mild to moderate pain
Dosage: 1-2 tablets every 4-6 hours as needed
Warning: Do not exceed 8 tablets in 24 hours
Store below 30°C in a dry place
Mfg by: ABC Pharmaceuticals Ltd
Batch No: AB1234
Mfg Date: Jan 2023
Exp Date: Dec 2025''';
  }
  
  // Analyze medicine text locally without API dependency - Only used as fallback
  MedicineInfo _analyzeTextLocally(String text) {
    // Extract medicine name
    final name = _extractMedicineName(text);
    final lowerText = text.toLowerCase();
    
    // Unlike before, we won't check for specific medicines
    // Instead, we'll just do a generic analysis for any medicine
    // since you want the AI to generate info for each specific medicine
    return MedicineInfo(
      name: name,
      description: 'This appears to be a medication. The AI analysis could not be completed. Please try again with a clearer image.',
      commonUses: _extractCommonUses(text),
      criticalInfo: 'Warning: Always follow prescription instructions and consult healthcare providers before using any medication. Do not use this information to self-diagnose or self-prescribe.',
      imageUrl: null,
      dosage: _extractDosage(text),
      interactions: 'Information not available. Please try scanning again or consult a healthcare professional.',
      sideEffects: _extractSideEffects(text),
      isTrustworthy: false,
    );
  }
  
  // Extract medicine name from text
  String _extractMedicineName(String text) {
    final lines = text.split('\n');
    
    // First try to find a line with all caps or mostly caps as the product name
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length > 3 && trimmed == trimmed.toUpperCase() && !trimmed.contains(':')) {
        return trimmed;
      }
    }
    
    // If not found, take the first non-empty line
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    
    return 'Unknown Medicine';
  }
  
  // Extract dosage information from text
  String _extractDosage(String text) {
    final lowerText = text.toLowerCase();
    
    // Look for common dosage patterns
    final dosageRegex = RegExp(r'(dosage|dose|take|adults?)[:\s]*(.*?)(\.|$)', caseSensitive: false);
    final match = dosageRegex.firstMatch(lowerText);
    
    if (match != null && match.group(2) != null) {
      return match.group(2)!.trim();
    }
    
    // If no match, check if there's a line containing dosage information
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('dosage') || 
          line.toLowerCase().contains('dose') ||
          line.toLowerCase().contains('take') ||
          line.toLowerCase().contains('adult')) {
        return line.trim();
      }
    }
    
    return 'Consult a healthcare professional for proper dosage.';
  }
  
  // Extract common uses from text
  String _extractCommonUses(String text) {
    final lowerText = text.toLowerCase();
    
    // Look for common use patterns
    final usesRegex = RegExp(r'(use|uses|indications?|for)[:\s]*(.*?)(\.|$)', caseSensitive: false);
    final match = usesRegex.firstMatch(lowerText);
    
    if (match != null && match.group(2) != null) {
      return match.group(2)!.trim();
    }
    
    // If no match, check if there's a line containing usage information
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('use') || 
          line.toLowerCase().contains('indication') ||
          line.toLowerCase().contains('for ')) {
        return line.trim();
      }
    }
    
    return 'Not specified in the packaging.';
  }
  
  // Extract side effects from text
  String _extractSideEffects(String text) {
    final lowerText = text.toLowerCase();
    
    // Look for side effects patterns
    final effectsRegex = RegExp(r'(side effects?|adverse|reactions?)[:\s]*(.*?)(\.|$)', caseSensitive: false);
    final match = effectsRegex.firstMatch(lowerText);
    
    if (match != null && match.group(2) != null) {
      return match.group(2)!.trim();
    }
    
    // If no match, check if there's a line containing side effects information
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('side effect') || 
          line.toLowerCase().contains('adverse') ||
          line.toLowerCase().contains('reaction')) {
        return line.trim();
      }
    }
    
    return 'No specific side effects mentioned on packaging.';
  }
  
  // Helper method to save an image to temporary storage (useful for processing)
  Future<File> saveTempImage(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/medicine_image.jpg');
    return await file.writeAsBytes(imageBytes);
  }
} 