import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
    
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Basic navigation logic; adjust if relying on stored token logic in future
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.restoreSession();
    if (!mounted) return;
    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => authProvider.user!.passwordChangeRequired ? const ChangePasswordScreen(isForced: true) : const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white, // Very light white
              Color(0xFFE8F5E9), // Very light green tint
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30.0), // Small curves around the image
              child: Image.asset(
                'assets/images/logo.png',
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback in case image isn't loaded correctly yet
                  return Container(
                    width: 180,
                    height: 180,
                    color: AppConstants.primaryGreen.withOpacity(0.1),
                    child: const Icon(
                      Icons.eco,
                      size: 80,
                      color: AppConstants.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
