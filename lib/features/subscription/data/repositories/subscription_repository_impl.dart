import 'package:appartements_erp/features/subscription/domain/entities/subscription_feature.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/base_exception.dart';
import '../../../../core/typedefs/future_either.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_plan_realtime_event.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_functions_remote_datasource.dart';
import '../datasources/subscription_remote_datasource.dart';
import '../models/subscription_plan_model.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;
  final SubscriptionFunctionsRemoteDataSource functionsDataSource;

  SubscriptionRepositoryImpl({
    required this.remoteDataSource,
    required this.functionsDataSource,
  });

  @override
  FutureEither<SubscriptionPlan> createPlan(CreatePlanParams params) async {
    try {
      final result = await functionsDataSource.createPlan({
        'name': params.name,
        'description': params.description,
        'monthlyPrice': params.monthlyPrice,
        'enabledFeatures': params.enabledFeatures.map((f) => f.value).toList(),
      });
      return Right(SubscriptionPlanModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<SubscriptionPlan> updatePlan(UpdatePlanParams params) async {
    try {
      final result = await functionsDataSource.updatePlan({
        'planId': params.planId,
        'name': params.name,
        'description': params.description,
        'monthlyPrice': params.monthlyPrice,
        'enabledFeatures': params.enabledFeatures.map((f) => f.value).toList(),
      });
      return Right(SubscriptionPlanModel.fromMap(result));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<int> deletePlan(String planId) async {
    try {
      final result = await functionsDataSource.deletePlan({'planId': planId});
      return Right((result['companiesUpdated'] as num?)?.toInt() ?? 0);
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<SubscriptionPlan> getPlanById(String planId) async {
    try {
      return Right(await remoteDataSource.getById(planId));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<SubscriptionPlan>> listPlans(
      {int limit = 25, int offset = 0}) async {
    try {
      return Right(await remoteDataSource.list(limit: limit, offset: offset));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  FutureEither<List<SubscriptionPlan>> searchPlans(String query) async {
    try {
      return Right(await remoteDataSource.search(query));
    } on BaseException catch (e) {
      return Left(e);
    }
  }

  @override
  Stream<SubscriptionPlanRealtimeEvent> watchPlans() =>
      remoteDataSource.watch();
}
