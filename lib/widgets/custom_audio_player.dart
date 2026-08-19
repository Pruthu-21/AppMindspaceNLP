import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';

class CustomAudioPlayer extends StatefulWidget {
  final String url;
  final String fileName;
  final bool isMini;
  final Duration initialPosition;
  final bool autoPlay;
  final Function(Duration position)? onPositionChanged;
  final Function(bool isPlaying)? onPlayingChanged;
  final Function(Duration duration)? onDurationChanged;

  const CustomAudioPlayer({
    Key? key,
    required this.url,
    required this.fileName,
    this.isMini = false,
    this.initialPosition = Duration.zero,
    this.autoPlay = false,
    this.onPositionChanged,
    this.onPlayingChanged,
    this.onDurationChanged,
  }) : super(key: key);

  @override
  State<CustomAudioPlayer> createState() => _CustomAudioPlayerState();
}

class _CustomAudioPlayerState extends State<CustomAudioPlayer> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late AnimationController _rotationController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  Timer? _hideTimer;

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _initializeController();
  }

  void _initializeController() {
    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    final isNetwork = widget.url.startsWith('http://') || widget.url.startsWith('https://');
    if (isNetwork) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    } else {
      _controller = VideoPlayerController.file(File(widget.url));
    }
    _controller!
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          if (widget.onDurationChanged != null) {
            widget.onDurationChanged!(_controller!.value.duration);
          }
          if (widget.initialPosition != Duration.zero) {
            _controller!.seekTo(widget.initialPosition);
          }
          if (widget.autoPlay) {
            _controller!.play();
          }
          _controller!.addListener(_playerListener);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  void _playerListener() {
    if (!mounted || _controller == null) return;
    
    // Sync vinyl rotation animation with player playing state
    if (_controller!.value.isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
    
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_controller!.value.position);
    }

    if (widget.onPlayingChanged != null) {
      widget.onPlayingChanged!(_controller!.value.isPlaying);
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hasHours = _controller != null && _controller!.value.duration.inHours > 0;
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    
    if (hasHours) {
      final hours = duration.inHours.toString();
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Failed to stream audio track',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _initializeController,
              child: Text(
                'Retry Connection',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connecting to stream...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final value = _controller!.value;
    final position = value.position;
    final duration = value.duration;

    if (widget.isMini) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                // Spinning Vinyl
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.black87 : Colors.grey.shade900,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Playback details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value.isPlaying ? 'Now Playing...' : 'Paused',
                        style: TextStyle(
                          color: value.isPlaying ? theme.colorScheme.primary : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Compact Controls
                IconButton(
                  icon: Icon(
                    value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: theme.colorScheme.primary,
                    size: 38,
                  ),
                  onPressed: () {
                    if (value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Custom Timeline
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                      thumbColor: theme.colorScheme.primary,
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (val) {
                        _controller!.seekTo(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Full Screen Layout Style
    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Backdrop Shadow (always visible)
            Positioned.fill(
              child: Container(
                color: isDark ? Colors.black45 : Colors.white12,
              ),
            ),
            
            // Large spinning vinyl (always visible)
            Center(
              child: RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.black87 : Colors.grey.shade900,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Premium control overlay
            if (_showControls) ...[
              // Dark backdrop cover when controls are active
              Container(color: Colors.black26),
              
              // Top Bar with back button and file name
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () {
                            Navigator.pop(context, {
                              'position': position,
                              'isPlaying': value.isPlaying,
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom slider, timing, and playback controls
              Positioned(
                bottom: 32,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Slider timeline
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: theme.colorScheme.primary,
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (val) {
                            _startHideTimer();
                            _controller!.seekTo(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                      
                      // Labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Audio controllers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, size: 30, color: Colors.white),
                            onPressed: () {
                              _startHideTimer();
                              final newPos = position - const Duration(seconds: 10);
                              _controller!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                            },
                          ),
                          const SizedBox(width: 32),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                _startHideTimer();
                                if (value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 32),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, size: 30, color: Colors.white),
                            onPressed: () {
                              _startHideTimer();
                              final newPos = position + const Duration(seconds: 10);
                              _controller!.seekTo(newPos > duration ? duration : newPos);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
