import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yack/data/models/OnboardingData.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      icon: Icons.edit_note_outlined,
      titleKey: 'onboarding_create_contracts_title',
      subtitleKey: 'onboarding_create_contracts_subtitle',
      color: AppTheme.yackGreen,
    ),
    OnboardingPage(
      icon: Icons.qr_code_2_outlined,
      titleKey: 'onboarding_secure_verified_title',
      subtitleKey: 'onboarding_secure_verified_subtitle',
      color: AppTheme.yackBrass,
    ),
    OnboardingPage(
      icon: Icons.fact_check_outlined,
      titleKey: 'onboarding_track_agreements_title',
      subtitleKey: 'onboarding_track_agreements_subtitle',
      color: AppTheme.statusBlue,
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  Future<void> _goTo(String route) async {
    await Hive.box('user').put('didFirstTime', true);
    if (mounted) Navigator.pushReplacementNamed(context, route);
  }

  void _next() {
    if (_isLast) {
      _goTo('/signup');
      return;
    }
    _pageController.nextPage(duration: AppTheme.slow, curve: AppTheme.ease);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const YackBrand(),
                  const Spacer(),
                  HrefWidget(
                    text: TranslationHandler.get('login'),
                    onClick: () => _goTo('/login'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => Semantics(
                  label: TranslationHandler.resolve(
                    'page_count',
                    params: {
                      'current': '${index + 1}',
                      'total': '${_pages.length}',
                    },
                  ),
                  child: _OnboardingPageView(page: _pages[index], index: index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => Expanded(
                          child: AnimatedContainer(
                            duration: AppTheme.normal,
                            height: 3,
                            margin: EdgeInsetsDirectional.only(
                              end: index == _pages.length - 1 ? 0 : 6,
                            ),
                            color: index <= _currentPage
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PrimaryActionButton(
                      action: TranslationHandler.get(
                        _isLast ? 'get_started' : 'next',
                      ),
                      icon: Icons.arrow_forward,
                      onClick: _next,
                    ),
                    if (!_isLast)
                      TextButton(
                        onPressed: () => _goTo('/signup'),
                        child: Text(TranslationHandler.get('skip')),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;
  final int index;

  const _OnboardingPageView({required this.page, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 230,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: _WorkflowPreview(index: index, color: page.color),
              ),
              const SizedBox(height: 30),
              Text(
                TranslationHandler.get(page.titleKey),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                TranslationHandler.get(page.subtitleKey),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowPreview extends StatelessWidget {
  final int index;
  final Color color;

  const _WorkflowPreview({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = switch (index) {
      0 => Icons.edit_note_outlined,
      1 => Icons.qr_code_2_outlined,
      _ => Icons.fact_check_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Container(
              width: 72,
              height: 24,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Container(height: 14, width: 190, color: colors.onSurface),
        const SizedBox(height: 14),
        Container(height: 8, color: colors.outlineVariant),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: .72,
          child: Container(height: 8, color: colors.outlineVariant),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  border: BorderDirectional(
                    start: BorderSide(color: color, width: 3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward, color: color),
          ],
        ),
      ],
    );
  }
}
