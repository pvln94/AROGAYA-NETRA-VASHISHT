import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:read_the_label/models/open_food_facts_product.dart';

class OpenFoodFactsService {
  // Change to use the Indian database for more relevant results
  static const String _baseUrl = 'https://in.openfoodfacts.org/api/v0';
  
  // Search products by name
  Future<List<OpenFoodFactsProduct>> searchProducts(String query) async {
    try {
      print('OpenFoodFactsService: Searching for "$query" in Indian database');
      final lowerQuery = query.toLowerCase().trim();
      final encodedQuery = Uri.encodeComponent(query);
      
      // Improved search URL with better parameters
      final url = Uri.parse('$_baseUrl/search?search_terms=$encodedQuery&country=india&json=1&page_size=100');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FoodScan App - Flutter - Version 1.0',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<OpenFoodFactsProduct> products = [];
        
        if (data['products'] != null && data['products'] is List) {
          final productsList = data['products'] as List;
          print('Found ${productsList.length} products in Indian database');
          
          // Define common Indian brands to prioritize
          final List<String> indianBrands = [
            'maggi', 'nestle', 'amul', 'britannia', 'parle', 'haldiram', 
            'mtr', 'dabur', 'patanjali', 'mother dairy', 'itc', 'himalaya', 
            'everest', 'mdh', 'tata', 'fortune', 'aashirvaad', 'lays', 'kurkure',
            'bikaji', 'vadilal', 'kwality walls', 'godrej'
          ];
          
          // Set a minimum score threshold based on query
          int minScoreThreshold = 50; // Higher default threshold for all products
          
          // Find if the query contains any known brand
          bool isKnownBrandSearch = false;
          String matchedBrand = "";
          for (String brand in indianBrands) {
            if (lowerQuery.contains(brand) || brand.contains(lowerQuery)) {
              isKnownBrandSearch = true;
              matchedBrand = brand;
              break;
            }
          }
          
          // Higher threshold for brand searches
          if (isKnownBrandSearch) {
            minScoreThreshold = 90;
          }
          
          // Handle product name patterns like "Parle-G", "Parle G", etc.
          List<String> queryWords = lowerQuery.split(RegExp(r'[\s\-_]+'));
          
          // Score products for relevance
          List<Map<String, dynamic>> scoredProducts = [];
          
          for (var product in productsList) {
            // Make sure product has basic data
            if (product['product_name'] != null) {
              try {
                String productName = (product['product_name'] ?? '').toString().toLowerCase();
                String brandName = (product['brands'] ?? '').toString().toLowerCase();
                
                // Calculate relevance score
                int relevanceScore = 10; // Base score for all products
                
                // Exact match on product name
                if (productName == lowerQuery) {
                  relevanceScore += 250;
                }
                // Product name starts with the query term (e.g., "Maggi Noodles" for "Maggi")
                else if (productName.startsWith(lowerQuery)) {
                  relevanceScore += 200;
                }
                // Product name contains the exact query term as a word
                else if (RegExp('\\b$lowerQuery\\b').hasMatch(productName)) {
                  relevanceScore += 150;
                }
                // Product name contains the query term
                else if (productName.contains(lowerQuery)) {
                  relevanceScore += 100;
                }
                
                // Check for partial matches in compound product names (like "Parle-G" or "Parle G")
                if (queryWords.length > 1) {
                  int matchedWords = 0;
                  for (String word in queryWords) {
                    if (word.length > 1 && productName.contains(word)) {
                      matchedWords++;
                    }
                  }
                  
                  // If most of the query words match, it's likely relevant
                  if (matchedWords >= queryWords.length * 0.7) {
                    relevanceScore += 150;
                  }
                }
                
                // Brand matches exactly (e.g., "Maggi")
                if (brandName == lowerQuery) {
                  relevanceScore += 250;
                }
                // Brand contains the query as a word
                else if (RegExp('\\b$lowerQuery\\b').hasMatch(brandName)) {
                  relevanceScore += 150;
                }
                // Brand contains the query
                else if (brandName.contains(lowerQuery)) {
                  relevanceScore += 100;
                }
                
                // Give a bonus for popular Indian brands
                bool matchesBrand = false;
                for (String brand in indianBrands) {
                  if (brandName.contains(brand)) {
                    relevanceScore += 40;
                    
                    // If this is a search for this particular brand, boost the score
                    if (lowerQuery.contains(brand) || brand.contains(lowerQuery)) {
                      relevanceScore += 100;
                      matchesBrand = true;
                    }
                    
                    break;
                  }
                }
                
                // Check if product is from India
                bool isIndianProduct = false;
                if (product['countries_tags'] is List) {
                  List<String> countries = List<String>.from(product['countries_tags']);
                  for (String country in countries) {
                    if (country.contains('india') || country.contains('en:in')) {
                      isIndianProduct = true;
                      relevanceScore += 50;
                      break;
                    }
                  }
                }
                
                // Special handling for each specific brand
                if (isKnownBrandSearch) {
                  switch (matchedBrand) {
                    case "maggi":
                      // Special handling for Maggi products
                      if (brandName == 'maggi') {
                        relevanceScore += 200; // Very strong boost for exact brand match
                      } else if (brandName.contains('maggi')) {
                        relevanceScore += 150; // Strong boost for brand containing Maggi
                      } else if (productName.contains('maggi')) {
                        relevanceScore += 100; // Good boost for product name containing Maggi
                      }
                      
                      // If not related to Maggi at all, give a very low score
                      if (!brandName.contains('maggi') && !productName.contains('maggi')) {
                        relevanceScore = 0; // Filtered out
                      }
                      break;
                      
                    case "parle":
                      // Special handling for Parle products
                      if (lowerQuery.contains("parle-g") || lowerQuery.contains("parle g")) {
                        // Looking specifically for Parle G
                        if (productName.contains("parle-g") || productName.contains("parle g")) {
                          relevanceScore += 200;
                        } else if (brandName == "parle" && productName.contains("g")) {
                          relevanceScore += 150;
                        } else if (!productName.contains("parle") && !productName.contains("g")) {
                          relevanceScore = 0; // Filter out non-Parle G products
                        }
                      } else {
                        // Generic Parle search
                        if (brandName == "parle") {
                          relevanceScore += 150;
                        } else if (!brandName.contains("parle")) {
                          relevanceScore = 0; // Filter out non-Parle products
                        }
                      }
                      break;
                      
                    case "amul":
                      // Special handling for Amul products
                      if (brandName == "amul") {
                        relevanceScore += 150;
                      } else if (!brandName.contains("amul")) {
                        relevanceScore = 0; // Filter out non-Amul products
                      }
                      break;
                      
                    case "lays":
                    case "kurkure":
                      // Special handling for snack products
                      if (brandName.contains(matchedBrand)) {
                        relevanceScore += 150;
                      } else if (productName.contains(matchedBrand)) {
                        relevanceScore += 100;
                      } else if (!brandName.contains(matchedBrand) && !productName.contains(matchedBrand)) {
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
                        relevanceScore -= 50; // Reduce score for products not matching the brand
                      }
                  }
                }
                
                // Boost score for products with images
                if (product['image_url'] != null) {
                  relevanceScore += 20;
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
                print('Error processing product: $e');
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
              print('Added product: ${p.productName} - Score: ${scoredProduct['score']}');
            } catch (e) {
              print('Error parsing product: $e');
              continue;
            }
          }
          
          // If we found no products, try a more general search
          if (products.isEmpty) {
            print('No relevant products found, trying broader search criteria');
            
            // Lower threshold for fallback
            minScoreThreshold = 30;
            
            // Fall back to general search without country filter
            final fallbackUrl = Uri.parse('$_baseUrl/search?search_terms=$encodedQuery&json=1&page_size=50');
            final fallbackResponse = await http.get(fallbackUrl);
            
            if (fallbackResponse.statusCode == 200) {
              final fallbackData = json.decode(fallbackResponse.body);
              
              if (fallbackData['products'] != null && fallbackData['products'] is List) {
                final fallbackProductsList = fallbackData['products'] as List;
                
                // Score and filter the fallback products too
                List<Map<String, dynamic>> scoredFallbackProducts = [];
                
                for (var product in fallbackProductsList) {
                  if (product['product_name'] != null) {
                    try {
                      String productName = (product['product_name'] ?? '').toString().toLowerCase();
                      String brandName = (product['brands'] ?? '').toString().toLowerCase();
                      
                      // Basic relevance score
                      int relevanceScore = 0;
                      
                      // Check for partial matches
                      if (productName.contains(lowerQuery) || brandName.contains(lowerQuery)) {
                        relevanceScore += 40;
                      }
                      
                      // Check for words in the query
                      for (String word in lowerQuery.split(' ')) {
                        if (word.length > 2 && (productName.contains(word) || brandName.contains(word))) {
                          relevanceScore += 20;
                        }
                      }
                      
                      // Add image bonus
                      if (product['image_url'] != null) {
                        relevanceScore += 10;
                      }
                      
                      if (relevanceScore >= minScoreThreshold) {
                        scoredFallbackProducts.add({
                          'product': product,
                          'score': relevanceScore
                        });
                      }
                    } catch (e) {
                      print('Error processing fallback product: $e');
                      continue;
                    }
                  }
                }
                
                // Sort and limit fallback products too
                scoredFallbackProducts.sort((a, b) => b['score'].compareTo(a['score']));
                scoredFallbackProducts = scoredFallbackProducts.take(10).toList();
                
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
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }
  
  // Get product by barcode
  Future<OpenFoodFactsProduct?> getProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/product/$barcode.json');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 1) {
          return OpenFoodFactsProduct.fromJson(data);
        } else {
          print('Product not found: $barcode');
          return null;
        }
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting product by barcode: $e');
      return null;
    }
  }
} 