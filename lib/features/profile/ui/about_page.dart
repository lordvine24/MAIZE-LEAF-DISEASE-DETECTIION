import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: CustomScrollView(
        slivers: [
          // ── Hero Sliver App Bar ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.surfaceDark,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/maize cover.jpeg',
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x40000000), Color(0xDD080D10)],
                        stops: [0.3, 1.0],
                      ),
                    ),
                  ),
                  // Hero content
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.greenGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CHLOROSCAN',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'AI-powered maize\nleaf diagnosis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smarter farming, one leaf at a time.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body Content ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Mission statement
                _MissionCard()
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 28),

                // How to use section
                Text(
                  'How to use',
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 14),
                ..._howToSteps.asMap().entries.map(
                  (entry) =>
                      Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GuideStep(
                              number: '0${entry.key + 1}',
                              icon: entry.value['icon'] as IconData,
                              title: entry.value['title'] as String,
                              detail: entry.value['detail'] as String,
                            ),
                          )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 220 + entry.key * 60),
                          )
                          .slideX(begin: 0.05),
                ),
                const SizedBox(height: 28),

                // Conditions screened
                Text(
                  'Conditions screened',
                  style: Theme.of(context).textTheme.titleLarge,
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 14),
                ..._conditions.asMap().entries.map(
                  (entry) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConditionCard(
                          color: entry.value['color'] as Color,
                          icon: entry.value['icon'] as IconData,
                          title: entry.value['title'] as String,
                          detail: entry.value['detail'] as String,
                        ),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: 470 + entry.key * 60),
                      ),
                ),
                const SizedBox(height: 28),

                // Disclaimer
                _DisclaimerCard().animate().fadeIn(delay: 650.ms),
                const SizedBox(height: 24),

                // CTA
                _CtaButton(onTap: () => context.push(AppRoutes.scan))
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: 32),

                // About / Author
                _AuthorTile().animate().fadeIn(delay: 750.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data ───────────────────────────────────────────────────────────────────
const _howToSteps = [
  {
    'icon': Icons.add_a_photo_outlined,
    'title': 'Choose a leaf photo',
    'detail':
        'Tap Scan Plant, then take a photo or select one from your gallery.',
  },
  {
    'icon': Icons.crop,
    'title': 'Crop to one leaf',
    'detail':
        'After taking a photo, adjust the crop frame around one maize leaf. Use good light and avoid blur or glare.',
  },
  {
    'icon': Icons.document_scanner_outlined,
    'title': 'Review the result',
    'detail':
        'Tap Analyze. Review the predicted condition and confidence score before acting.',
  },
  {
    'icon': Icons.history_rounded,
    'title': 'Keep your scans',
    'detail':
        'Sign in to save results to Scan History, where you can revisit or delete them later.',
  },
];

const _conditions = [
  {
    'color': AppTheme.warningColor,
    'icon': Icons.blur_on_rounded,
    'title': 'Gray Leaf Spot',
    'detail': 'Fungal disease — rectangular gray spots on lower leaves',
  },
  {
    'color': AppTheme.primaryGreen,
    'icon': Icons.eco_rounded,
    'title': 'Healthy Leaf',
    'detail': 'No listed disease detected — keep monitoring the crop',
  },
  {
    'color': AppTheme.errorColor,
    'icon': Icons.sick_outlined,
    'title': 'Northern Corn Leaf Blight',
    'detail': 'Fungal blight — cigar-shaped gray-green lesions',
  },
  {
    'color': AppTheme.accentEmerald,
    'icon': Icons.filter_vintage_outlined,
    'title': 'Maize Rust',
    'detail': 'Rust disease — orange-brown powdery pustules',
  },
];

// ── Mission Card ───────────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGreen),
        boxShadow: AppTheme.greenGlow(intensity: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Our Mission',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'ChloroScan screens a maize leaf photo and suggests which of four common conditions it most resembles — helping farmers catch problems early.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guide Step ─────────────────────────────────────────────────────────────
class _GuideStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String detail;

  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.greenGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Condition Card ─────────────────────────────────────────────────────────
class _ConditionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String detail;

  const _ConditionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          // Color dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

// ── Disclaimer ─────────────────────────────────────────────────────────────
class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.06),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.warningColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important disclaimer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.warningColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A scan is an image-based screening, not a confirmed diagnosis. If symptoms persist or spread, consult a local agricultural expert before treatment. Always follow product labels.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.5,
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

// ── CTA Button ─────────────────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.greenGlow(intensity: 0.8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              color: Colors.black,
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Start a scan now',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Author ──────────────────────────────────────────────────────────────────
class _AuthorTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.greenGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'L',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lordvine Okoth',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Developer & Researcher',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text('v1.0.0', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
