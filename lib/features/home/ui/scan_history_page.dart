import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/data/profile_repository.dart';
import '../../../shared/utils/local_media.dart';
import '../plant_inference_service.dart';

class ScanHistoryPage extends ConsumerWidget {
  const ScanHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final history = user == null
        ? null
        : ref.watch(userScansProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan history'),
        actions: [
          IconButton(
            tooltip: 'New scan',
            onPressed: () => context.push(AppRoutes.scan),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: history == null
          ? const _HistoryMessage(
              icon: Icons.person_outline_rounded,
              message: 'Sign in to view your scan history.',
            )
          : history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _HistoryMessage(
                icon: Icons.cloud_off_outlined,
                message: 'Could not load scan history: $error',
              ),
              data: (scans) => scans.isEmpty
                  ? const _HistoryMessage(
                      icon: Icons.document_scanner_outlined,
                      message: 'Your completed scans will appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: scans.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _HistoryEntry(scan: scans[index]),
                    ),
            ),
    );
  }
}

class _HistoryEntry extends ConsumerStatefulWidget {
  final Map<String, dynamic> scan;

  const _HistoryEntry({required this.scan});

  @override
  ConsumerState<_HistoryEntry> createState() => _HistoryEntryState();
}

class _HistoryEntryState extends ConsumerState<_HistoryEntry> {
  bool _isDeleting = false;

  Future<void> _deleteScan(String? uid) async {
    final scan = widget.scan;
    final scanId = scan['id']?.toString();
    if (uid == null || scanId == null || scanId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete scan?'),
        content: const Text(
          'This removes this scan from your history and deletes its photo from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .deleteScanResult(uid: uid, scanId: scanId);
      final imagePath = scan['imagePath']?.toString();
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          await deleteLocalImage(imagePath);
        } catch (error) {
          debugPrint('[History] Could not delete local scan image: $error');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Scan deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete scan: $error')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final user = ref.watch(currentUserProvider);
    final isMaize = scan['isMaize'] == true;
    final isUncertain = scan['isUncertain'] == true;
    final color = !isMaize || isUncertain
        ? AppTheme.warningColor
        : AppTheme.primaryGreen;
    final localDisease = scan['localDisease']?.toString() ?? '';
    final storedTitle = scan['title']?.toString() ?? '';
    final title = PlantInferenceService.englishDiseaseName(
      storedTitle.isNotEmpty
        ? storedTitle
        : localDisease.isNotEmpty
        ? localDisease
        : 'Plant scan',
    );
    final score = scan['maizeScore'];
    final imagePath =
        scan['imagePath']?.toString() ?? scan['imageUrl']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imagePath?.isNotEmpty == true
                ? localImage(
                    path: imagePath!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallback: _historyFallback(color, isMaize),
                  )
                : _historyFallback(color, isMaize),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  scan['status']?.toString() ?? 'Scan completed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(scan['timestamp']),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (score is num) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Model 1 score: ${score.toStringAsFixed(3)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (scan['confidence'] is num)
            Text(
              '${(scan['confidence'] as num).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          IconButton(
            tooltip: 'Delete scan',
            onPressed: _isDeleting ? null : () => _deleteScan(user?.uid),
            icon: _isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            color: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }
}

Widget _historyFallback(Color color, bool isMaize) {
  return Container(
    width: 64,
    height: 64,
    alignment: Alignment.center,
    color: AppTheme.surfaceElevated,
    child: Icon(
      isMaize ? Icons.eco_outlined : Icons.image_search_outlined,
      color: color,
      size: 22,
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HistoryMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(dynamic timestamp) {
  final date = timestamp is num
      ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()).toLocal()
      : DateTime.tryParse(timestamp?.toString() ?? '')?.toLocal();
  if (date == null) return 'Time unavailable';
  final dateText = '${date.day}/${date.month}/${date.year}';
  final timeText =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$dateText at $timeText';
}
