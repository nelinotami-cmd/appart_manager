import '../typedefs/future_either.dart';

/// Every use case in the Domain layer implements this contract.
///
/// [Type] is the successful return type, [Params] is the (Equatable) input
/// object. Use cases with no input use [NoParams].
abstract class UseCase<Type, Params> {
  FutureEither<Type> call(Params params);
}
