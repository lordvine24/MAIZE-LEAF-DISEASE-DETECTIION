import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/local_media.dart';
import '../../profile/data/profile_repository.dart';
import '../plant_inference_service.dart';
import 'leaf_crop_page.dart';

class ScanPage extends ConsumerStatefulWidget {
  final XFile? initialImage;
  const ScanPage({super.key, this.initialImage});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with SingleTickerProviderStateMixin {
  final _imagePicker = ImagePicker();
  final _flutterTts = FlutterTts();
  XFile? _selectedImage;
  String? _localImagePath;
  Uint8List? _imageBytes;
  PlantInferenceResult? _result;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _isSpeaking = false;
  bool _wasSaved = false;
  ImageSource? _imageSource;
  String? _saveError;
  String? _speechError;
  String? _pageError;
  String _progressMessage = 'Analyzing photo...';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _speechError = 'Could not read the scan result aloud: $message';
      });
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    final image = widget.initialImage;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreInitialImage(image);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_flutterTts.stop());
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _readResultAloud() async {
    if (_isSpeaking) {
      try {
        await _flutterTts.stop();
      } catch (error) {
        if (mounted) {
          setState(
            () => _speechError = 'Could not stop speech playback: $error',
          );
        }
      } finally {
        if (mounted) setState(() => _isSpeaking = false);
      }
      return;
    }

    final result = _result;
    if (result == null) return;

    setState(() {
      _isSpeaking = true;
      _speechError = null;
    });
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(_spokenResult(result));
      if (mounted) setState(() => _isSpeaking = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _speechError = 'Could not read the scan result aloud: $error';
      });
    }
  }

  String _spokenResult(PlantInferenceResult result) {
    final sections = <String>[
      'Scan result: ${result.title}.',
      if (result.localDisease.isNotEmpty)
        'Confidence: ${result.confidence.toStringAsFixed(1)} percent.',
      if (result.guidance.isNotEmpty) 'Guidance: ${result.guidance}',
      if (result.symptoms.isNotEmpty)
        'Symptoms to look for: ${result.symptoms}',
      if (result.advice case final advice?)
        'Recommended next steps. Treatment: ${advice.product} '
            'Application: ${advice.application} '
            'Other steps: ${advice.otherSteps} '
            'Safety: ${advice.safety}',
    ];
    return sections.join(' ');
  }

  Future<void> _restoreInitialImage(XFile image) async {
    try {
      final croppedImage = await _cropSelectedImage(image);
      if (croppedImage != null) {
        await _adoptImage(croppedImage, ImageSource.camera);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _pageError = 'Could not recover camera photo: $error');
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    if (kIsWeb) {
      setState(() {
        _pageError =
            'On-device model scanning requires an Android or iOS device.';
      });
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null) return;
      final croppedImage = await _cropSelectedImage(image);
      if (croppedImage != null) await _adoptImage(croppedImage, source);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pageError = 'Could not open that image: $error');
    }
  }

  Future<XFile?> _cropSelectedImage(XFile image) async {
    final bytes = await image.readAsBytes();
    if (!mounted) return null;
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (_) => LeafCropPage(imageBytes: bytes),
      ),
    );
    if (croppedBytes == null) return null;

    final baseName = image.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return XFile.fromData(
      croppedBytes,
      name: '${baseName}_leaf.jpg',
      mimeType: 'image/jpeg',
    );
  }

  Future<void> _adoptImage(XFile image, ImageSource source) async {
    final bytes = await image.readAsBytes();
    final safeName = image.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final localPath = await saveImageLocally(
      folder: 'scan_captures',
      filename: '${DateTime.now().microsecondsSinceEpoch}_$safeName',
      bytes: bytes,
    );
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _localImagePath = localPath;
      _imageBytes = bytes;
      _imageSource = source;
      _result = null;
      _isSaving = false;
      _wasSaved = false;
      _saveError = null;
      _pageError = null;
    });
  }

  Future<void> _analyzeImage() async {
    final image = _selectedImage;
    final imageBytes = _imageBytes;
    if (image == null || imageBytes == null || _isAnalyzing || _isSaving) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _pageError = null;
      _progressMessage = 'Checking whether this is maize...';
    });

    final PlantInferenceResult result;
    try {
      result = await ref
          .read(plantInferenceServiceProvider)
          .classify(imageBytes);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageError = 'Could not analyze this image: $error';
        _isAnalyzing = false;
      });
      debugPrint('[Scan] Inference failed: $error');
      return;
    }

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
        _isSaving = true;
        _progressMessage = 'Saving scan to your history...';
      });
    }

    var wasSaved = false;
    String? saveError;
    final saveTimer = Stopwatch()..start();
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        saveError = 'Sign in to save this scan.';
      } else {
        final profileRepository = ref.read(profileRepositoryProvider);
        final scanId = profileRepository.createScanId(user.uid);
        final localImagePath = _localImagePath;
        if (localImagePath == null) {
          throw StateError('The selected image is not saved on this device.');
        }
        await profileRepository.saveScanResult(
          uid: user.uid,
          scanId: scanId,
          scanData: {
            'isMaize': result.isMaize,
            'isUncertain': result.isUncertain,
            'stage': result.stage,
            'status': result.status,
            'title': result.title,
            'localDisease': result.localDisease,
            'symptoms': result.symptoms,
            'confidence': result.confidence,
            'maizeScore': result.maizeScore,
            'maizeThreshold': result.maizeThreshold,
            'guidance': result.guidance,
            if (result.advice != null) 'advice': result.advice!.toMap(),
            'imagePath': localImagePath,
            'imageName': image.name,
            'source': _imageSource == ImageSource.camera ? 'camera' : 'gallery',
          },
        );
        wasSaved = true;
      }
    } catch (error) {
      saveError = error.toString();
      debugPrint('[Scan] Could not save scan result: $error');
    } finally {
      saveTimer.stop();
      if (kDebugMode) {
        debugPrint(
          '[Scan timing] History save: ${saveTimer.elapsedMilliseconds} ms',
        );
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
          _wasSaved = wasSaved;
          _saveError = saveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;
    final result = _result;
    final resultColor = result == null
        ? AppTheme.primaryGreen
        : !result.isMaize || result.isUncertain
        ? AppTheme.warningColor
        : AppTheme.primaryGreen;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        title: const Text('Plant Scan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'New Diagnosis',
                style: Theme.of(context).textTheme.displayMedium,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
              const SizedBox(height: 4),
              Text(
                'After taking a photo, crop the frame around one maize leaf before scanning.',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 20),

              // Image Preview Area
              _ImagePreviewArea(
                imageBytes: imageBytes,
                isAnalyzing: _isAnalyzing,
                pulseController: _pulseController,
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 14),

              // Image Source Buttons
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onPressed: _isAnalyzing || _isSaving
                          ? null
                          : () => _selectImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onPressed: _isAnalyzing || _isSaving
                          ? null
                          : () => _selectImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              if (_pageError != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(
                  message: _pageError!,
                ).animate().fadeIn().shake(hz: 3, offset: const Offset(4, 0)),
              ],

              if (imageBytes != null) ...[
                const SizedBox(height: 16),
                _AnalyzeButton(
                  isAnalyzing: _isAnalyzing || _isSaving,
                  progressMessage: _progressMessage,
                  onPressed: _analyzeImage,
                ).animate().fadeIn(delay: 250.ms),
              ],

              if (result != null) ...[
                const SizedBox(height: 24),
                _ScanResultPanel(
                  result: result,
                  color: resultColor,
                  wasSaved: _wasSaved,
                  saveError: _saveError,
                  isSpeaking: _isSpeaking,
                  speechError: _speechError,
                  onSpeechTap: _readResultAloud,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image Preview Area ───────────────────────────────────────────────────────
class _ImagePreviewArea extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool isAnalyzing;
  final AnimationController pulseController;

  const _ImagePreviewArea({
    required this.imageBytes,
    required this.isAnalyzing,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final glowOpacity = isAnalyzing
            ? 0.15 + 0.2 * pulseController.value
            : 0.0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isAnalyzing
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(
                        alpha: glowOpacity,
                      ),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: imageBytes == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        border: Border.all(
                          color: AppTheme.borderColor,
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.borderGreen),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Select a leaf photo',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera or Gallery',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(imageBytes!, fit: BoxFit.contain),
                        if (isAnalyzing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryGreen,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Analyzing...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

// ── Source Button ────────────────────────────────────────────────────────────
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SourceButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: onPressed == null
                  ? AppTheme.textMuted
                  : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: onPressed == null
                    ? AppTheme.textMuted
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analyze Button ───────────────────────────────────────────────────────────
class _AnalyzeButton extends StatelessWidget {
  final bool isAnalyzing;
  final String progressMessage;
  final VoidCallback onPressed;

  const _AnalyzeButton({
    required this.isAnalyzing,
    required this.progressMessage,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAnalyzing ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isAnalyzing
              ? const LinearGradient(
                  colors: [AppTheme.surfaceElevated, AppTheme.surfaceElevated],
                )
              : AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isAnalyzing ? null : AppTheme.greenGlow(intensity: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAnalyzing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                ),
              )
            else
              const Icon(
                Icons.document_scanner_outlined,
                color: Colors.black,
                size: 20,
              ),
            const SizedBox(width: 10),
            Text(
              isAnalyzing ? progressMessage : 'Analyze Photo',
              style: TextStyle(
                color: isAnalyzing ? AppTheme.textSecondary : Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan Result Panel ────────────────────────────────────────────────────────
class _ScanResultPanel extends StatelessWidget {
  final PlantInferenceResult result;
  final Color color;
  final bool wasSaved;
  final String? saveError;
  final bool isSpeaking;
  final String? speechError;
  final VoidCallback onSpeechTap;

  const _ScanResultPanel({
    required this.result,
    required this.color,
    required this.wasSaved,
    required this.saveError,
    required this.isSpeaking,
    required this.speechError,
    required this.onSpeechTap,
  });

  @override
  Widget build(BuildContext context) {
    final stageLabel = result.stage == 1
        ? 'STAGE 1  ·  MAIZE GATEKEEPER'
        : 'STAGE 2  ·  DISEASE CLASSIFIER';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    result.isMaize
                        ? Icons.eco_rounded
                        : Icons.image_search_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSpeechTap,
                    icon: Icon(
                      isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    ),
                    label: Text(
                      isSpeaking ? 'Stop reading' : 'Read result aloud',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
                if (speechError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    speechError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.errorColor),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  result.status,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${result.maizeScore.toStringAsFixed(3)}  ·  Cutoff: ${result.maizeThreshold.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),

                // Confidence bar
                if (result.localDisease.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Confidence',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${result.confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (result.confidence / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  result.guidance,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                if (result.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.isUncertain
                              ? 'Possible symptoms'
                              : 'Symptoms to look for',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          result.symptoms,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],

                if (result.advice case final advice?) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Recommended next steps',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _AdviceItem(title: 'Treatment', text: advice.product),
                  _AdviceItem(title: 'Application', text: advice.application),
                  _AdviceItem(title: 'Other steps', text: advice.otherSteps),
                  _AdviceItem(title: 'Safety', text: advice.safety),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: wasSaved
                        ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                        : AppTheme.warningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: wasSaved
                          ? AppTheme.primaryGreen.withValues(alpha: 0.25)
                          : AppTheme.warningColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        wasSaved
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: wasSaved
                            ? AppTheme.primaryGreen
                            : AppTheme.warningColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wasSaved
                              ? 'Saved to your scan history'
                              : saveError == null
                              ? 'Saving to your scan history...'
                              : 'Could not save scan: $saveError',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
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

class _AdviceItem extends StatelessWidget {
  final String title;
  final String text;
  const _AdviceItem({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
