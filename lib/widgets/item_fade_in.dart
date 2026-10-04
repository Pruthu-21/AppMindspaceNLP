import 'package:flutter/material.dart';

class ItemFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ItemFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<ItemFadeIn> createState() => _ItemFadeInState();
}

class _ItemFadeInState extends State<ItemFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
