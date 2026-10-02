import '../../../../core/typedefs/future_either.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class DeleteGestionnaireAccountUseCase
    implements UseCase<void, DeleteGestionnaireParams> {
  final AuthRepository repository;

  const DeleteGestionnaireAccountUseCase(this.repository);

  @override
  FutureEither<void> call(DeleteGestionnaireParams params) =>
      repository.deleteGestionnaireAccount(params);
}
