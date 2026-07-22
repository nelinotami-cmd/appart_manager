import 'package:equatable/equatable.dart';

abstract class CompanyEvent extends Equatable {
  const CompanyEvent();

  @override
  List<Object?> get props => [];
}

/// Loads a single company for the detail/edit view - an Admin's own
/// company, or (Super Admin) any company by id.
class CompanyDetailLoadRequested extends CompanyEvent {
  final String companyId;

  const CompanyDetailLoadRequested({required this.companyId});

  @override
  List<Object?> get props => [companyId];
}

class CompanyProfileUpdateRequested extends CompanyEvent {
  final String companyId;
  final String name;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String address;

  const CompanyProfileUpdateRequested({
    required this.companyId,
    required this.name,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
  });

  @override
  List<Object?> get props =>
      [companyId, name, contactName, contactEmail, contactPhone, address];
}

/// Super Admin only (enforced server-side).
class CompanyStatusUpdateRequested extends CompanyEvent {
  final String companyId;
  final bool activate;

  const CompanyStatusUpdateRequested({required this.companyId, required this.activate});

  @override
  List<Object?> get props => [companyId, activate];
}

/// Super Admin only (enforced server-side).
class CompanyPlanAssignRequested extends CompanyEvent {
  final String companyId;
  final String? subscriptionPlanId;

  const CompanyPlanAssignRequested({required this.companyId, required this.subscriptionPlanId});

  @override
  List<Object?> get props => [companyId, subscriptionPlanId];
}

/// Super Admin's "all companies" list.
class CompanyListLoadRequested extends CompanyEvent {
  const CompanyListLoadRequested();
}

class CompanySearchRequested extends CompanyEvent {
  final String query;

  const CompanySearchRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class CompanyListWatchStarted extends CompanyEvent {
  const CompanyListWatchStarted();
}

class CompanyListWatchStopped extends CompanyEvent {
  const CompanyListWatchStopped();
}
