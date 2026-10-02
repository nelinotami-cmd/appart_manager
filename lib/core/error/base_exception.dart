/// Base class for every exception thrown from the Data layer.
///
/// Every concrete exception carries a short [title] (suitable for a dialog
/// title or snackbar header) and a human-readable [message] (suitable for
/// display to a non-technical end user, in French, since the MVP targets
/// French-speaking managers in Cameroon).
abstract class BaseException implements Exception {
  final String title;
  final String message;

  const BaseException({required this.title, required this.message});

  @override
  String toString() => '$title: $message';
}

/// Thrown when the backend (Appwrite) returns an unexpected/server-side
/// error (5xx, network failure reaching Appwrite, unknown SDK error).
class ServerException extends BaseException {
  const ServerException({
    super.title = 'Erreur serveur',
    super.message = "Une erreur est survenue cote serveur. Veuillez reessayer.",
  });
}

/// Thrown for any authentication/authorization failure: bad credentials,
/// expired/invalid session, invalid OTP, insufficient role, etc.
class AuthException extends BaseException {
  const AuthException({
    super.title = "Erreur d'authentification",
    required super.message,
  });
}

/// Thrown when input supplied by the caller is invalid (caught before or
/// mapped from a backend validation error).
class ValidationException extends BaseException {
  const ValidationException({
    super.title = 'Erreur de validation',
    required super.message,
  });
}

/// Thrown when a requested resource (document, account) does not exist.
class NotFoundException extends BaseException {
  const NotFoundException({
    super.title = 'Introuvable',
    required super.message,
  });
}

/// Thrown when the current actor is not allowed to perform the requested
/// operation (e.g. a Gestionnaire trying to create another Gestionnaire).
class PermissionException extends BaseException {
  const PermissionException({
    super.title = 'Acces refuse',
    required super.message,
  });
}

/// Thrown by local/hydrated storage operations.
class CacheException extends BaseException {
  const CacheException({
    super.title = 'Erreur locale',
    super.message = "Une erreur est survenue lors de l'acces au stockage local.",
  });
}
