import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/company.dart';

enum CompanyDetailStatus { initial, loading, loaded, error }
enum CompanyListStatus { initial, loading, loaded, error }

class CompanyState extends Equatable {
  final CompanyDetailStatus detailStatus;
  final Company? currentCompany;
  final Failure? detailFailure;

  final CompanyListStatus listStatus;
  final List<Company> companies;
  final Failure? listFailure;

  const CompanyState({
    this.detailStatus = CompanyDetailStatus.initial,
    this.currentCompany,
    this.detailFailure,
    this.listStatus = CompanyListStatus.initial,
    this.companies = const [],
    this.listFailure,
  });

  const CompanyState.initial() : this();

  CompanyState copyWith({
    CompanyDetailStatus? detailStatus,
    Company? currentCompany,
    Failure? detailFailure,
    bool clearDetailFailure = false,
    CompanyListStatus? listStatus,
    List<Company>? companies,
    Failure? listFailure,
    bool clearListFailure = false,
  }) {
    return CompanyState(
      detailStatus: detailStatus ?? this.detailStatus,
      currentCompany: currentCompany ?? this.currentCompany,
      detailFailure: clearDetailFailure ? null : (detailFailure ?? this.detailFailure),
      listStatus: listStatus ?? this.listStatus,
      companies: companies ?? this.companies,
      listFailure: clearListFailure ? null : (listFailure ?? this.listFailure),
    );
  }

  @override
  List<Object?> get props => [
        detailStatus,
        currentCompany,
        detailFailure,
        listStatus,
        companies,
        listFailure,
      ];
}
