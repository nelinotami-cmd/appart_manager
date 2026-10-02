import 'package:equatable/equatable.dart';

import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/subscription_plan.dart';
import '../repositories/subscription_repository.dart';

class ListPlansParams extends Equatable {
  final int limit;
  final int offset;

  const ListPlansParams({this.limit = 25, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}

class ListPlansUseCase implements UseCase<List<SubscriptionPlan>, ListPlansParams> {
  final SubscriptionRepository repository;

  const ListPlansUseCase(this.repository);

  @override
  FutureEither<List<SubscriptionPlan>> call(ListPlansParams params) =>
      repository.listPlans(limit: params.limit, offset: params.offset);
}
