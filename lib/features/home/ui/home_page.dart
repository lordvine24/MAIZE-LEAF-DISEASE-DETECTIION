import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/data/profile_repository.dart';
import '../../../shared/utils/local_media.dart';
import '../plant_inference_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverCameraResult();
    });
  }

  Future<void> _recoverCameraResult() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.file != null && mounted) {
        context.go(AppRoutes.scan, extra: response.file);
      } else if (response.exception != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera capture failed: ${response.exception}'),
          ),
        );
      }
    } catch (error) {
      debugPrint('[Scan] Could not recover camera result: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scans = user == null
        ? const <Map<String, dynamic>>[]
        : ref.watch(userScansProvider(user.uid)).valueOrNull ??
              const <Map<String, dynamic>>[];
    final profile = user == null
        ? null
        : ref.watch(userProfileProvider(user.uid)).valueOrNull;
    final scanCount = profile?.scanCount ?? scans.length;
    final issueCount = scans
        .where(
          (scan) =>
              scan['isMaize'] == true && scan['localDisease'] != 'Daun Sehat',
        )
        .length;
    final healthyCount = scans
        .where((scan) => scan['localDisease'] == 'Daun Sehat')
        .length;
    final displayName = user?.displayName?.trim();
    final emailName = user?.email?.split('@').first.trim();
    final userName = displayName?.isNotEmpty == true
        ? displayName!
        : emailName?.isNotEmpty == true
        ? emailName!
        : 'Grower';
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppTheme.primaryGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('ChloroScan'),
          ],
        ),
        actions: [
          // Profile Avatar
          GestureDetector(
            onTap: () => context.go('/home/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                child: ClipOval(
                  child: profile?.avatarPath != null
                      ? localImage(
                          path: profile!.avatarPath!,
                          width: 36,
                          height: 36,
                          fallback: _profileFallback(user),
                        )
                      : user?.photoURL != null
                      ? Image.network(
                          user!.photoURL!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _profileFallback(user),
                        )
                      : _profileFallback(user),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Text(
              '$timeGreeting, $userName 👋',
              style: Theme.of(context).textTheme.displayMedium,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
            const SizedBox(height: 4),
            Text(
              'What would you like to scan today?',
              style: Theme.of(context).textTheme.bodyMedium,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 28),

            // Scan Card
            _ScanCard(
              onPressed: () => context.push(AppRoutes.scan),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
            const SizedBox(height: 20),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.grass_rounded,
                    label: 'Scans',
                    value: '$scanCount',
                    color: AppTheme.primaryGreen,
                  ).animate().fadeIn(delay: 200.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.healing_rounded,
                    label: 'Recent issues',
                    value: '$issueCount',
                    color: AppTheme.warningColor,
                  ).animate().fadeIn(delay: 250.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Healthy',
                    value: '$healthyCount',
                    color: AppTheme.accentEmerald,
                  ).animate().fadeIn(delay: 300.ms),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Scans Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Scans',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.history),
                  child: const Text(
                    'See all',
                    style: TextStyle(color: AppTheme.primaryGreen),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 12),

            if (scans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No scans yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your saved results will appear here',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms)
            else
              ...scans.take(3).map((scan) => _RecentScanTile(scan: scan)),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // FAB — Scan Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.scan),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text(
          'Scan Plant',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.8, 0.8)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final Map<String, dynamic> scan;

  const _RecentScanTile({required this.scan});

  @override
  Widget build(BuildContext context) {
    final isMaize = scan['isMaize'] == true;
    final isUncertain = scan['isUncertain'] == true;
    final color = !isMaize || isUncertain
        ? AppTheme.warningColor
        : AppTheme.primaryGreen;
    final storedTitle = scan['title'] as String? ?? '';
    final localDisease = scan['localDisease'] as String? ?? '';
    final title = PlantInferenceService.englishDiseaseName(
      storedTitle.isNotEmpty
        ? storedTitle
        : localDisease.isNotEmpty
        ? localDisease
        : 'Plant scan',
    );
    final imagePath =
        scan['imagePath'] as String? ?? scan['imageUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imagePath?.isNotEmpty == true
                ? localImage(
                    path: imagePath!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    fallback: _scanFallbackIcon(color, isMaize),
                  )
                : _scanFallbackIcon(color, isMaize),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  _scanDateLabel(scan['timestamp']),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (scan['confidence'] is num)
            Text(
              '${(scan['confidence'] as num).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
        ],
      ),
    );
  }
}

Widget _profileFallback(User? user) {
  return Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    color: AppTheme.surfaceElevated,
    child: Text(
      (user?.displayName?.isNotEmpty == true)
          ? user!.displayName![0].toUpperCase()
          : '?',
      style: const TextStyle(
        color: AppTheme.primaryGreen,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _scanFallbackIcon(Color color, bool isMaize) {
  return Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    color: AppTheme.surfaceElevated,
    child: Icon(
      isMaize ? Icons.eco_outlined : Icons.image_search_outlined,
      color: color,
      size: 21,
    ),
  );
}

String _scanDateLabel(dynamic timestamp) {
  final date = timestamp is num
      ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()).toLocal()
      : DateTime.tryParse(timestamp?.toString() ?? '')?.toLocal();
  if (date == null) return 'Saved scan';
  final dateText = '${date.day}/${date.month}/${date.year}';
  final timeText =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$dateText at $timeText';
}

class _ScanCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScanCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/maize cover.jpeg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xD9000000),
                  Color(0x9A071B10),
                  Color(0x28071B10),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Scan your maize',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Check a leaf for common maize diseases.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Start scan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.deepGreen,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
