import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/company.dart';
import '../../domain/entities/company_status.dart';
import '../bloc/company_bloc.dart';
import '../bloc/company_event.dart';
import '../bloc/company_state.dart';
import 'company_detail_page.dart';

/// Matches the reference `Gestion des Entreprises` mockups (desktop
/// table / mobile cards) - Super Admin's list of every company.
///
/// Dropped from the mockups (see scope note in the session summary):
/// "Inscrire une Entreprise" button (no standalone create-company
/// resource - creation is exclusively via 5.1's registration flow),
/// Total Clients / Taux d'Activation / MRR stat cards (not in cahier des
/// charges 5.2, and MRR specifically implies billing/invoicing that
/// isn't built).
///
/// Hosted inside `AppShell`; search is driven externally via
/// [searchQuery] (see `AppDestination.hasSearch`), same pattern as
/// `CompanyUsersPage`. The status filter below is a separate, local
/// control (client-side filter over the already-loaded list) since the
/// shell's one search field is already spoken for by name search.
class CompaniesListPage extends StatefulWidget {
  final String searchQuery;

  const CompaniesListPage({super.key, this.searchQuery = ''});

  @override
  State<CompaniesListPage> createState() => _CompaniesListPageState();
}

enum _StatusFilter { all, active, inactive }

class _CompaniesListPageState extends State<CompaniesListPage> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      context.read<CompanyBloc>()
        ..add(const CompanyListLoadRequested())
        ..add(const CompanyListWatchStarted());
    }
  }

  @override
  void didUpdateWidget(covariant CompaniesListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      final query = widget.searchQuery.trim();
      if (query.isEmpty) {
        context.read<CompanyBloc>().add(const CompanyListLoadRequested());
      } else {
        context.read<CompanyBloc>().add(CompanySearchRequested(query: query));
      }
    }
  }

  @override
  void dispose() {
    context.read<CompanyBloc>().add(const CompanyListWatchStopped());
    super.dispose();
  }

  List<Company> _applyStatusFilter(List<Company> companies) {
    switch (_statusFilter) {
      case _StatusFilter.all:
        return companies;
      case _StatusFilter.active:
        return companies.where((c) => c.status == CompanyStatus.active).toList();
      case _StatusFilter.inactive:
        return companies.where((c) => c.status == CompanyStatus.inactive).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des Entreprises', style: AppTextStyles.headlineMd),
                    const SizedBox(height: 4),
                    Text(
                      "Gerez les profils clients et leur statut d'activation.",
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                ),
              ),
              DropdownButton<_StatusFilter>(
                value: _statusFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: _StatusFilter.all, child: Text('Tous les statuts')),
                  DropdownMenuItem(value: _StatusFilter.active, child: Text('Actif')),
                  DropdownMenuItem(value: _StatusFilter.inactive, child: Text('Inactif')),
                ],
                onChanged: (value) => setState(() => _statusFilter = value ?? _StatusFilter.all),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: BlocBuilder<CompanyBloc, CompanyState>(
              buildWhen: (previous, current) =>
                  previous.listStatus != current.listStatus ||
                  previous.companies != current.companies,
              builder: (context, state) {
                if (state.listStatus == CompanyListStatus.loading && state.companies.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.listStatus == CompanyListStatus.error && state.companies.isEmpty) {
                  return Center(
                    child: Text(
                      state.listFailure?.message ?? 'Une erreur est survenue.',
                      style: AppTextStyles.bodyMd,
                    ),
                  );
                }
                final companies = _applyStatusFilter(state.companies);
                if (companies.isEmpty) {
                  return Center(
                    child: Text('Aucune entreprise trouvee.', style: AppTextStyles.bodyMd),
                  );
                }
                return isWide
                    ? _CompaniesTable(companies: companies)
                    : ListView.separated(
                        itemCount: companies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _CompanyCard(company: companies[index]),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompaniesTable extends StatelessWidget {
  final List<Company> companies;

  const _CompaniesTable({required this.companies});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('ENTREPRISE', style: AppTextStyles.labelSm)),
                Expanded(flex: 3, child: Text('CONTACT', style: AppTextStyles.labelSm)),
                Expanded(flex: 2, child: Text('STATUT', style: AppTextStyles.labelSm)),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: companies.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.surfaceContainerHighest),
              itemBuilder: (context, index) {
                final company = companies[index];
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CompanyDetailPage(companyId: company.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(company.name, style: AppTextStyles.bodySm)),
                        Expanded(
                          flex: 3,
                          child: Text(company.contactEmail, style: AppTextStyles.bodySm),
                        ),
                        Expanded(flex: 2, child: _StatusBadge(company: company)),
                        const SizedBox(
                          width: 48,
                          child: Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final Company company;

  const _CompanyCard({required this.company});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CompanyDetailPage(companyId: company.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.surfaceContainerHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(company.name, style: AppTextStyles.bodyMd)),
                  _StatusBadge(company: company),
                ],
              ),
              const SizedBox(height: 4),
              Text(company.contactEmail, style: AppTextStyles.bodySm),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Company company;

  const _StatusBadge({required this.company});

  @override
  Widget build(BuildContext context) {
    final isActive = company.status == CompanyStatus.active;
    final bg = isActive ? AppColors.successContainer : AppColors.surfaceContainerHigh;
    final fg = isActive ? AppColors.onSuccessContainer : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: AppTextStyles.labelSm.copyWith(color: fg),
      ),
    );
  }
}
