import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/onboarding_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

const _onboardingSteps = 4;

class OnboardingAdminScreen extends ConsumerWidget {
  const OnboardingAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(onboardingLinksProvider);
    final submissions = ref.watch(onboardingSubmissionsProvider);
    final isWide = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canCreate = user?.hasPermission('onboarding_create') ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Onboarding Flow Management',
                  subtitle:
                      'Streamlining secure documentation and employee integration.',
                ),
              ),
              if (canCreate)
                PrimaryButton(
                  label: 'Generate Secure Link',
                  icon: Icons.link,
                  color: AppColors.brandBlue,
                  onPressed: () => _createLink(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 22),
          // Stat + rapid onboarding row
          submissions.when(
            data: (subs) {
              final pending = subs
                  .where((s) =>
                      s.status == OnboardingSubmissionStatus.submitted)
                  .length;
              final active = subs
                  .where((s) =>
                      s.status != OnboardingSubmissionStatus.approved &&
                      s.status != OnboardingSubmissionStatus.rejected)
                  .length;
              final cards = [
                StatCard(
                  label: 'Pending Reviews',
                  value: '$pending',
                  icon: Icons.verified_outlined,
                  iconColor: AppColors.brandBlue,
                  iconBg: AppColors.brandBlueSoft,
                  footer: 'Awaiting approval',
                ),
                StatCard(
                  label: 'Active Onboarding',
                  value: '$active',
                  icon: Icons.event_note_outlined,
                  footer: 'Candidates in progress',
                ),
              ];
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _RapidCard(links: links)),
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 12),
                  _RapidCard(links: links),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Candidates in Onboarding'),
                const SizedBox(height: 14),
                submissions.when(
                  data: (subs) {
                    if (subs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text('No candidates yet',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final s in subs)
                          _CandidateRow(sub: s, isWide: isWide, ref: ref),
                      ],
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator())),
                  error: (e, _) => Text('$e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          submissions.when(
            data: (subs) => _PipelineHealth(subs: subs, isWide: isWide),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _createLink(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final link =
        await ref.read(onboardingServiceProvider).createLink(createdBy: user.id);
    if (context.mounted) {
      Clipboard.setData(ClipboardData(text: link.shareUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secure link created & copied')),
      );
    }
  }
}

class _RapidCard extends StatelessWidget {
  const _RapidCard({required this.links});
  final AsyncValue<List<OnboardingLinkModel>> links;

  @override
  Widget build(BuildContext context) {
    final active = links.valueOrNull
        ?.where((l) => l.status == OnboardingLinkStatus.active)
        .toList();
    final url = (active != null && active.isNotEmpty)
        ? active.first.shareUrl
        : 'Generate a secure link to begin';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandNavy, AppColors.brandBlue],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Rapid Onboarding',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Send pre-validated onboarding packages to new hires with high-grade encryption.',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (active != null && active.isNotEmpty)
                    ? () {
                        Clipboard.setData(ClipboardData(text: url));
                        Share.share('Complete your onboarding: $url');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandNavy,
                  elevation: 0,
                ),
                child: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow(
      {required this.sub, required this.isWide, required this.ref});
  final OnboardingSubmissionModel sub;
  final bool isWide;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final name = '${sub.firstName ?? ''} ${sub.lastName ?? ''}'.trim();
    final progress = (sub.currentStep / _onboardingSteps).clamp(0.0, 1.0);
    final pill = switch (sub.status) {
      OnboardingSubmissionStatus.approved => StatusPill.green('READY'),
      OnboardingSubmissionStatus.submitted => StatusPill.green('ACTIVE'),
      OnboardingSubmissionStatus.rejected => StatusPill.red('REJECTED'),
      OnboardingSubmissionStatus.draft => StatusPill.blue('INVITED'),
    };

    return InkWell(
      onTap: () {
        final adminId = ref.read(currentUserProvider).valueOrNull?.id ?? '';
        showDialog(
          context: context,
          builder: (_) => _ReviewDialog(submission: sub, adminId: adminId),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      InitialAvatar(
                          name: name.isNotEmpty ? name : '?', size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isNotEmpty ? name : 'Unnamed',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandNavy),
                                overflow: TextOverflow.ellipsis),
                            Text(sub.email ?? '—',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide)
                  Expanded(
                    flex: 3,
                    child: Text(sub.department ?? '—',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textBody)),
                  ),
                if (isWide)
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: AppColors.brandBlueSoft,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(progress * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textBody)),
                      ],
                    ),
                  ),
                Expanded(
                    flex: 2,
                    child: Align(
                        alignment: Alignment.centerLeft, child: pill)),
                if (sub.status == OnboardingSubmissionStatus.submitted)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Review',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandBlue)),
                  ),
                const Icon(Icons.chevron_right, color: AppColors.textFaint),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
        ],
      ),
    );
  }
}

/// Full read of a submitted form + admin-only fields (salary / position /
/// department) → approve or reject. Approved/rejected submissions open
/// read-only so the form can always be re-read.
class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.submission, required this.adminId});
  final OnboardingSubmissionModel submission;
  final String adminId;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  late final TextEditingController _salary;
  late final TextEditingController _position;
  String? _department;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _salary = TextEditingController();
    _position = TextEditingController(text: widget.submission.position ?? '');
    _department = widget.submission.department;
  }

  @override
  void dispose() {
    _salary.dispose();
    _position.dispose();
    super.dispose();
  }

  bool get _pending =>
      widget.submission.status == OnboardingSubmissionStatus.submitted;

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final departments = [
      for (final d in (ref.watch(departmentsProvider).valueOrNull ?? const []))
        d.name as String
    ];
    final name = '${s.firstName ?? ''} ${s.lastName ?? ''}'.trim();

    return Theme(
      data: AppTheme.light(),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Expanded(
              child: Text(name.isEmpty ? 'Submission' : name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (!_pending)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.pillGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s.status.name.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pillGreenFg)),
              ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submitted by the employee',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                const SizedBox(height: 8),
                _kv('Email', s.email),
                _kv("Father's name", s.fatherName),
                _kv('CNIC / ID', s.cnic),
                _kv('Phone', s.phone),
                _kv('Address', s.address),
                _kv('Department (chosen)', s.department),
                _kv('Designation (chosen)', s.position),
                const Divider(height: 26),
                Text(
                  _pending
                      ? 'Set by HR (not entered by the employee)'
                      : 'Set by HR at approval',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _salary,
                  enabled: _pending,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Salary',
                    prefixText: 'Rs ',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _position,
                  enabled: _pending,
                  decoration: const InputDecoration(
                    labelText: 'Position / Designation',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue:
                      departments.contains(_department) ? _department : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Department', isDense: true,
                      border: OutlineInputBorder()),
                  items: [
                    for (final d in departments)
                      DropdownMenuItem<String?>(value: d, child: Text(d)),
                  ],
                  onChanged:
                      _pending ? (v) => setState(() => _department = v) : null,
                ),
              ],
            ),
          ),
        ),
        actions: _pending
            ? [
                TextButton(
                  onPressed: _busy ? null : () => _reject(),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
                TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Close')),
                PrimaryButton(
                  label: _busy ? 'Approving…' : 'Approve & add',
                  onPressed: _busy ? () {} : () => _approve(),
                ),
              ]
            : [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
      ),
    );
  }

  Widget _kv(String k, String? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted))),
            Expanded(
              child: Text((v == null || v.isEmpty) ? '—' : v,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody)),
            ),
          ],
        ),
      );

  Future<void> _approve() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(onboardingServiceProvider).approveSubmission(
            widget.submission,
            widget.adminId,
            salary: double.tryParse(_salary.text.trim()),
            position:
                _position.text.trim().isEmpty ? null : _position.text.trim(),
            department: _department,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(
            SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(onboardingServiceProvider)
          .rejectSubmission(widget.submission.id, widget.adminId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(
            SnackBar(content: Text(AppException.from(e).message)));
      }
    }
  }
}

class _PipelineHealth extends StatelessWidget {
  const _PipelineHealth({required this.subs, required this.isWide});
  final List<OnboardingSubmissionModel> subs;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final invited =
        subs.where((s) => s.status == OnboardingSubmissionStatus.draft).length;
    final submitted = subs
        .where((s) => s.status == OnboardingSubmissionStatus.submitted)
        .length;
    final approved = subs
        .where((s) => s.status == OnboardingSubmissionStatus.approved)
        .length;

    final stages = [
      ('Form Initiation', Icons.assignment_outlined, invited, AppColors.brandBlue),
      ('Document Upload', Icons.cloud_upload_outlined, submitted,
          AppColors.brandBlue),
      ('Admin Review', Icons.fact_check_outlined, submitted,
          AppColors.pillAmberFg),
      ('Final Approval', Icons.verified_outlined, approved,
          AppColors.pillGreenFg),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Onboarding Pipeline Health',
            subtitle: 'Visual overview of bottlenecks and flow efficiency.',
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in stages)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: (s.$4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(s.$2, color: s.$4, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(s.$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.heading)),
                      const SizedBox(height: 2),
                      Text('${s.$3} candidates',
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
