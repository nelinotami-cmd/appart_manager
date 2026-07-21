import 'package:equatable/equatable.dart';

/// Marker object for use cases that take no parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
