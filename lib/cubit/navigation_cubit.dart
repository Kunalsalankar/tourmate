import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/navigation/navigation_service.dart';
import '../core/navigation/app_router.dart';

class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(NavigationInitial());

  void navigateToRoleSelection() {
    NavigationService.navigateTo(AppRouter.roleSelection);
    emit(NavigationToRoleSelection());
  }

  void navigateToUserSignIn() {
    NavigationService.navigateTo(AppRouter.userSignIn);
    emit(NavigationToUserSignIn());
  }

  void navigateToUserSignUp() {
    NavigationService.navigateTo(AppRouter.userSignUp);
    emit(NavigationToUserSignUp());
  }

  void navigateToAdminSignIn() {
    NavigationService.navigateTo(AppRouter.adminSignIn);
    emit(NavigationToAdminSignIn());
  }

  void navigateToAdminSignUp() {
    NavigationService.navigateTo(AppRouter.adminSignUp);
    emit(NavigationToAdminSignUp());
  }

  void navigateBack() {
    NavigationService.goBack();
    emit(NavigationBack());
  }
}

abstract class NavigationState {}

class NavigationInitial extends NavigationState {}

class NavigationToRoleSelection extends NavigationState {}

class NavigationToUserSignIn extends NavigationState {}

class NavigationToUserSignUp extends NavigationState {}

class NavigationToAdminSignIn extends NavigationState {}

class NavigationToAdminSignUp extends NavigationState {}

class NavigationBack extends NavigationState {}

