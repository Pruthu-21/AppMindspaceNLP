import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Syncing drive...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class PulseSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PulseSkeleton({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  State<PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<PulseSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class FileListSkeleton extends StatelessWidget {
  const FileListSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const PulseSkeleton(width: 48, height: 48, borderRadius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulseSkeleton(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: 16,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    const PulseSkeleton(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const PulseSkeleton(width: 24, height: 24, borderRadius: 6),
            ],
          ),
        );
      },
    );
  }
}

class FileGridSkeleton extends StatelessWidget {
  const FileGridSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? Colors.grey.withOpacity(0.1),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PulseSkeleton(width: 36, height: 36, borderRadius: 10),
                  PulseSkeleton(width: 20, height: 20, borderRadius: 4),
                ],
              ),
              Spacer(),
              PulseSkeleton(width: 100, height: 14, borderRadius: 4),
              SizedBox(height: 6),
              PulseSkeleton(width: 50, height: 10, borderRadius: 4),
            ],
          ),
        );
      },
    );
  }
}
