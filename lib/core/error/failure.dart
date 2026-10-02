import 'package:equatable/equatable.dart';

import 'base_exception.dart';

/// Presentation-friendly, equatable representation of a [BaseException].
///
/// Repositories return `Either<BaseException, T>` (see [FutureEither]) so
/// that use cases and the Bloc layer can pattern-match on concrete
/// exception types when needed. [Failure] is a lightweight, Equatable
/// wrapper that Blocs can hold directly inside their state without pulling
/// the exception hierarchy into Presentation-level equality checks.
class Failure extends Equatable {
  final String title;
  final String message;

  const Failure({required this.title, required this.message});

  factory Failure.fromException(BaseException exception) => Failure(
        title: exception.title,
        message: exception.message,
      );

  @override
  List<Object?> get props => [title, message];
}
