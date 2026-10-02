import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/gestionnaire_creation_result.dart';
import '../repositories/auth_repository.dart';

class CreateGestionnaireAccountUseCase
    implements UseCase<GestionnaireCreationResult, CreateGestionnaireParams> {
  final AuthRepository repository;

  const CreateGestionnaireAccountUseCase(this.repository);

  @override
  FutureEither<GestionnaireCreationResult> call(CreateGestionnaireParams params) =>
      repository.createGestionnaireAccount(params);
}
