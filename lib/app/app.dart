import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/navigation/app_router.dart';
import '../core/navigation/navigation_service.dart';
import '../core/colors.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/navigation_cubit.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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