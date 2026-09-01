import 'package:flutter/material.dart';
import '../main.dart'; // To access AppStartupHelper

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    
    // Set how long the GIF should display before navigating to the app.
    // Adjust the seconds here to match your GIF's length!
    Future.delayed(const Duration(milliseconds: 7800), () {
      _navigateToMainApp();
    });
  }
  
  void _navigateToMainApp() {
    if (!mounted || _navigated) return;
    _navigated = true;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AppStartupHelper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed to white background
      body: Center(
        child: Image.asset(
          'assets/download.gif',
          fit: BoxFit.contain, // Ensures the GIF fits nicely on the screen
        ),
      ),
    );
  }
}
