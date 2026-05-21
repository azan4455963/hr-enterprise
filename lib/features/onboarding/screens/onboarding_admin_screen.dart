import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/onboarding_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/service_providers.dart';

class OnboardingAdminScreen extends ConsumerWidget {
  const OnboardingAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(onboardingLinksProvider);
    final submissions = ref.watch(onboardingSubmissionsProvider);

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Employee Onboarding',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  PermissionGate(
                    permission: 'onboarding_create',
                    child: ElevatedButton.icon(
                      onPressed: () => _createLink(context, ref),
                      icon: const Icon(Icons.link),
                      label: const Text('Generate Link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TabBar(
                tabs: [
                  Tab(text: 'Links'),
                  Tab(text: 'Submissions'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    links.when(
                      data: (list) => _LinksList(links: list),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                    ),
                    submissions.when(
                      data: (list) => _SubmissionsList(submissions: list),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLink(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final link = await ref.read(onboardingServiceProvider).createLink(
          createdBy: user.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link created: ${link.shareUrl}')),
      );
    }
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList({required this.links});

  final List<OnboardingLinkModel> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const Center(child: Text('No onboarding links'));
    return ListView.builder(
      itemCount: links.length,
      itemBuilder: (_, i) {
        final link = links[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              title: Text(link.title),
              subtitle: Text(
                'Expires: ${link.expiresAt?.toString().split(' ').first ?? 'Never'} • '
                'Uses: ${link.usedCount}/${link.maxUses}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link.shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share(
                      'Complete your onboarding: ${link.shareUrl}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubmissionsList extends ConsumerWidget {
  const _SubmissionsList({required this.submissions});

  final List<OnboardingSubmissionModel> submissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (submissions.isEmpty) {
      return const Center(child: Text('No submissions yet'));
    }
    return ListView.builder(
      itemCount: submissions.length,
      itemBuilder: (_, i) {
        final sub = submissions[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              title: Text('${sub.firstName ?? ''} ${sub.lastName ?? ''}'.trim()),
              subtitle: Text(sub.status.name),
              trailing: sub.status == OnboardingSubmissionStatus.submitted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: AppColors.success),
                          onPressed: () async {
                            final user =
                                ref.read(currentUserProvider).valueOrNull;
                            if (user != null) {
                              await ref
                                  .read(onboardingServiceProvider)
                                  .approveSubmission(sub, user.id);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.error),
                          onPressed: () async {
                            final user =
                                ref.read(currentUserProvider).valueOrNull;
                            if (user != null) {
                              await ref
                                  .read(onboardingServiceProvider)
                                  .rejectSubmission(sub.id, user.id);
                            }
                          },
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
