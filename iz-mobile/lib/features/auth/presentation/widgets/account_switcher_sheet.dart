import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iz_mobile/core/theme/app_theme.dart';
import 'package:iz_mobile/features/auth/providers/account_provider.dart';

class AccountSwitcherSheet extends ConsumerWidget {
  const AccountSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final activeId = accountState.activeAccountId;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesap Değiştir',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          ...accountState.accounts.map((acc) {
            final isActive = acc.id == activeId;
            final avatarChar = acc.username.isNotEmpty ? acc.username[0].toUpperCase() : '?';
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: acc.avatarUrl != null && acc.avatarUrl!.isNotEmpty 
                    ? NetworkImage(acc.avatarUrl!) 
                    : null,
                child: acc.avatarUrl == null || acc.avatarUrl!.isEmpty ? Text(avatarChar) : null,
              ),
              title: Text(acc.displayName ?? acc.username),
              trailing: isActive ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
              onTap: () {
                if (!isActive) {
                  ref.read(accountProvider.notifier).switchAccount(acc.id);
                  context.go('/app');
                }
                Navigator.pop(context);
              },
            );
          }),
          if (accountState.accounts.length < 2) ...[
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Başka Bir Hesap Ekle'),
              onTap: () {
                Navigator.pop(context);
                context.go('/login?adding=true');
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
