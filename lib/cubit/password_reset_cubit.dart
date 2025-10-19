import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit() : super(PasswordResetInitial());

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    emit(PasswordResetLoading());
    try {
      // First, sign in anonymously to access the updatePassword method
      await _auth.signInAnonymously();
      
      // Get the user by email
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        emit(PasswordResetFailure('No account found with this email'));
        return;
      }
      
      // Send password reset email to get a fresh credential
      await _auth.sendPasswordResetEmail(email: email);
      
      // Sign in with email link (user will get an email with a link)
      // Note: In a real app, you would handle the email link flow properly
      // This is a simplified version for demonstration
      
      // For security reasons, we'll just tell the user to check their email
      // and then they can set a new password through the email link
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
