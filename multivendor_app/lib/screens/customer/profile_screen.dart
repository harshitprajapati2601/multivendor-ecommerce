import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/edit_profile_sheet.dart';
import '../../widgets/logout_dialog.dart';
import '../../widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final profile = auth.userProfile;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const AvatarPicker(radius: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName ?? auth.fullName ?? 'Customer',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.email ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                                const SizedBox(width: 4),
                                Text(
                                  profile.phoneNumber!,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile Details'),
                    onPressed: () => EditProfileSheet.show(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Appearance & Preferences Section
          Text('Preferences', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Material(
            color: theme.cardTheme.color,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Column(

              children: [
                SwitchListTile.adaptive(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text('Dark Theme', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleTheme(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Logout Button

          PrimaryButton(
            label: 'Log Out',
            icon: Icons.logout_rounded,
            outlined: true,
            color: AppColors.danger,
            isLoading: auth.isLoading,
            onPressed: () async {
              final confirm = await LogoutDialog.show(context);
              if (confirm && context.mounted) {
                auth.logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
