import 'package:flutter/material.dart';
import 'package:sajda/home_page.dart';

import 'package:sajda/intro_page.dart';
import 'package:sajda/services/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Simulate loading or fetching initial data
    await Future.delayed(const Duration(seconds: 2));

    try {
      final userProfile = await DatabaseHelper().getUserProfile();

      if (mounted) {
        if (userProfile != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const IntroPage()),
          );
        }
      }
    } catch (e) {
      debugPrint("Error in SplashScreen: $e");
      // Fallback to IntroPage or HomePage depending on strategy.
      // Let's go to IntroPage if we can't determine profile.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images-removebg-preview.png',
              width: 200, // Adjust size as needed
              height: 200,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(), // Optional loading indicator
          ],
        ),
      ),
    );
  }
}
