import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/navigation/app_router.dart';
import '../core/navigation/navigation_service.dart';
import '../core/colors.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/navigation_cubit.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';
import '../core/services/trip_status_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TripStatusService _tripStatusService = TripStatusService();

  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes to start/stop trip monitoring
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User is signed in, start monitoring trip statuses
        _tripStatusService.startMonitoring();
      } else {
        // User is signed out, stop monitoring
        _tripStatusService.stopMonitoring();
      }
    });
  }

  @override
  void dispose() {
    _tripStatusService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(
          create: (_) => TripCubit(tripRepository: TripRepository()),
        ),
      ],
      child: MaterialApp(
        title: 'Tourmate',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          useMaterial3: true,
        ),
        navigatorKey: NavigationService.navigatorKey,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRouter.splash,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}