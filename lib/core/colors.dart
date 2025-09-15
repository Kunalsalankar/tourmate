import 'package:flutter/material.dart';

/// App Colors - Light Blue Theme
/// This file defines all the colors used throughout the Tourmate app
/// to maintain consistency and easy theme management.
class AppColors {
  // Primary Colors - Light Blue Theme
  static const Color primary = Color(0xFF2196F3); // Light Blue
  static const Color primaryLight = Color(0xFF64B5F6); // Lighter Blue
  static const Color primaryDark = Color(0xFF1976D2); // Darker Blue

  // Secondary Colors
  static const Color secondary = Color(0xFF03DAC6); // Teal
  static const Color secondaryLight = Color(0xFF56E0E0); // Light Teal
  static const Color secondaryDark = Color(0xFF018786); // Dark Teal

  // Accent Colors
  static const Color accent = Color(0xFF00BCD4); // Cyan
  static const Color accentLight = Color(0xFF62EFFF); // Light Cyan
  static const Color accentDark = Color(0xFF0097A7); // Dark Cyan

  // Background Colors
  static const Color background = Color(0xFFF5F5F5); // Light Grey
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceLight = Color(0xFFFAFAFA); // Very Light Grey

  // Text Colors
  static const Color textPrimary = Color(0xFF212121); // Dark Grey
  static const Color textSecondary = Color(0xFF757575); // Medium Grey
  static const Color textLight = Color(0xFFBDBDBD); // Light Grey
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFF9800); // Orange
  static const Color error = Color(0xFFF44336); // Red
  static const Color info = Color(0xFF2196F3); // Blue

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF2196F3), // Light Blue
    Color(0xFF64B5F6), // Lighter Blue
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF03DAC6), // Teal
    Color(0xFF56E0E0), // Light Teal
  ];

  static const List<Color> accentGradient = [
    Color(0xFF00BCD4), // Cyan
    Color(0xFF62EFFF), // Light Cyan
  ];

  // Card Colors
  static const Color cardBackground = Color(0xFFFFFFFF); // White
  static const Color cardShadow = Color(0x1A000000); // Black with 10% opacity

  // Border Colors
  static const Color border = Color(0xFFE0E0E0); // Light Grey
  static const Color borderFocused = Color(0xFF2196F3); // Light Blue

  // Icon Colors
  static const Color iconPrimary = Color(0xFF2196F3); // Light Blue
  static const Color iconSecondary = Color(0xFF757575); // Medium Grey
  static const Color iconLight = Color(0xFFBDBDBD); // Light Grey

  // Button Colors
  static const Color buttonPrimary = Color(0xFF2196F3); // Light Blue
  static const Color buttonSecondary = Color(0xFF03DAC6); // Teal
  static const Color buttonDisabled = Color(0xFFBDBDBD); // Light Grey

  // AppBar Colors
  static const Color appBarBackground = Color(0xFF2196F3); // Light Blue
  static const Color appBarText = Color(0xFFFFFFFF); // White

  // Input Field Colors
  static const Color inputBackground = Color(0xFFFFFFFF); // White
  static const Color inputBorder = Color(0xFFE0E0E0); // Light Grey
  static const Color inputBorderFocused = Color(0xFF2196F3); // Light Blue

  // Snackbar Colors
  static const Color snackbarSuccess = Color(0xFF4CAF50); // Green
  static const Color snackbarError = Color(0xFFF44336); // Red
  static const Color snackbarWarning = Color(0xFFFF9800); // Orange
  static const Color snackbarInfo = Color(0xFF2196F3); // Blue
}

