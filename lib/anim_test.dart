import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SplashTest());
  }
}

class SplashTest extends StatefulWidget {
  const SplashTest({Key? key}) : super(key: key);
  @override
  State<SplashTest> createState() => _SplashTestState();
}

class _SplashTestState extends State<SplashTest> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _controller.forward();
  }

  void _onTap() {
    double remainingValue = 1.0 - _controller.value;
    int newDuration = (remainingValue * 5000).round(); // 2x speed
    _controller.animateTo(1.0, duration: Duration(milliseconds: newDuration));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Center(child: Text('Value: ${_controller.value.toStringAsFixed(3)}'));
          }
        ),
      ),
    );
  }
}
