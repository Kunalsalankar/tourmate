import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit() : super(PasswordResetInitial());

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sends a password reset email to the user
  /// Firebase will send an email with a link to reset the password
  /// No authentication is required for this operation
  Future<void> sendPasswordResetEmail(String email) async {
    emit(PasswordResetLoading());
    try {
      await _auth.sendPasswordResetEmail(email: email);
      emit(PasswordResetEmailSent());
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      emit(PasswordResetFailure(message));
    } catch (e) {
      emit(PasswordResetFailure('An unexpected error occurred'));
    }
  }
}

abstract class PasswordResetState {}

class PasswordResetInitial extends PasswordResetState {}

class PasswordResetLoading extends PasswordResetState {}

class PasswordResetSuccess extends PasswordResetState {}

class PasswordResetEmailSent extends PasswordResetState {}

class PasswordResetFailure extends PasswordResetState {
  final String message;
  PasswordResetFailure(this.message);
}
