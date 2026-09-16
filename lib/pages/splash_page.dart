import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../main.dart'; // To access AppStartupHelper

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ui.FrameInfo> _frames = [];
  bool _navigated = false;
  int _totalDurationMs = 0;

  int _currentPhase = 1;
  bool _isTapping = false;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    // Exactly ONE AnimationController, as requested.
    // Initial duration will be overridden once the GIF is loaded.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _controller.addListener(_onTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToMainApp();
      }
    });

    _loadGif();
  }

  Future<void> _loadGif() async {
    try {
      final data = await DefaultAssetBundle.of(
        context,
      ).load('assets/download.gif');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());

      List<ui.FrameInfo> frames = [];
      int totalMs = 0;
      for (int i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        frames.add(frame);
        totalMs += frame.duration.inMilliseconds;
      }

      if (mounted) {
        setState(() {
          _frames = frames;
          _totalDurationMs = totalMs;
        });
        // Start animation normally
        _controller.duration = Duration(milliseconds: _totalDurationMs);
        _applySpeed();
      }
    } catch (error) {
      debugPrint('Error loading splash GIF: $error');
      // If asset fails to load, fallback to immediate navigation
      _navigateToMainApp();
    }
  }

  void _onTick() {
    if (_frames.isEmpty) return;

    // Determine current frame index
    int frame = (_controller.value * (_frames.length - 1)).floor();

    // Determine the phase
    int newPhase = 1;
    if (frame >= _frames.length - 5) {
      newPhase = 3; // Phase 3: Final 4-5 frames
    } else if (frame > 45) {
      newPhase = 2; // Phase 2: Middle portion
    } else {
      newPhase = 1; // Phase 1: Intro
    }

    // Determine tapping state (taps are considered active for 300ms)
    bool isTappingNow =
        DateTime.now().difference(_lastTapTime).inMilliseconds < 300;

    // Only apply speed changes when phase or tap state changes
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
      speedMultiplier = 0.25; // Noticeable slow down for the final frames
    } else if (_currentPhase == 2 && _isTapping) {
      speedMultiplier = 2.0; // 2x speed when tapping in the middle phase
    } else {
      speedMultiplier = 1.0; // Normal speed
    }

    double remainingValue = 1.0 - _controller.value;
    if (remainingValue <= 0) return;

    int newDuration = ((remainingValue * _totalDurationMs) / speedMultiplier)
        .round();

    if (newDuration > 0) {
      // Accelerates/decelerates by changing the remaining simulation time,
      // without restarting the animation from the beginning.
      _controller.animateTo(1.0, duration: Duration(milliseconds: newDuration));
    }
  }

  void _onTap() {
    _lastTapTime = DateTime.now();
    // Prompt evaluation of tap state immediately
    _onTick();
  }

  void _navigateToMainApp() {
    if (!mounted || _navigated) return;
    _navigated = true;

    // Ensure only exactly ONE navigation action happens.
    // Very short transition (Duration.zero) for immediate app opening
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: _frames.isEmpty
              ? const SizedBox.shrink()
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    int frameIndex = (_controller.value * (_frames.length - 1))
                        .floor();
                    if (frameIndex < 0) frameIndex = 0;
                    if (frameIndex >= _frames.length)
                      frameIndex = _frames.length - 1;

                    return RawImage(
                      image: _frames[frameIndex].image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
