part of 'location_comments_cubit.dart';

abstract class LocationCommentsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LocationCommentsInitial extends LocationCommentsState {}

class LocationCommentsLoading extends LocationCommentsState {}

class LocationCommentsLoaded extends LocationCommentsState {
  final List<LocationComment> comments;
  LocationCommentsLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class LocationCommentsError extends LocationCommentsState {
  final String message;
  LocationCommentsError(this.message);

  @override
  List<Object?> get props => [message];
}
