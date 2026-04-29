import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../models/user_data.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final ImagePicker _picker = ImagePicker();

  Future<void> _changePicture() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final success = await ref.read(authProvider.notifier).updateProfile(imagePath: image.path);
      if (success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
      }
    }
  }

  Future<void> _toggleBiometrics(String type, bool enabled) async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();

      if (!(canCheckBiometrics || isDeviceSupported)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics not available on this device')),
          );
        }
        return;
      }

      if (enabled) {
        bool authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication failed. Biometrics not enabled.')),
            );
          }
          return;
        }
      }

      final success = await ref.read(authProvider.notifier).toggleBiometric(type, enabled);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(enabled ? 'Biometrics enabled successfully' : 'Biometrics disabled')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showChangePinDialog() {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Transaction PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: currentPinController,
              decoration: const InputDecoration(labelText: 'Current PIN', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(labelText: 'New PIN', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final success = await ref.read(authProvider.notifier).changePin(
                  currentPinController.text,
                  newPinController.text,
                );
                if (success) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN changed successfully')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Update PIN', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Login Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final success = await ref.read(authProvider.notifier).changePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
                if (success) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Update Password', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action is permanent and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final authNotifier = ref.read(authProvider.notifier);
              await authNotifier.deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFF041f62), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B), fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildMinimalHeader(user),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('PERSONAL INFO'),
                      const SizedBox(height: 12),
                      _buildMinimalContainer([
                        _SettingsItem(
                          icon: Icons.person_outline_rounded,
                          title: user?.fullname ?? 'Full Name',
                          subtitle: 'Full Name',
                          onTap: () {},
                        ),
                        const _MinimalDivider(),
                        _SettingsItem(
                          icon: Icons.alternate_email_rounded,
                          title: user?.email ?? 'Email Address',
                          subtitle: 'Email',
                          onTap: () {},
                        ),
                      ]),
                      const SizedBox(height: 32),
                      _buildSectionLabel('REFERRAL PROGRAM'),
                      const SizedBox(height: 12),
                      _buildMinimalContainer([
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF041f62), size: 18),
                          ),
                          title: Text(
                            user?.referral?.code ?? '---',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B), letterSpacing: 2),
                          ),
                          subtitle: const Text('Your Referral Code', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF041f62)),
                                onPressed: () {
                                  if (user?.referral?.code != null) {
                                    Clipboard.setData(ClipboardData(text: user!.referral!.code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Referral code copied to clipboard')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const _MinimalDivider(),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildReferralStat('Total Referrals', '${user?.referral?.totalReferrals ?? 0}'),
                              Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
                              _buildReferralStat('Total Earned', '₦${user?.referral?.totalEarned ?? 0}'),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 32),
                      _buildSectionLabel('SECURITY'),
                      const SizedBox(height: 12),
                      _buildMinimalContainer([
                        _ToggleTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric Login',
                          subtitle: 'Fingerprint unlock',
                          value: authState.loginBioEnabled,
                          isLoading: authState.isLoginBioLoading,
                          onChanged: (val) => _toggleBiometrics('login', val),
                        ),
                        const _MinimalDivider(),
                        _ToggleTile(
                          icon: Icons.shield_outlined,
                          title: 'Biometric Payments',
                          subtitle: 'Transaction authorization',
                          value: authState.transBioEnabled,
                          isLoading: authState.isTransBioLoading,
                          onChanged: (val) => _toggleBiometrics('transaction', val),
                        ),
                        const _MinimalDivider(),
                        _SettingsItem(
                          icon: Icons.lock_outline_rounded,
                          title: 'Change Transaction PIN',
                          onTap: _showChangePinDialog,
                        ),
                        const _MinimalDivider(),
                        _SettingsItem(
                          icon: Icons.password_rounded,
                          title: 'Change Password',
                          onTap: _showChangePasswordDialog,
                        ),
                      ]),
                      const SizedBox(height: 32),
                      _buildSectionLabel('SYSTEM'),
                      const SizedBox(height: 12),
                      _buildMinimalContainer([
                        _SettingsItem(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          titleColor: Colors.orange[800],
                          onTap: _showLogoutConfirmation,
                        ),
                        const _MinimalDivider(),
                        _SettingsItem(
                          icon: Icons.delete_outline_rounded,
                          title: 'Delete Account',
                          titleColor: Colors.red[700],
                          onTap: _confirmDeleteAccount,
                        ),
                      ]),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalHeader(User? user) {
    return Column(
      children: [
        _buildAvatar(user),
        const SizedBox(height: 16),
        Text(
          user?.fullname ?? 'User Name',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF041f62).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user?.tier ?? 'BASIC',
                style: const TextStyle(color: Color(0xFF041f62), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
            if (user?.isVerified == true) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded, color: Colors.green, size: 16),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMinimalContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAvatar(User? user) {
    return Stack(
      children: [
        UserAvatar(
          name: user?.fullname ?? 'User',
          imageUrl: user?.picture,
          radius: 50,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _changePicture,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF041f62),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MinimalDivider extends StatelessWidget {
  const _MinimalDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56, endIndent: 16);
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Icon(icon, color: const Color(0xFF041f62), size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
      trailing: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF041f62)),
            )
          : Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF041f62),
                activeTrackColor: const Color(0xFF041f62).withOpacity(0.2),
              ),
            ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Icon(icon, color: titleColor ?? const Color(0xFF041f62), size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: titleColor ?? const Color(0xFF1E293B),
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
    );
  }
}
