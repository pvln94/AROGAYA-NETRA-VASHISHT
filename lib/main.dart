import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

import 'my_home_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  
  // Initialize notification service (simplified version without actual notifications)
  await NotificationService.instance.init();
      
  // Load environment variables
  if (kIsWeb) {
    dotenv.testLoad(fileInput: 'GEMINI_API_KEY=AIzaSyA91Qu8C8xDq_cpr0zYIhT00UMlUWXD0Lc');
    // Add a small delay for web to ensure initialization
    Timer(Duration(milliseconds: 100), () {
      runApp(const MyApp());
    });
  } else {
    await dotenv.load(fileName: ".env");
    // Run the app directly for non-web platforms
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodBar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2DCCA7),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
          background: const Color(0xFF121212),
          primary: const Color(0xFF2DCCA7),
          secondary: const Color(0xFFFF6B6B),
          tertiary: const Color(0xFFFFC857),
          error: const Color(0xFFFF5C5C),
          onSurface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onError: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          labelLarge: TextStyle(color: Colors.black),
          labelMedium: TextStyle(color: Colors.black),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        // Add web-specific theme settings
        platform: kIsWeb ? TargetPlatform.macOS : null, // Better web rendering
      ),
      home: const HomeScreen(),
    );
  }
}


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF000000), // Background color
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Name - Arogya Netra (Centered Text)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20), // Adjust padding as needed
                child: Text(
                  'Scan Smart      Live Healthy',
                  textAlign: TextAlign.center, // Centering the text
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Custom-sized Image
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/icons/log.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 40),
              // Scan Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyHomePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DCCA7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Scan',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}