import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/navigation/app_router.dart';
import '../core/navigation/navigation_service.dart';
import '../core/colors.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/navigation_cubit.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';
import '../core/services/trip_notification_scheduler.dart';

class MyApp extends StatelessWidget {
  final TripNotificationScheduler tripNotificationScheduler;
  
  const MyApp({super.key, required this.tripNotificationScheduler});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(
          create: (_) => TripCubit(
            tripRepository: TripRepository(),
            notificationScheduler: tripNotificationScheduler,
          ),
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