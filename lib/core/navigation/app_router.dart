import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
import '../../screens/role_selection_screen.dart';
import '../../user/sign_in_screen.dart';
import '../../user/sign_up/sign_up_screen.dart';
import '../../admin/sign_up/admin_sign_in_screen.dart';
import '../../admin/sign_up/admin_sign_up_screen.dart';
import '../../user/home_screen.dart';
import '../../admin/admin_trips_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String userSignIn = '/user-sign-in';
  static const String userSignUp = '/user-sign-up';
  static const String adminSignIn = '/admin-sign-in';
  static const String adminSignUp = '/admin-sign-up';
  static const String userHome = '/user-home';
  static const String adminTrips = '/admin-trips';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case roleSelection:
        return MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
          settings: settings,
        );
      case userSignIn:
        return MaterialPageRoute(
          builder: (_) => const SignInScreen(),
          settings: settings,
        );
      case userSignUp:
        return MaterialPageRoute(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case adminSignIn:
        return MaterialPageRoute(
          builder: (_) => const AdminSignInScreen(),
          settings: settings,
        );
      case adminSignUp:
        return MaterialPageRoute(
          builder: (_) => const AdminSignUpScreen(),
          settings: settings,
        );
      case userHome:
        return MaterialPageRoute(
          builder: (_) => const UserHomeScreen(),
          settings: settings,
        );
      case adminTrips:
        return MaterialPageRoute(
          builder: (_) => const AdminTripsScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
          settings: settings,
        );
    }
  }
}
