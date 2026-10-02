import 'package:equatable/equatable.dart';

import 'company.dart';

enum CompanyEventType { created, updated, deleted }

/// Emitted by [CompanyRepository.watchCompanies] realtime stream.
class CompanyRealtimeEvent extends Equatable {
  final CompanyEventType type;
  final Company company;

  const CompanyRealtimeEvent({required this.type, required this.company});

  @override
  List<Object?> get props => [type, company];
}
