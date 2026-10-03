import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../main.dart'; // To access AppStartupHelper

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Must match @color/splash_bg in android/app/src/main/res/values/colors.xml
  static const Color _fallbackBg = Color(0xFF050d37); // replace with printed value

  late AnimationController _controller;
  List<ui.FrameInfo> _frames = [];
  bool _navigated = false;
  int _totalDurationMs = 0;

  Color _bgTop = _fallbackBg;
  Color _bgBottom = _fallbackBg;

  int _currentPhase = 1;
  bool _isTapping = false;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _controller.addListener(_onTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _navigateToMainApp();
    });
    _loadGif();
  }

  String _hex(Color c) =>
      '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Reads the GIF's top and bottom edge colors so the area around the
  /// letterboxed image blends in with it.
  Future<void> _sampleBackground(ui.Image img) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return;

    Color px(int x, int y) {
      final cx = x.clamp(0, img.width - 1);
      final cy = y.clamp(0, img.height - 1);
      final i = (cy * img.width + cx) * 4;
      return Color.fromARGB(
          255, bd.getUint8(i), bd.getUint8(i + 1), bd.getUint8(i + 2));
    }

    _bgTop = px(2, 2);
    _bgBottom = px(2, img.height - 3);
    debugPrint('SPLASH_BG top=${_hex(_bgTop)} bottom=${_hex(_bgBottom)}');
  }

  Future<void> _loadGif() async {
    try {
      final data = await rootBundle.load('assets/download.gif');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());

      final frames = <ui.FrameInfo>[];
      int totalMs = 0;
      for (int i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        frames.add(frame);
        totalMs += frame.duration.inMilliseconds;
      }
      if (frames.isNotEmpty) await _sampleBackground(frames.first.image);

      if (!mounted) {
        for (final f in frames) {
          f.image.dispose();
        }
        return;
      }
      setState(() {
        _frames = frames;
        _totalDurationMs = totalMs;
      });
      _controller.duration = Duration(milliseconds: _totalDurationMs);
      _applySpeed();
    } catch (error) {
      debugPrint('Error loading splash GIF: $error');
      _navigateToMainApp();
    }
  }

  void _onTick() {
    if (_frames.isEmpty) return;
    final frame = (_controller.value * (_frames.length - 1)).floor();

    int newPhase;
    if (frame >= _frames.length - 5) {
      newPhase = 3;
    } else if (frame > 45) {
      newPhase = 2;
    } else {
      newPhase = 1;
    }

    final isTappingNow =
        DateTime.now().difference(_lastTapTime).inMilliseconds < 300;

    if (newPhase != _currentPhase || isTappingNow != _isTapping) {
      _currentPhase = newPhase;
      _isTapping = isTappingNow;
      _applySpeed();
    }
  }

  void _applySpeed() {
    if (_controller.status == AnimationStatus.completed || _navigated) return;

    double speedMultiplier = 1.0;
    if (_currentPhase == 3) {
      speedMultiplier = 0.25;
    } else if (_currentPhase == 2 && _isTapping) {
      speedMultiplier = 2.0;
    }

    final remainingValue = 1.0 - _controller.value;
    if (remainingValue <= 0) return;

    final newDuration =
        ((remainingValue * _totalDurationMs) / speedMultiplier).round();
    if (newDuration > 0) {
      _controller.animateTo(1.0, duration: Duration(milliseconds: newDuration));
    }
  }

  void _onTap() {
    _lastTapTime = DateTime.now();
    _onTick();
  }

  void _navigateToMainApp() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppStartupHelper(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final f in _frames) {
      f.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bgTop,
        // No SafeArea: the background must run under the status and nav bars.
        body: GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, _bgBottom],
              ),
            ),
            child: SizedBox.expand(
              child: _frames.isEmpty
                  ? const SizedBox.shrink()
                  : RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final idx = (_controller.value * (_frames.length - 1))
                              .floor()
                              .clamp(0, _frames.length - 1);
                          return RawImage(
                            image: _frames[idx].image,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}