import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationState {
  final String? message;
  NotificationState({this.message});
}

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(NotificationState());

  void showNotification(String message) {
    emit(NotificationState(message: message));
    // Reset after showing so it doesn't repeat
    emit(NotificationState());
  }
}
