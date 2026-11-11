import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/profile_repository.dart';
import '../../../shared/utils/local_media.dart';
import '../../auth/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isBusy = false;
  String? _loadedProfileUid;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _isBusy = true);

    try {
      final bytes = await picked.readAsBytes();
      final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final avatarPath = await saveImageLocally(
        folder: 'avatars',
        filename: '${DateTime.now().microsecondsSinceEpoch}_$safeName',
        bytes: bytes,
      );
      await ref.read(profileRepositoryProvider).updateProfile(user.uid, {
        'avatarPath': avatarPath,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      await user.updateDisplayName(name);
      await ref.read(profileRepositoryProvider).updateProfile(user.uid, {
        'name': name,
        'email': user.email ?? '',
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details saved.')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $error')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = user == null
        ? null
        : ref.watch(userProfileProvider(user.uid)).valueOrNull;
    if (user != null && _loadedProfileUid != user.uid) {
      _loadedProfileUid = user.uid;
      _nameController.text = profile?.name ?? user.displayName ?? '';
      _locationController.text = profile?.location ?? '';
      _phoneController.text = profile?.phone ?? '';
    } else if (user != null &&
        profile != null &&
        _nameController.text.isEmpty) {
      _nameController.text = profile.name;
      _locationController.text = profile.location;
      _phoneController.text = profile.phone;
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Profile'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Profile Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  border: const Border(
                    bottom: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar with glowing ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.greenGlow(intensity: 0.6),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: AppTheme.surfaceElevated,
                            child: ClipOval(
                              child: profile?.avatarPath != null
                                  ? localImage(
                                      path: profile!.avatarPath!,
                                      width: 108,
                                      height: 108,
                                      fit: BoxFit.cover,
                                      fallback: _defaultAvatar(user),
                                    )
                                  : user?.photoURL != null
                                  ? Image.network(
                                      user!.photoURL!,
                                      width: 108,
                                      height: 108,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _defaultAvatar(user),
                                    )
                                  : _defaultAvatar(user),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isBusy ? null : _pickAndUploadAvatar,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppTheme.greenGradient,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.surfaceDark,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              color: Colors.black,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).scale(),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : 'Your profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              // ── Form ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ProfileField(
                      controller: _nameController,
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                      onChanged: (_) => setState(() {}),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _locationController,
                      label: 'Location',
                      icon: Icons.location_on_outlined,
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _phoneController,
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),

                    // Save Button
                    AppButton(
                      label: _isBusy ? 'Saving...' : 'Save changes',
                      isLoading: _isBusy,
                      icon: Icons.check_rounded,
                      onPressed: _isBusy ? null : _saveProfile,
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Settings tiles
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About ChloroScan',
                      onTap: () => context.push(AppRoutes.about),
                    ).animate().fadeIn(delay: 300.ms),

                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Account type',
                      subtitle: user?.providerData.any(
                                (p) => p.providerId == 'google.com',
                              ) ==
                              true
                          ? 'Google'
                          : 'Email / Password',
                    ).animate().fadeIn(delay: 350.ms),

                    const SizedBox(height: 20),

                    // Sign Out
                    GestureDetector(
                      onTap: _isBusy ? null : _signOut,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: AppTheme.errorColor,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar(user) {
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: Text(
        (user?.displayName?.isNotEmpty == true)
            ? user!.displayName![0].toUpperCase()
            : '?',
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
