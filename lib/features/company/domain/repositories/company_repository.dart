import '../../../../core/typedefs/future_either.dart';
import '../entities/company.dart';

/// Minimal Company repository contract, sufficient for Auth's
/// registration flow. Extend with full CRUD/search/realtime when section
/// 5.2 (Gestion des entreprises) is implemented.
abstract class CompanyRepository {
  FutureEither<Company> getCompanyById(String companyId);
}
