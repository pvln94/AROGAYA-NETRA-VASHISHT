import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/open_food_facts_product.dart';

class FoodFactsService {
  // Use the India database which will be more relevant for local products
  static const String baseUrl = 'https://in.openfoodfacts.org/api/v2';

  // Get product by barcode
  Future<OpenFoodFactsProduct?> getProductByBarcode(String barcode) async {
    try {
      print('Making API request to get product by barcode: $barcode');
      final response = await http.get(
        Uri.parse('$baseUrl/product/$barcode'),
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 1) {
          print('Product found with barcode: $barcode');
          try {
            return OpenFoodFactsProduct.fromJson(jsonData);
          } catch (e) {
            print('Error parsing product data: $e');
            print('Response body: ${response.body.substring(0, 200)}...'); // Show part of the response
            return null;
          }
        } else {
          print('Product not found');
          return null;
        }
      } else {
        print('Error fetching product: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception while fetching product: $e');
      return null;
    }
  }

  // Search products by name or description using the India database
  Future<List<OpenFoodFactsProduct>> searchProducts(String query) async {
    try {
      print('Making API request to search products: $query');
      final lowerQuery = query.toLowerCase().trim();
      
      // Use direct search URL format for the Indian database which often works better
      // Add country parameter to focus on Indian products
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://in.openfoodfacts.org/cgi/search.pl?search_terms=$encodedQuery&countries=en:india&json=1&page_size=100';
      
      print('Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FoodScan App - Flutter - Version 1.0',
        },
      );

      print('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        List<OpenFoodFactsProduct> products = [];

        if (jsonData['products'] != null && jsonData['products'] is List) {
          final List rawProducts = jsonData['products'] as List;
          print('Found ${rawProducts.length} products from Indian database');
          
          // Score products based on relevance
          List<Map<String, dynamic>> scoredProducts = [];
          
          // Define common Indian brands to prioritize
          final List<String> indianBrands = [
            'maggi', 'nestle', 'amul', 'britannia', 'parle', 'haldiram', 
            'mtr', 'dabur', 'patanjali', 'mother dairy', 'itc', 'himalaya', 
            'everest', 'mdh', 'tata', 'fortune', 'aashirvaad', 'lays', 'kurkure',
            'bikaji', 'vadilal', 'kwality walls', 'godrej', 'bingo', 'kissan',
            'cadbury', 'hershey', 'heinz', 'kellogg', 'parle agro', 'real',
            'tropicana', 'minute maid', 'del monte', 'haldirams', 'act ii',
            'uncle chips', 'sunfeast', 'tiger', 'oreo', 'bourbon', 'parle-g'
          ];
          
          // Set a much higher default minimum score threshold for all products
          // This will filter out more unrelated products
          int minScoreThreshold = 100;
          
          // Find if the query contains any known brand
          bool isKnownBrandSearch = false;
          String matchedBrand = "";
          
          // Handle multi-word queries differently than single-word queries
          List<String> queryWords = lowerQuery.split(RegExp(r'\s+'));
          
          // Set specific brand-matching logic to determine query type
          for (String brand in indianBrands) {
            // For multi-word brands, check for exact match
            if (brand.contains(' ')) {
              if (lowerQuery.contains(brand)) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            } else {
              // For single-word brands, check for word boundary matches to avoid partial matches
              if (RegExp('\\b$brand\\b').hasMatch(lowerQuery) || lowerQuery == brand) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            }
          }
          
          // Set different thresholds based on query type and length
          if (isKnownBrandSearch) {
            // Very high threshold for brand searches to only get highly relevant products
            minScoreThreshold = 150;
          } else if (queryWords.length > 1) {
            // For multi-word queries, use higher threshold since we expect more precise matches
            minScoreThreshold = 120;
          }
          
          print('Using score threshold: $minScoreThreshold for query: "$lowerQuery"');
          
          // When searching for a known product, allow hyphenated or spaced versions
          // For example, "parle-g" or "parle g" should be treated similarly
          String normalizedQuery = lowerQuery.replaceAll(RegExp(r'[\-_]'), ' ');
          
          // Create a pattern that allows for fuzzy matching for multi-word products
          // This helps match products like "good day" even if query is "goodday"
          String fuzzyPattern = normalizedQuery.replaceAll(' ', '.*');
          
          for (var product in rawProducts) {
            try {
              String productName = (product['product_name'] ?? '').toString().toLowerCase();
              String brandName = (product['brands'] ?? '').toString().toLowerCase();
              
              // Skip products without a name
              if (productName.isEmpty) continue;
              
              // Normalize product name to handle hyphens and spaces consistently
              String normalizedProductName = productName.replaceAll(RegExp(r'[\-_]'), ' ');
              
              // Get countries tag if available
              List<String> countries = [];
              if (product['countries_tags'] is List) {
                countries = List<String>.from(product['countries_tags']);
              }
              
              // Check if product is from India for weight calculations
              bool isIndianProduct = false;
              for (String country in countries) {
                if (country.contains('india') || country.contains('en:in')) {
                  isIndianProduct = true;
                  break;
                }
              }
              
              // Calculate relevance score - starting at 0 instead of base score
              // Products must earn their relevance
              int relevanceScore = 0;
              
              // EXTREMELY strict matching for exact queries
              
              // EXACT MATCH - Product name exactly matches query (highest priority)
              if (normalizedProductName == normalizedQuery) {
                relevanceScore += 300;
              }
              // Product name starts with the query as a whole word
              else if (normalizedProductName.startsWith(normalizedQuery + ' ') || 
                  normalizedProductName.startsWith(normalizedQuery + '-')) {
                relevanceScore += 250;
              }
              // Product name has query as a complete word
              else if (RegExp('\\b' + RegExp.escape(normalizedQuery) + '\\b').hasMatch(normalizedProductName)) {
                relevanceScore += 200;
              }
              // Product name contains the entire query string
              else if (normalizedProductName.contains(normalizedQuery)) {
                relevanceScore += 150;
              }
              // For fuzzy matching (like "goodday" matching "good day")
              else if (RegExp(fuzzyPattern).hasMatch(normalizedProductName)) {
                relevanceScore += 100;
              }
              
              // BRAND MATCHING
              // Brand exactly matches the query
              if (brandName == lowerQuery) {
                relevanceScore += 300;
              }
              // Brand contains the query as a whole word
              else if (RegExp('\\b' + RegExp.escape(lowerQuery) + '\\b').hasMatch(brandName)) {
                relevanceScore += 200;
              }
              // Brand contains the query
              else if (brandName.contains(lowerQuery)) {
                relevanceScore += 100;
              }
              
              // MULTI-WORD QUERY HANDLING
              // For queries with multiple words, add points if product contains all words
              if (queryWords.length > 1) {
                int matchedWords = 0;
                for (String word in queryWords) {
                  if (word.length > 2 && normalizedProductName.contains(word)) {
                    matchedWords++;
                  }
                }
                
                // Award point for matching all words in the query
                double matchRatio = matchedWords / queryWords.length;
                if (matchRatio == 1) {
                  relevanceScore += 150; // All words matched
                } else if (matchRatio >= 0.75) {
                  relevanceScore += 100; // Most words matched
                } else if (matchRatio >= 0.5) {
                  relevanceScore += 50; // Half words matched
                }
              }
              
              // BRAND RELEVANCE BOOSTING
              // Boost scores for popular Indian brands
              bool isPopularBrand = false;
              for (String brand in indianBrands) {
                if (brandName.contains(brand)) {
                relevanceScore += 40;
                  isPopularBrand = true;
                  
                  // If this is a search specifically for this brand, boost significantly
                  if (lowerQuery.contains(brand) || brand.contains(lowerQuery)) {
                    relevanceScore += 150;
                  }
                  
                  break;
                }
              }
              
              // LOCATION RELEVANCE
              // Boost products explicitly from India
              if (isIndianProduct) {
                relevanceScore += 50;
              }
              
              // IMAGE BONUS
              // Boost score for products with images (better user experience)
              if (product['image_url'] != null) {
                relevanceScore += 30;
              }
              
              // BRAND-SPECIFIC HANDLING
              // Special handling for specific Indian brands/products that are commonly searched
              if (isKnownBrandSearch) {
                switch (matchedBrand) {
                  case "maggi":
                    // Must be Maggi branded or have Maggi in name
                    if (brandName == 'maggi' || brandName == 'nestle maggi') {
                      relevanceScore += 200;
                    } else if (brandName.contains('maggi')) {
                      relevanceScore += 150;
                    } else if (productName.contains('maggi')) {
                      relevanceScore += 100;
                    }
                    
                    // Filter out unrelated products
                    if (!brandName.contains('maggi') && !productName.contains('maggi')) {
                      relevanceScore = 0;
                    }
                    break;
                    
                  case "parle-g":
                  case "parle g":
                    // Looking specifically for Parle G biscuits
                    if (productName.contains("parle-g") || productName.contains("parle g")) {
                      relevanceScore += 200;
                    } else if (brandName == "parle" && (productName.contains("g") || productName.contains("glucose"))) {
                      relevanceScore += 150;
                    } else {
                      relevanceScore = 0; // Filter out non-Parle G products
                    }
                    break;
                    
                  case "parle":
                    // Generic Parle search (excluding when specifically looking for Parle-G)
                    if (!lowerQuery.contains("parle g") && !lowerQuery.contains("parle-g")) {
                      if (brandName == "parle") {
                        relevanceScore += 150;
                      } else if (brandName.contains("parle")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out non-Parle products
                      }
                    }
                    break;
                    
                  case "amul":
                    // Amul products
                    if (brandName == "amul") {
                      relevanceScore += 150;
                    } else if (brandName.contains("amul")) {
                      relevanceScore += 100;
                    } else {
                      relevanceScore = 0; // Filter out non-Amul products
                    }
                    break;
                    
                  case "bourbon":
                    // Bourbon biscuits (usually Britannia)
                    if (productName.contains("bourbon") && (brandName.contains("britannia") || brandName == "")) {
                      relevanceScore += 200;
                    } else if (productName.contains("bourbon")) {
                      relevanceScore += 100;
                    } else {
                      relevanceScore = 0; // Filter out non-Bourbon products
                    }
                    break;
                    
                  case "lays":
                  case "kurkure":
                  case "bingo":
                    // Snack products
                    if (brandName.contains(matchedBrand)) {
                      relevanceScore += 150;
                    } else if (productName.contains(matchedBrand)) {
                      relevanceScore += 100;
                    } else {
                      relevanceScore = 0; // Filter out unrelated products
                    }
                    break;
                    
                  case "good day":
                    // Britannia Good Day
                    if (productName.contains("good day") && brandName.contains("britannia")) {
                      relevanceScore += 200;
                    } else if (productName.contains("good day")) {
                      relevanceScore += 150;
                    } else if (brandName.contains("britannia") && productName.contains("goodday")) {
                      relevanceScore += 100;
                    } else {
                      relevanceScore = 0; // Filter out unrelated products
                    }
                    break;
                    
                  default:
                    // Generic handling for other brand searches
                    if (brandName.contains(matchedBrand)) {
                      relevanceScore += 150;
                    } else if (productName.contains(matchedBrand)) {
                      relevanceScore += 100;
                    } else {
                      // Heavily penalize non-matching products
                      relevanceScore = 0;
                    }
                }
              }
              
              // For generic queries that don't match any known brand, use stricter text matching
              if (!isKnownBrandSearch && queryWords.length == 1 && lowerQuery.length > 2) {
                // If it's just a single word query, only include products that actually contain that word
                if (!normalizedProductName.contains(lowerQuery) && !brandName.contains(lowerQuery)) {
                  relevanceScore = 0; // Filter out totally unrelated products
                }
              }
              
              // Only include products with a score above the threshold
              if (relevanceScore >= minScoreThreshold) {
                scoredProducts.add({
                  'product': product,
                  'score': relevanceScore,
                  'name': productName,
                  'brand': brandName
                });
              }
            } catch (e) {
              print('Error scoring product: $e');
              continue;
            }
          }
          
          print('Found ${scoredProducts.length} relevant products after filtering with threshold $minScoreThreshold');
          
          // Sort products by relevance score (highest first)
          scoredProducts.sort((a, b) => b['score'].compareTo(a['score']));
          
          // Take only top 20 most relevant results
          scoredProducts = scoredProducts.take(20).toList();
          
          // Debug print to show what was matched
          for (var item in scoredProducts) {
            print('Matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
          }
          
          // Convert top scored products to OpenFoodFactsProduct objects
          for (var scoredProduct in scoredProducts) {
            try {
              final product = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
              products.add(product);
              print('Added product: ${product.productName} (${product.barcode}) - Score: ${scoredProduct['score']}');
            } catch (e) {
              print('Error parsing product: $e');
              continue;
            }
          }
          
          // If we still have no results, try using broader criteria
          if (products.isEmpty && rawProducts.isNotEmpty) {
            print('No relevant products found, trying broader criteria');
            
            // Lower threshold for fallback
            minScoreThreshold = 50;
            
            // Re-score with looser criteria
            scoredProducts = [];
            for (var product in rawProducts) {
              if (product['product_name'] != null) {
                try {
                  String productName = (product['product_name'] ?? '').toString().toLowerCase();
                  String brandName = (product['brands'] ?? '').toString().toLowerCase();
                  
                  // Basic relevance score
                  int relevanceScore = 0;
                  
                  // Check for partial matches
                  if (productName.contains(lowerQuery) || brandName.contains(lowerQuery)) {
                    relevanceScore += 60;
                  }
                  
                  // Check for words in the query
                  for (String word in lowerQuery.split(' ')) {
                    if (word.length > 2 && (productName.contains(word) || brandName.contains(word))) {
                      relevanceScore += 30;
                    }
                  }
                  
                  // Add image bonus
                  if (product['image_url'] != null) {
                    relevanceScore += 10;
                  }
                  
                  if (relevanceScore >= minScoreThreshold) {
                    scoredProducts.add({
                      'product': product,
                      'score': relevanceScore,
                      'name': productName,
                      'brand': brandName
                    });
                  }
                  
                } catch (e) {
                  print('Error parsing product: $e');
                  continue;
                }
              }
            }
            
            // Sort and limit fallback results
            scoredProducts.sort((a, b) => b['score'].compareTo(a['score']));
            scoredProducts = scoredProducts.take(10).toList();
            
            // Debug print to show what was matched in fallback
            for (var item in scoredProducts) {
              print('Fallback matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
            }
            
            // Add the fallback products
            for (var scoredProduct in scoredProducts) {
              try {
                final offProduct = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
                products.add(offProduct);
                print('Added product using broader criteria: ${offProduct.productName} - Score: ${scoredProduct['score']}');
              } catch (e) {
                print('Error parsing product: $e');
                continue;
              }
            }
          }
        } else {
          print('No products array found in response or empty array');
          print('Response structure: ${jsonData.keys.join(', ')}');
        }

        return products;
      } else {
        print('Error searching products: ${response.statusCode}');
        print('Response body: ${response.body.substring(0, 200)}...');
        return [];
      }
    } catch (e) {
      print('Exception while searching products: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Try searching using alternative search method with India database
  Future<List<OpenFoodFactsProduct>> legacySearchProducts(String query) async {
    try {
      print('Trying alternative search for: $query');
      final lowerQuery = query.toLowerCase().trim();
      final encodedQuery = Uri.encodeComponent(query);
      
      // First try to search for the brand in Indian products
      final url = 'https://in.openfoodfacts.org/brand/$encodedQuery/country/india.json';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FoodScan App - Flutter - Version 1.0',
        }
      );
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        List<OpenFoodFactsProduct> products = [];
        
        if (jsonData['products'] != null && jsonData['products'] is List) {
          final productsList = jsonData['products'] as List;
          print('Found ${productsList.length} products in brand search for Indian products');
          
          // Define common Indian brands to prioritize
          final List<String> indianBrands = [
            'maggi', 'nestle', 'amul', 'britannia', 'parle', 'haldiram', 
            'mtr', 'dabur', 'patanjali', 'mother dairy', 'itc', 'himalaya', 
            'everest', 'mdh', 'tata', 'fortune', 'aashirvaad', 'lays', 'kurkure',
            'bikaji', 'vadilal', 'kwality walls', 'godrej', 'bingo', 'kissan',
            'cadbury', 'hershey', 'heinz', 'kellogg', 'parle agro', 'real',
            'tropicana', 'minute maid', 'del monte', 'haldirams', 'act ii',
            'uncle chips', 'sunfeast', 'tiger', 'oreo', 'bourbon', 'parle-g'
          ];
          
          // Set a much higher default minimum score threshold for all products
          // This will filter out more unrelated products
          int minScoreThreshold = 100;
          
          // Find if the query contains any known brand
          bool isKnownBrandSearch = false;
          String matchedBrand = "";
          
          // Handle multi-word queries differently than single-word queries
          List<String> queryWords = lowerQuery.split(RegExp(r'\s+'));
          
          // Set specific brand-matching logic to determine query type
          for (String brand in indianBrands) {
            // For multi-word brands, check for exact match
            if (brand.contains(' ')) {
              if (lowerQuery.contains(brand)) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            } else {
              // For single-word brands, check for word boundary matches to avoid partial matches
              if (RegExp('\\b$brand\\b').hasMatch(lowerQuery) || lowerQuery == brand) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            }
          }
          
          // Set different thresholds based on query type and length
          if (isKnownBrandSearch) {
            // Very high threshold for brand searches to only get highly relevant products
            minScoreThreshold = 150;
          } else if (queryWords.length > 1) {
            // For multi-word queries, use higher threshold since we expect more precise matches
            minScoreThreshold = 120;
          }
          
          print('Using score threshold (legacy): $minScoreThreshold for query: "$lowerQuery"');
          
          // When searching for a known product, allow hyphenated or spaced versions
          // For example, "parle-g" or "parle g" should be treated similarly
          String normalizedQuery = lowerQuery.replaceAll(RegExp(r'[\-_]'), ' ');
          
          // Create a pattern that allows for fuzzy matching for multi-word products
          // This helps match products like "good day" even if query is "goodday" 
          String fuzzyPattern = normalizedQuery.replaceAll(' ', '.*');
          
          // Score products for relevance
          List<Map<String, dynamic>> scoredProducts = [];
          
          for (var product in productsList) {
            // Make sure product has basic data
            if (product['product_name'] != null) {
              try {
                String productName = (product['product_name'] ?? '').toString().toLowerCase();
                String brandName = (product['brands'] ?? '').toString().toLowerCase();
                
                // Skip products without a name
                if (productName.isEmpty) continue;
                
                // Normalize product name to handle hyphens and spaces consistently
                String normalizedProductName = productName.replaceAll(RegExp(r'[\-_]'), ' ');
                
                // Check if product is from India for weight calculations
                bool isIndianProduct = false;
                if (product['countries_tags'] is List) {
                  List<String> countries = List<String>.from(product['countries_tags']);
                  for (String country in countries) {
                    if (country.contains('india') || country.contains('en:in')) {
                      isIndianProduct = true;
                      break;
                    }
                  }
                }
                
                // Calculate relevance score - starting at 0 instead of base score
                // Products must earn their relevance
                int relevanceScore = 0;
                
                // EXTREMELY strict matching for exact queries
                
                // EXACT MATCH - Product name exactly matches query (highest priority)
                if (normalizedProductName == normalizedQuery) {
                  relevanceScore += 300;
                }
                // Product name starts with the query as a whole word
                else if (normalizedProductName.startsWith(normalizedQuery + ' ') || 
                    normalizedProductName.startsWith(normalizedQuery + '-')) {
                  relevanceScore += 250;
                }
                // Product name has query as a complete word
                else if (RegExp('\\b' + RegExp.escape(normalizedQuery) + '\\b').hasMatch(normalizedProductName)) {
                  relevanceScore += 200;
                }
                // Product name contains the entire query string
                else if (normalizedProductName.contains(normalizedQuery)) {
                  relevanceScore += 150;
                }
                // For fuzzy matching (like "goodday" matching "good day")
                else if (RegExp(fuzzyPattern).hasMatch(normalizedProductName)) {
                  relevanceScore += 100;
                }
                
                // BRAND MATCHING
                // Brand exactly matches the query
                if (brandName == lowerQuery) {
                  relevanceScore += 300;
                }
                // Brand contains the query as a whole word
                else if (RegExp('\\b' + RegExp.escape(lowerQuery) + '\\b').hasMatch(brandName)) {
                  relevanceScore += 200;
                }
                // Brand contains the query
                else if (brandName.contains(lowerQuery)) {
                  relevanceScore += 100;
                }
                
                // MULTI-WORD QUERY HANDLING
                // For queries with multiple words, add points if product contains all words
                if (queryWords.length > 1) {
                  int matchedWords = 0;
                  for (String word in queryWords) {
                    if (word.length > 2 && normalizedProductName.contains(word)) {
                      matchedWords++;
                    }
                  }
                  
                  // Award point for matching all words in the query
                  double matchRatio = matchedWords / queryWords.length;
                  if (matchRatio == 1) {
                    relevanceScore += 150; // All words matched
                  } else if (matchRatio >= 0.75) {
                    relevanceScore += 100; // Most words matched
                  } else if (matchRatio >= 0.5) {
                    relevanceScore += 50; // Half words matched
                  }
                }
                
                // BRAND RELEVANCE BOOSTING
                // Boost scores for popular Indian brands
                bool isPopularBrand = false;
                for (String brand in indianBrands) {
                  if (brandName.contains(brand)) {
                    relevanceScore += 40;
                    isPopularBrand = true;
                    
                    // If this is a search specifically for this brand, boost significantly
                    if (lowerQuery.contains(brand) || brand.contains(lowerQuery)) {
                      relevanceScore += 150;
                    }
                    
                    break;
                  }
                }
                
                // LOCATION RELEVANCE
                // Boost products explicitly from India
                if (isIndianProduct) {
                  relevanceScore += 50;
                }
                
                // IMAGE BONUS
                // Boost score for products with images (better user experience)
                if (product['image_url'] != null) {
                  relevanceScore += 30;
                }
                
                // BRAND-SPECIFIC HANDLING
                // Special handling for specific Indian brands/products that are commonly searched
                if (isKnownBrandSearch) {
                  switch (matchedBrand) {
                    case "maggi":
                      // Must be Maggi branded or have Maggi in name
                      if (brandName == 'maggi' || brandName == 'nestle maggi') {
                        relevanceScore += 200;
                      } else if (brandName.contains('maggi')) {
                        relevanceScore += 150;
                      } else if (productName.contains('maggi')) {
                        relevanceScore += 100;
                      }
                      
                      // Filter out unrelated products
                      if (!brandName.contains('maggi') && !productName.contains('maggi')) {
                        relevanceScore = 0;
                      }
                      break;
                      
                    case "parle-g":
                    case "parle g":
                      // Looking specifically for Parle G biscuits
                      if (productName.contains("parle-g") || productName.contains("parle g")) {
                        relevanceScore += 200;
                      } else if (brandName == "parle" && (productName.contains("g") || productName.contains("glucose"))) {
                        relevanceScore += 150;
                      } else {
                        relevanceScore = 0; // Filter out non-Parle G products
                      }
                      break;
                      
                    case "parle":
                      // Generic Parle search (excluding when specifically looking for Parle-G)
                      if (!lowerQuery.contains("parle g") && !lowerQuery.contains("parle-g")) {
                        if (brandName == "parle") {
                          relevanceScore += 150;
                        } else if (brandName.contains("parle")) {
                          relevanceScore += 100;
                        } else {
                          relevanceScore = 0; // Filter out non-Parle products
                        }
                      }
                      break;
                      
                    case "amul":
                      // Amul products
                      if (brandName == "amul") {
                        relevanceScore += 150;
                      } else if (brandName.contains("amul")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out non-Amul products
                      }
                      break;
                      
                    case "bourbon":
                      // Bourbon biscuits (usually Britannia)
                      if (productName.contains("bourbon") && (brandName.contains("britannia") || brandName == "")) {
                        relevanceScore += 200;
                      } else if (productName.contains("bourbon")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out non-Bourbon products
                      }
                      break;
                      
                    case "lays":
                    case "kurkure":
                    case "bingo":
                      // Snack products
                      if (brandName.contains(matchedBrand)) {
                        relevanceScore += 150;
                      } else if (productName.contains(matchedBrand)) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out unrelated products
                      }
                      break;
                      
                    case "good day":
                      // Britannia Good Day
                      if (productName.contains("good day") && brandName.contains("britannia")) {
                        relevanceScore += 200;
                      } else if (productName.contains("good day")) {
                        relevanceScore += 150;
                      } else if (brandName.contains("britannia") && productName.contains("goodday")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out unrelated products
                      }
                      break;
                      
                    default:
                      // Generic handling for other brand searches
                      if (brandName.contains(matchedBrand)) {
                        relevanceScore += 150;
                      } else if (productName.contains(matchedBrand)) {
                        relevanceScore += 100;
                      } else {
                        // Heavily penalize non-matching products
                        relevanceScore = 0;
                      }
                  }
                }
                
                // For generic queries that don't match any known brand, use stricter text matching
                if (!isKnownBrandSearch && queryWords.length == 1 && lowerQuery.length > 2) {
                  // If it's just a single word query, only include products that actually contain that word
                  if (!normalizedProductName.contains(lowerQuery) && !brandName.contains(lowerQuery)) {
                    relevanceScore = 0; // Filter out totally unrelated products
                  }
                }
                
                // Only include products with a score above the threshold
                if (relevanceScore >= minScoreThreshold) {
                  scoredProducts.add({
                    'product': product,
                    'score': relevanceScore,
                    'name': productName,
                    'brand': brandName
                  });
                }
                
              } catch (e) {
                print('Error processing legacy product: $e');
                continue;
              }
            }
          }
          
          print('Found ${scoredProducts.length} relevant products after filtering with threshold $minScoreThreshold');
          
          // Sort products by relevance score (highest first)
          scoredProducts.sort((a, b) => b['score'].compareTo(a['score']));
          
          // Take only top 20 most relevant results
          scoredProducts = scoredProducts.take(20).toList();
          
          // Debug print to show what was matched
          for (var item in scoredProducts) {
            print('Matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
          }
          
          // Convert top scored products to OpenFoodFactsProduct objects
          for (var scoredProduct in scoredProducts) {
            try {
              final product = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
              products.add(product);
              print('Added legacy product: ${product.productName} - Score: ${scoredProduct['score']}');
              } catch (e) {
                print('Error parsing legacy product: $e');
                continue;
              }
            }
          }
        
        // If we didn't find specific Indian products, fall back to general brand search
        if (products.isEmpty) {
          print('No Indian products found for brand, trying general brand search');
          
          // Lower threshold for fallback
          int fallbackThreshold = 50;
          
          final fallbackUrl = 'https://in.openfoodfacts.org/brand/$encodedQuery.json';
          final fallbackResponse = await http.get(Uri.parse(fallbackUrl));
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackData = jsonDecode(fallbackResponse.body);
            
            if (fallbackData['products'] != null && fallbackData['products'] is List) {
              final fallbackProductsList = fallbackData['products'] as List;
              print('Found ${fallbackProductsList.length} products in general brand search');
              
              // Score and filter the fallback products too
              List<Map<String, dynamic>> scoredFallbackProducts = [];
              
              for (var product in fallbackProductsList) {
                // Make sure product has basic data
                if (product['product_name'] != null) {
                  try {
                    String productName = (product['product_name'] ?? '').toString().toLowerCase();
                    String brandName = (product['brands'] ?? '').toString().toLowerCase();
                    
                    // Basic relevance score
                    int relevanceScore = 0;
                    
                    // Check for partial matches
                    if (productName.contains(lowerQuery) || brandName.contains(lowerQuery)) {
                      relevanceScore += 60;
                    }
                    
                    // Check for words in the query
                    for (String word in lowerQuery.split(' ')) {
                      if (word.length > 2 && (productName.contains(word) || brandName.contains(word))) {
                        relevanceScore += 30;
                      }
                    }
                    
                    // Add image bonus
                    if (product['image_url'] != null) {
                      relevanceScore += 10;
                    }
                    
                    if (relevanceScore >= fallbackThreshold) {
                      scoredFallbackProducts.add({
                        'product': product,
                        'score': relevanceScore,
                        'name': productName,
                        'brand': brandName
                      });
                    }
                  } catch (e) {
                    print('Error parsing fallback product: $e');
                    continue;
                  }
                }
              }
              
              // Sort and limit fallback products too
              scoredFallbackProducts.sort((a, b) => b['score'].compareTo(a['score']));
              scoredFallbackProducts = scoredFallbackProducts.take(10).toList();
              
              // Debug print to show what was matched in fallback
              for (var item in scoredFallbackProducts) {
                print('Fallback matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
              }
              
              // Add the top fallback products
              for (var scoredProduct in scoredFallbackProducts) {
                try {
                  final product = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
                  products.add(product);
                  print('Added fallback product: ${product.productName} - Score: ${scoredProduct['score']}');
                } catch (e) {
                  print('Error parsing fallback product: $e');
                  continue;
                }
              }
            }
          }
        }
        
        return products;
      }
      return [];
    } catch (e) {
      print('Legacy search error: $e');
      return [];
    }
  }

  // Try a third search approach using direct product query
  Future<List<OpenFoodFactsProduct>> searchByDirectQuery(String query) async {
    try {
      print('Trying direct product name search for: $query');
      final lowerQuery = query.toLowerCase().trim();
      final encodedQuery = Uri.encodeComponent(query);
      
      // Try to search by product name in Indian products first
      final url = 'https://in.openfoodfacts.org/cgi/search.pl?search_terms=$encodedQuery&tagtype_0=countries&tag_contains_0=contains&tag_0=india&sort_by=popularity&page_size=50&json=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'FoodScan App - Flutter - Version 1.0',
        }
      );
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        List<OpenFoodFactsProduct> products = [];
        
        if (jsonData['products'] != null && jsonData['products'] is List) {
          final productsList = jsonData['products'] as List;
          print('Found ${productsList.length} products in direct search for Indian products');
          
          // Define common Indian brands to prioritize
          final List<String> indianBrands = [
            'maggi', 'nestle', 'amul', 'britannia', 'parle', 'haldiram', 
            'mtr', 'dabur', 'patanjali', 'mother dairy', 'itc', 'himalaya', 
            'everest', 'mdh', 'tata', 'fortune', 'aashirvaad', 'lays', 'kurkure',
            'bikaji', 'vadilal', 'kwality walls', 'godrej', 'bingo', 'kissan',
            'cadbury', 'hershey', 'heinz', 'kellogg', 'parle agro', 'real',
            'tropicana', 'minute maid', 'del monte', 'haldirams', 'act ii',
            'uncle chips', 'sunfeast', 'tiger', 'oreo', 'bourbon', 'parle-g'
          ];
          
          // Set a much higher default minimum score threshold for all products
          // This will filter out more unrelated products
          int minScoreThreshold = 100;
          
          // Find if the query contains any known brand
          bool isKnownBrandSearch = false;
          String matchedBrand = "";
          
          // Handle multi-word queries differently than single-word queries
          List<String> queryWords = lowerQuery.split(RegExp(r'\s+'));
          
          // Set specific brand-matching logic to determine query type
          for (String brand in indianBrands) {
            // For multi-word brands, check for exact match
            if (brand.contains(' ')) {
              if (lowerQuery.contains(brand)) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            } else {
              // For single-word brands, check for word boundary matches to avoid partial matches
              if (RegExp('\\b$brand\\b').hasMatch(lowerQuery) || lowerQuery == brand) {
                isKnownBrandSearch = true;
                matchedBrand = brand;
                break;
              }
            }
          }
          
          // Set different thresholds based on query type and length
          if (isKnownBrandSearch) {
            // Very high threshold for brand searches to only get highly relevant products
            minScoreThreshold = 150;
          } else if (queryWords.length > 1) {
            // For multi-word queries, use higher threshold since we expect more precise matches
            minScoreThreshold = 120;
          }
          
          print('Using score threshold (direct query): $minScoreThreshold for query: "$lowerQuery"');
          
          // When searching for a known product, allow hyphenated or spaced versions
          // For example, "parle-g" or "parle g" should be treated similarly
          String normalizedQuery = lowerQuery.replaceAll(RegExp(r'[\-_]'), ' ');
          
          // Create a pattern that allows for fuzzy matching for multi-word products
          // This helps match products like "good day" even if query is "goodday" 
          String fuzzyPattern = normalizedQuery.replaceAll(' ', '.*');
          
          // Score products for relevance
          List<Map<String, dynamic>> scoredProducts = [];
          
          for (var product in productsList) {
            // Make sure product has basic data
            if (product['product_name'] != null) {
              try {
                String productName = (product['product_name'] ?? '').toString().toLowerCase();
                String brandName = (product['brands'] ?? '').toString().toLowerCase();
                
                // Skip products without a name
                if (productName.isEmpty) continue;
                
                // Normalize product name to handle hyphens and spaces consistently
                String normalizedProductName = productName.replaceAll(RegExp(r'[\-_]'), ' ');
                
                // Check if product is from India for weight calculations
                bool isIndianProduct = false;
                if (product['countries_tags'] is List) {
                  List<String> countries = List<String>.from(product['countries_tags']);
                  for (String country in countries) {
                    if (country.contains('india') || country.contains('en:in')) {
                      isIndianProduct = true;
                      break;
                    }
                  }
                }
                
                // Calculate relevance score - starting at 0 instead of base score
                // Products must earn their relevance
                int relevanceScore = 0;
                
                // EXTREMELY strict matching for exact queries
                
                // EXACT MATCH - Product name exactly matches query (highest priority)
                if (normalizedProductName == normalizedQuery) {
                  relevanceScore += 300;
                }
                // Product name starts with the query as a whole word
                else if (normalizedProductName.startsWith(normalizedQuery + ' ') || 
                    normalizedProductName.startsWith(normalizedQuery + '-')) {
                  relevanceScore += 250;
                }
                // Product name has query as a complete word
                else if (RegExp('\\b' + RegExp.escape(normalizedQuery) + '\\b').hasMatch(normalizedProductName)) {
                  relevanceScore += 200;
                }
                // Product name contains the entire query string
                else if (normalizedProductName.contains(normalizedQuery)) {
                  relevanceScore += 150;
                }
                // For fuzzy matching (like "goodday" matching "good day")
                else if (RegExp(fuzzyPattern).hasMatch(normalizedProductName)) {
                  relevanceScore += 100;
                }
                
                // BRAND MATCHING
                // Brand exactly matches the query
                if (brandName == lowerQuery) {
                  relevanceScore += 300;
                }
                // Brand contains the query as a whole word
                else if (RegExp('\\b' + RegExp.escape(lowerQuery) + '\\b').hasMatch(brandName)) {
                  relevanceScore += 200;
                }
                // Brand contains the query
                else if (brandName.contains(lowerQuery)) {
                  relevanceScore += 100;
                }
                
                // MULTI-WORD QUERY HANDLING
                // For queries with multiple words, add points if product contains all words
                if (queryWords.length > 1) {
                  int matchedWords = 0;
                  for (String word in queryWords) {
                    if (word.length > 2 && normalizedProductName.contains(word)) {
                      matchedWords++;
                    }
                  }
                  
                  // Award point for matching all words in the query
                  double matchRatio = matchedWords / queryWords.length;
                  if (matchRatio == 1) {
                    relevanceScore += 150; // All words matched
                  } else if (matchRatio >= 0.75) {
                    relevanceScore += 100; // Most words matched
                  } else if (matchRatio >= 0.5) {
                    relevanceScore += 50; // Half words matched
                  }
                }
                
                // BRAND RELEVANCE BOOSTING
                // Boost scores for popular Indian brands
                bool isPopularBrand = false;
                for (String brand in indianBrands) {
                  if (brandName.contains(brand)) {
                    relevanceScore += 40;
                    isPopularBrand = true;
                    
                    // If this is a search specifically for this brand, boost significantly
                    if (lowerQuery.contains(brand) || brand.contains(lowerQuery)) {
                      relevanceScore += 150;
                    }
                    
                    break;
                  }
                }
                
                // LOCATION RELEVANCE
                // Boost products explicitly from India
                if (isIndianProduct) {
                  relevanceScore += 50;
                }
                
                // IMAGE BONUS
                // Boost score for products with images (better user experience)
                if (product['image_url'] != null) {
                  relevanceScore += 30;
                }
                
                // BRAND-SPECIFIC HANDLING
                // Special handling for specific Indian brands/products that are commonly searched
                if (isKnownBrandSearch) {
                  switch (matchedBrand) {
                    case "maggi":
                      // Must be Maggi branded or have Maggi in name
                      if (brandName == 'maggi' || brandName == 'nestle maggi') {
                        relevanceScore += 200;
                      } else if (brandName.contains('maggi')) {
                        relevanceScore += 150;
                      } else if (productName.contains('maggi')) {
                        relevanceScore += 100;
                      }
                      
                      // Filter out unrelated products
                      if (!brandName.contains('maggi') && !productName.contains('maggi')) {
                        relevanceScore = 0;
                      }
                      break;
                      
                    case "parle-g":
                    case "parle g":
                      // Looking specifically for Parle G biscuits
                      if (productName.contains("parle-g") || productName.contains("parle g")) {
                        relevanceScore += 200;
                      } else if (brandName == "parle" && (productName.contains("g") || productName.contains("glucose"))) {
                        relevanceScore += 150;
                      } else {
                        relevanceScore = 0; // Filter out non-Parle G products
                      }
                      break;
                      
                    case "parle":
                      // Generic Parle search (excluding when specifically looking for Parle-G)
                      if (!lowerQuery.contains("parle g") && !lowerQuery.contains("parle-g")) {
                        if (brandName == "parle") {
                          relevanceScore += 150;
                        } else if (brandName.contains("parle")) {
                          relevanceScore += 100;
                        } else {
                          relevanceScore = 0; // Filter out non-Parle products
                        }
                      }
                      break;
                      
                    case "amul":
                      // Amul products
                      if (brandName == "amul") {
                        relevanceScore += 150;
                      } else if (brandName.contains("amul")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out non-Amul products
                      }
                      break;
                      
                    case "bourbon":
                      // Bourbon biscuits (usually Britannia)
                      if (productName.contains("bourbon") && (brandName.contains("britannia") || brandName == "")) {
                        relevanceScore += 200;
                      } else if (productName.contains("bourbon")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out non-Bourbon products
                      }
                      break;
                      
                    case "lays":
                    case "kurkure":
                    case "bingo":
                      // Snack products
                      if (brandName.contains(matchedBrand)) {
                        relevanceScore += 150;
                      } else if (productName.contains(matchedBrand)) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out unrelated products
                      }
                      break;
                      
                    case "good day":
                      // Britannia Good Day
                      if (productName.contains("good day") && brandName.contains("britannia")) {
                        relevanceScore += 200;
                      } else if (productName.contains("good day")) {
                        relevanceScore += 150;
                      } else if (brandName.contains("britannia") && productName.contains("goodday")) {
                        relevanceScore += 100;
                      } else {
                        relevanceScore = 0; // Filter out unrelated products
                      }
                      break;
                      
                    default:
                      // Generic handling for other brand searches
                      if (brandName.contains(matchedBrand)) {
                        relevanceScore += 150;
                      } else if (productName.contains(matchedBrand)) {
                        relevanceScore += 100;
                      } else {
                        // Heavily penalize non-matching products
                        relevanceScore = 0;
                      }
                  }
                }
                
                // For generic queries that don't match any known brand, use stricter text matching
                if (!isKnownBrandSearch && queryWords.length == 1 && lowerQuery.length > 2) {
                  // If it's just a single word query, only include products that actually contain that word
                  if (!normalizedProductName.contains(lowerQuery) && !brandName.contains(lowerQuery)) {
                    relevanceScore = 0; // Filter out totally unrelated products
                  }
                }
                
                // Only include products with a score above the threshold
                if (relevanceScore >= minScoreThreshold) {
                  scoredProducts.add({
                    'product': product,
                    'score': relevanceScore,
                    'name': productName,
                    'brand': brandName
                  });
                }
                
              } catch (e) {
                print('Error processing direct search product: $e');
                continue;
              }
            }
          }
          
          print('Found ${scoredProducts.length} relevant products after filtering with threshold $minScoreThreshold');
          
          // Sort products by relevance score (highest first)
          scoredProducts.sort((a, b) => b['score'].compareTo(a['score']));
          
          // Take only top 20 most relevant results
          scoredProducts = scoredProducts.take(20).toList();
          
          // Debug print to show what was matched
          for (var item in scoredProducts) {
            print('Matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
          }
          
          // Convert top scored products to OpenFoodFactsProduct objects
          for (var scoredProduct in scoredProducts) {
            try {
              final p = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
                products.add(p);
              print('Added direct product: ${p.productName} - Score: ${scoredProduct['score']}');
              } catch (e) {
                print('Error parsing direct search product: $e');
                continue;
              }
            }
          }
        
        // If we didn't find specific Indian products, fall back to general product name search
        if (products.isEmpty) {
          print('No Indian products found in direct search, trying general product search');
          
          // Lower threshold for fallback
          int fallbackThreshold = 50;
          
          final fallbackUrl = 'https://in.openfoodfacts.org/product-name/$encodedQuery.json';
          final fallbackResponse = await http.get(Uri.parse(fallbackUrl));
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackData = jsonDecode(fallbackResponse.body);
            
            if (fallbackData['products'] != null && fallbackData['products'] is List) {
              final fallbackProductsList = fallbackData['products'] as List;
              print('Found ${fallbackProductsList.length} products in general product search');
              
              // Score and filter the fallback products too
              List<Map<String, dynamic>> scoredFallbackProducts = [];
              
              for (var product in fallbackProductsList) {
                // Make sure product has basic data
                if (product['product_name'] != null) {
                  try {
                    String productName = (product['product_name'] ?? '').toString().toLowerCase();
                    String brandName = (product['brands'] ?? '').toString().toLowerCase();
                    
                    // Basic relevance score
                    int relevanceScore = 0;
                    
                    // Check for partial matches
                    if (productName.contains(lowerQuery) || brandName.contains(lowerQuery)) {
                      relevanceScore += 60;
                    }
                    
                    // Check for words in the query
                    for (String word in lowerQuery.split(' ')) {
                      if (word.length > 2 && (productName.contains(word) || brandName.contains(word))) {
                        relevanceScore += 30;
                      }
                    }
                    
                    // Add image bonus
                    if (product['image_url'] != null) {
                      relevanceScore += 10;
                    }
                    
                    if (relevanceScore >= fallbackThreshold) {
                      scoredFallbackProducts.add({
                        'product': product,
                        'score': relevanceScore,
                        'name': productName,
                        'brand': brandName
                      });
                    }
                  } catch (e) {
                    print('Error parsing fallback product: $e');
                    continue;
                  }
                }
              }
              
              // Sort and limit fallback products too
              scoredFallbackProducts.sort((a, b) => b['score'].compareTo(a['score']));
              scoredFallbackProducts = scoredFallbackProducts.take(10).toList();
              
              // Debug print to show what was matched in fallback
              for (var item in scoredFallbackProducts) {
                print('Fallback matched: ${item['name']} (${item['brand']}) - Score: ${item['score']}');
              }
              
              // Add the top fallback products
              for (var scoredProduct in scoredFallbackProducts) {
                try {
                  final p = OpenFoodFactsProduct.fromJson({'product': scoredProduct['product']});
                  products.add(p);
                  print('Added fallback product: ${p.productName} - Score: ${scoredProduct['score']}');
                } catch (e) {
                  print('Error parsing fallback product: $e');
                  continue;
                }
              }
            }
          }
        }
        
        return products;
      }
      return [];
    } catch (e) {
      print('Direct search error: $e');
      return [];
    }
  }

  // Get product by scanning label (OCR) - returns closest matches
  Future<List<OpenFoodFactsProduct>> getProductsByLabel(String text) async {
    // This is a simplified approach - extracting key terms from label text
    // and searching with those terms
    final keywords = _extractKeywords(text);
    if (keywords.isEmpty) {
      print('No valid keywords extracted from label text');
      return [];
    }
    
    print('Extracted keywords from label: ${keywords.join(", ")}');
    return searchProducts(keywords.join(' '));
  }

  // Helper method to extract potentially useful keywords from label text
  List<String> _extractKeywords(String text) {
    // Split by common separators
    final words = text.split(RegExp(r'[,;:\s]+'));
    
    // Filter out very short words and numbers-only words
    final filteredWords = words.where((word) {
      return word.length > 3 && !RegExp(r'^\d+$').hasMatch(word);
    }).toList();
    
    // Take up to 5 keywords to keep search precise but not too narrow
    return filteredWords.take(5).toList();
  }
} 