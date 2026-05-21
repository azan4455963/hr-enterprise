import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_providers.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(employeeServiceProvider).getEmployee(employeeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final emp = snapshot.data;
        if (emp == null) {
          return const Scaffold(body: Center(child: Text('Employee not found')));
        }
        final user = ref.watch(currentUserProvider).valueOrNull;
        final canViewSalary = user != null &&
            ref.watch(rbacServiceProvider).canViewSalary(user);

        return Scaffold(
          appBar: AppBar(
            title: Text(emp.fullName),
            actions: [
              PermissionGate(
                permission: 'employees_edit',
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      context.push('/employees/$employeeId/edit'),
                ),
              ),
              PermissionGate(
                permission: 'employees_delete',
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GlassCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: emp.profilePictureUrl != null
                            ? NetworkImage(emp.profilePictureUrl!)
                            : null,
                        child: emp.profilePictureUrl == null
                            ? Text(emp.firstName[0],
                                style: const TextStyle(fontSize: 32))
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(emp.fullName,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Text(emp.position ?? ''),
                            Text(emp.departmentName ?? ''),
                            Chip(label: Text(emp.status.name)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _infoCard('Contact', [
                  _row('Email', emp.email),
                  _row('Phone', emp.phone ?? '-'),
                  _row('Address', emp.address ?? '-'),
                ]),
                _infoCard('Personal', [
                  _row('Father Name', emp.fatherName ?? '-'),
                  _row('CNIC', emp.cnic ?? '-'),
                ]),
                _infoCard('Employment', [
                  _row('Joining',
                      emp.joiningDate?.toString().split(' ').first ?? '-'),
                  if (canViewSalary) _row('Salary', '\$${emp.salary ?? 0}'),
                ]),
                if (emp.documentUrls.isNotEmpty)
                  _infoCard('Documents', [
                    for (final url in emp.documentUrls)
                      ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(url.split('/').last),
                        dense: true,
                      ),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await ref.read(employeeServiceProvider).deleteEmployee(
              employeeId,
              userId: user.id,
            );
      }
      if (context.mounted) context.go('/employees');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
