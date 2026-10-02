import '../entities/company_realtime_event.dart';
import '../repositories/company_repository.dart';

/// Realtime use cases return a [Stream] directly rather than a
/// [FutureEither] - there is no single terminal result to await.
class WatchCompaniesUseCase {
  final CompanyRepository repository;

  const WatchCompaniesUseCase(this.repository);

  Stream<CompanyRealtimeEvent> call() => repository.watchCompanies();
}
