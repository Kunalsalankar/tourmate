// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colors.dart';
import '../core/services/notification_service.dart';
import '../core/services/preferences_service.dart';
import '../user/home_screen.dart';
import '../user/sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    // Add this to check auth state after animation
    Future.delayed(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    // Initialize preferences service
    final prefsService = PreferencesService();
    await prefsService.initialize();

    // Request notification permissions on first launch
    if (!prefsService.hasRequestedNotificationPermission) {
      await _requestNotificationPermissions();
      await prefsService.setNotificationPermissionRequested();
    }

    // Mark first launch as complete
    if (prefsService.isFirstLaunch) {
      await prefsService.setFirstLaunchComplete();
    }

    // Check auth and navigate
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    
    if (user != null) {
      // User is signed in, navigate to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => UserHomeScreen()),
      );
    } else {
      // Not signed in, navigate to sign in
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SignInScreen()),
      );
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final notificationService = NotificationService();
    
    // Show a dialog explaining why we need notification permissions
    if (!mounted) return;
    
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Enable Notifications'),
          ],
        ),
        content: const Text(
          'Get notified when your trips are about to start!\n\n'
          'We\'ll send you reminders for your upcoming trips so you never miss an adventure.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final granted = await notificationService.requestPermissions();
      if (!mounted) return;
      
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Notifications enabled successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
            colors: AppColors.primaryGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.travel_explore,
                                size: 80,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              'Tourmate',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                    color: AppColors.textPrimary.withOpacity(0.26),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your Ultimate Travel Companion',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textOnPrimary.withOpacity(0.7),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
                // Remove the Get Started button, navigation is now automatic
              ],
            ),
          ),
        ),
      ),
    );
  }
}