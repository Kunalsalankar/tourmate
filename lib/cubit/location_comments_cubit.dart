import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/models/location_comment.dart';
import '../core/repositories/location_comments_repository.dart';

part 'location_comments_state.dart';

class LocationCommentsCubit extends Cubit<LocationCommentsState> {
  final LocationCommentsRepository _repository;
  StreamSubscription? _sub;

  LocationCommentsCubit({LocationCommentsRepository? repository})
    : _repository = repository ?? LocationCommentsRepository(),
      super(LocationCommentsInitial());

  void startListeningAll() {
    _sub?.cancel();
    emit(LocationCommentsLoading());
    _sub = _repository.streamAllComments().listen(
      (snapshot) {
        final comments = snapshot.docs.map((d) {
          final data = d.data();
          return LocationComment.fromMap(data, d.id);
        }).toList();
        emit(LocationCommentsLoaded(comments));
      },
      onError: (e) {
        emit(LocationCommentsError(e.toString()));
      },
    );
  }

  Future<void> addComment({
    required LatLng position,
    required String userName,
    required String comment,
  }) async {
    try {
      await _repository.addComment(
        latitude: position.latitude,
        longitude: position.longitude,
        userName: userName,
        comment: comment,
      );
    } catch (e) {
      emit(LocationCommentsError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
