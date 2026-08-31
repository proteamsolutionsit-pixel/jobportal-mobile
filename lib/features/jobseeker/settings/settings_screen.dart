/// Settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/environment.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/router.dart';
import '../authentication/auth_controller.dart';
import '../profile/profile_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final viewers = ref.watch(viewersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Heading('Account'),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Email address'),
            subtitle: Text(user?.email ?? ''),
            trailing: user?.isEmailVerified == true
                ? const Tag('Verified', background: C.ok50, foreground: C.ok600)
                : const Tag('Unverified',
                    background: C.warn50, foreground: C.warn600),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.changePassword),
          ),

          const _Heading('Job search'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Job alerts'),
            subtitle: const Text('Get told when matching jobs are posted'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.alerts),
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('What we email you about'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.notificationPrefs),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Who viewed my profile'),
            subtitle: viewers.maybeWhen(
              // The payload's own total. NEVER list.length — this is the exact
              // endpoint that once told a candidate opened forty times by three
              // agencies that they had "3 views", because the list was capped
              // at fifty and the label counted recruiter rows.
              data: (v) => Text(
                v.total == 0
                    ? 'No views yet'
                    : '${v.total} ${v.total == 1 ? 'view' : 'views'}',
              ),
              orElse: () => null,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showViewers(context, ref),
          ),

          const _Heading('Security'),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () => _signOut(context, ref, everywhere: false),
          ),
          ListTile(
            leading: const Icon(Icons.devices_other_rounded),
            title: const Text('Sign out on all devices'),
            subtitle: const Text('Ends every session, including this one'),
            onTap: () => _signOut(context, ref, everywhere: true),
          ),

          const _Heading('Danger zone'),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: C.bad500),
            title: const Text('Delete my account',
                style: TextStyle(color: C.bad600)),
            subtitle: const Text('Permanent. Your profile and CV are removed.'),
            onTap: () => _confirmDelete(context, ref),
          ),

          const SizedBox(height: Sp.x6),
          Center(
            child: Text(
              Env.isProduction
                  ? 'JobPortal 1.0.0'
                  : 'JobPortal 1.0.0 · ${Env.current.name}',
              style: const TextStyle(fontSize: 12, color: C.ink400),
            ),
          ),
          const SizedBox(height: Sp.x6),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x5, Sp.x4, Sp.x2),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

Future<void> _signOut(
  BuildContext context,
  WidgetRef ref, {
  required bool everywhere,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(everywhere ? 'Sign out everywhere?' : 'Sign out?'),
      content: Text(
        everywhere
            ? 'Every device signed in to this account will be signed out, '
                'including this one.'
            : 'You will need to sign in again on this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  // Both call the server first and clear locally regardless — clearing only
  // locally would leave a live token until it expires.
  final controller = ref.read(authControllerProvider.notifier);
  everywhere ? await controller.logoutEverywhere() : await controller.logout();
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This removes your profile, your CV and your application history. '
            'It cannot be undone.',
          ),
          const SizedBox(height: Sp.x4),
          const Text('Type DELETE to confirm.'),
          const SizedBox(height: Sp.x2),
          TextField(
            controller: controller,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(controller.text.trim().toUpperCase() == 'DELETE'),
          style: FilledButton.styleFrom(backgroundColor: C.bad500),
          child: const Text('Delete permanently'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (ok != true || !context.mounted) return;

  try {
    await ref.read(seekerRepositoryProvider).deleteAccount();
    ref.read(authControllerProvider.notifier).markSignedOut();
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}

Future<void> _showViewers(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final viewers = ref.watch(viewersProvider);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Who viewed my profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    viewers.maybeWhen(
                      data: (v) => Text(
                        '${v.total}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: viewers.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Could not load right now.'),
                  ),
                  data: (v) => v.viewers.isEmpty
                      ? const Center(child: Text('No views yet.'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: v.viewers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final row = v.viewers[i];
                            final name = (row['company_name'] ??
                                    row['company'] ??
                                    row['name'] ??
                                    'A recruiter')
                                .toString();
                            return ListTile(
                              leading: CompanyLogo(
                                path: row['logo_path'] as String?,
                                name: name,
                                size: 38,
                              ),
                              title: Text(name),
                              subtitle: row['viewed_at'] == null
                                  ? null
                                  : Text('Viewed ${row['viewed_at']}'),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
