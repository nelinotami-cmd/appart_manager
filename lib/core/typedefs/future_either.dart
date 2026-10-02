import 'package:dartz/dartz.dart';

import '../error/base_exception.dart';

/// Standard return type for every Repository / UseCase method in this
/// project. The Left side defaults to [BaseException]; a feature may
/// define its own typedef with a different Left type if it ever needs one,
/// but should reuse this one otherwise.
typedef FutureEither<T> = Future<Either<BaseException, T>>;
