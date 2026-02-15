import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // Account section
          _SectionHeader(title: 'アカウント'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('メールアドレス'),
            subtitle: Text(user?.email ?? '未設定'),
          ),

          const Divider(),

          // Display section
          _SectionHeader(title: '表示'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('テーマ'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),

          const Divider(),

          // Notification section
          _SectionHeader(title: '通知'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('プッシュ通知'),
            subtitle: const Text('更新通知を受け取る'),
            value: true,
            onChanged: (value) {
              // TODO: Implement push notification toggle
            },
          ),

          const Divider(),

          // Data section
          _SectionHeader(title: 'データ'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('データエクスポート'),
            subtitle: const Text('ブックマーク・レビューをJSON形式で出力'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('今後のバージョンで対応予定です')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('データインポート'),
            subtitle: const Text('エクスポートしたデータを読み込み'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('今後のバージョンで対応予定です')),
              );
            },
          ),

          const Divider(),

          // About section
          _SectionHeader(title: 'その他'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open terms of service
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('ライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context),
          ),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('バージョン'),
            subtitle: Text('1.0.0'),
          ),

          const Divider(),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('ログアウト'),
                    content: const Text('ログアウトしますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('ログアウト'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'システム設定に従う';
      case ThemeMode.light:
        return 'ライト';
      case ThemeMode.dark:
        return 'ダーク';
    }
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('テーマ'),
        children: ThemeMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(
                  mode == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(_themeModeLabel(mode)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
