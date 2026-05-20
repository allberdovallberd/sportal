import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/sportal_background.dart';
import '../../ui/widgets/sportal_primary_button.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _imageOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _imageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
      ),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _contentOffset =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.36, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final ratio = width / height;
          final zoom = _responsiveZoom(width: width, ratio: ratio);
          final imageAlignment = _responsiveAlignment(
            width: width,
            ratio: ratio,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              const SportalBackground(child: SizedBox.shrink()),
              FadeTransition(
                opacity: _imageOpacity,
                child: Transform.scale(
                  scale: zoom,
                  child: Image.asset(
                    'assets/images/hoshgeldiniz_bg_image.png',
                    fit: BoxFit.cover,
                    alignment: imageAlignment,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x20000000),
                      Color(0x4A000000),
                      Color(0x76000000),
                      Color(0xA2000000),
                      Color(0xCC000000),
                      Color(0xF2000000),
                    ],
                    stops: [0.36, 0.47, 0.60, 0.72, 0.84, 0.93, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 34),
                  child: FadeTransition(
                    opacity: _contentOpacity,
                    child: SlideTransition(
                      position: _contentOffset,
                      child: Column(
                        children: [
                          const Spacer(),
                          Text(
                            l10n.t('onboardingTitle'),
                            style: SportalTextStyles.h1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('onboardingSubtitle'),
                            style: SportalTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          SportalPrimaryButton(
                            label: l10n.t('commonContinue'),
                            enabled: true,
                            onPressed: () => context.go('/login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _responsiveZoom({required double width, required double ratio}) {
    final isTablet = width >= 600;

    // Keep phone framing almost unchanged, but add stronger crop on large
    // screens so image edge/corner artifacts never become visible.
    if (!isTablet) {
      return ratio < 0.50 ? 1.48 : 1.44;
    }

    if (ratio > 0.90) {
      return 1.95;
    }
    if (ratio > 0.72) {
      return 1.82;
    }
    if (ratio > 0.58) {
      return 1.72;
    }
    return 1.62;
  }

  Alignment _responsiveAlignment({
    required double width,
    required double ratio,
  }) {
    final isTablet = width >= 600;
    if (!isTablet) {
      return const Alignment(0.06, -0.05);
    }
    if (ratio > 0.78) {
      return const Alignment(0.12, -0.08);
    }
    return const Alignment(0.08, -0.06);
  }
}
