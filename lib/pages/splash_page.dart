import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // AppStartupHelper, globalSessionCheckFuture

class SplashPage extends StatefulWidget {
  final Stopwatch stopwatch;
  const SplashPage({super.key, required this.stopwatch});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // ---------- Assets ----------
  static const String _logoAsset = 'assets/splash/splash_logo.png';

  // ---------- Brand palette ----------
  static const Color _bgLight = Color(
    0xFFF4F8FF,
  ); // must match native splash colour
  static const Color _bgDark = Color(
    0xFF1A1A1A,
  ); // must match native splash dark colour
  static const Color _navy = Color(0xFF084088);
  static const Color _sky = Color(0xFF0090D8);

  // ---------- Timing ----------
  static const int _minVisibleMs = 1200; // keep short = fast app feel
  static const int _tapSkipAfterMs = 600;
  static const int _fadeOutMs = 200;

  late final AnimationController _intro; // fades in bar + background accents
  late final AnimationController _pulse; // slow "breathing" glow behind logo

  bool _started = false;
  bool _sessionReady = false;
  bool _navigated = false;
  bool _isFadingOut = false;
  double _target = 0.0; // real progress target (0..1)

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Real signal: flips when the session check really finishes.
    globalSessionCheckFuture.then(
      (_) {
        _sessionReady = true;
      },
      onError: (Object _) {
        _sessionReady = true; // never block the app because of an error
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Decode the logo BEFORE we start, so the first Flutter frame already
    // shows it (no flicker after the native splash).
    precacheImage(const AssetImage(_logoAsset), context).whenComplete(() {
      if (!mounted) return;
      _intro.forward();
      if (!MediaQuery.of(context).disableAnimations) {
        _pulse.repeat(reverse: true);
      }
      _setTarget(0.30);
      _progressLoop();
    });
  }

  // ---------- Progress logic ----------

  void _setTarget(double v) {
    if (!mounted || v <= _target) return; // only ever moves forward
    setState(() => _target = v.clamp(0.0, 1.0));
  }

  Future<void> _progressLoop() async {
    while (mounted && !_navigated && !_isFadingOut) {
      final elapsed = widget.stopwatch.elapsedMilliseconds;

      if (_sessionReady && elapsed >= _minVisibleMs) {
        _setTarget(1.0);
        await Future.delayed(
          const Duration(milliseconds: 450),
        ); // let bar finish
        if (mounted) _fadeOutAndNavigate();
        return;
      }

      // Eases 30% -> 95% by the minimum time; holds at 90% until the
      // session check truly completes.
      final base = 0.30 + math.min(elapsed / _minVisibleMs, 1.0) * 0.65;
      _setTarget(_sessionReady ? base : math.min(base, 0.90));
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  // ---------- Interaction & navigation ----------

  void _onTap() {
    if (widget.stopwatch.elapsedMilliseconds > _tapSkipAfterMs) {
      _fadeOutAndNavigate();
    }
  }

  void _fadeOutAndNavigate() {
    if (_navigated || _isFadingOut) return;
    setState(() {
      _isFadingOut = true;
      _target = 1.0;
    });
    Future.delayed(const Duration(milliseconds: _fadeOutMs), () {
      if (mounted) _navigateToMainApp();
    });
  }

  void _navigateToMainApp() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppStartupHelper(stopwatch: widget.stopwatch),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ---------- UI ----------

  Color _a(Color c, double opacity) =>
      c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

  String _statusFor(double v) {
    if (v < 0.45) return 'Getting things ready';
    if (v < 0.92) return 'Checking your session';
    return 'Welcome back';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentBg = Theme.of(context).scaffoldBackgroundColor;
    final statusIconBrightness =
        isDarkMode ? Brightness.light : Brightness.dark;
    final statusBrightness = isDarkMode ? Brightness.dark : Brightness.light;

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIconBrightness,
          statusBarBrightness: statusBrightness,
          systemNavigationBarColor: currentBg,
          systemNavigationBarIconBrightness: statusIconBrightness,
        ),
        child: Scaffold(
          backgroundColor: currentBg,
          body: GestureDetector(
            onTap: _onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              opacity: _isFadingOut ? 0.0 : 1.0,
              duration: const Duration(milliseconds: _fadeOutMs),
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final h = c.maxHeight;
                  // Fixed logo width to precisely match native splash (Android 12 inner circle proportion)
                  final logoW = 147.5;
                  final barW = (w * 0.62).clamp(190.0, 320.0);
                  final bottomPad = (h * 0.09).clamp(36.0, 84.0);

                  return Stack(
                    children: [
                      // Soft brand-coloured light blobs (fade in after first frame)
                      FadeTransition(
                        opacity: _intro,
                        child: Stack(
                          children: [
                            Positioned(
                              top: -w * 0.45,
                              left: -w * 0.35,
                              child: _blob(w * 1.1, _a(_sky, 0.16)),
                            ),
                            Positioned(
                              bottom: -w * 0.5,
                              right: -w * 0.4,
                              child: _blob(w * 1.2, _a(_navy, 0.10)),
                            ),
                          ],
                        ),
                      ),

                      // Logo: exactly centred, same as native splash => seamless
                      Center(child: _buildLogo(logoW)),

                      // Progress block
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottomPad,
                        child: FadeTransition(
                          opacity: _intro,
                          child: SafeArea(
                            top: false,
                            child: Center(child: _buildProgress(barW)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, _a(color, 0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double logoW) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // breathing glow
            Container(
              width: logoW * (1.25 + 0.08 * t),
              height: logoW * (1.25 + 0.08 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_a(_sky, 0.10 + 0.10 * t), _a(_sky, 0.0)],
                ),
              ),
            ),
            Transform.scale(scale: 1.0 + 0.015 * t, child: child),
          ],
        );
      },
      child: Image.asset(
        _logoAsset,
        width: logoW,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Mindspace logo',
      ),
    );
  }

  Widget _buildProgress(double width) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : _navy;

    return SizedBox(
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: _target),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          final pct = (v * 100).round().clamp(0, 100);
          return Semantics(
            label: 'Loading',
            value: '$pct percent',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _statusFor(v),
                        key: ValueKey(_statusFor(v)),
                        style: TextStyle(
                          color: _a(textColor, isDarkMode ? 0.8 : 0.62),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 5,
                    color: _a(textColor, 0.10),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_sky, isDarkMode ? _sky : _navy],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: _a(_sky, 0.45), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
