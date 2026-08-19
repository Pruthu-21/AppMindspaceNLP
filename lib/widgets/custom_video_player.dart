import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String url;
  final String fileName;
  final bool isMini;
  final Duration initialPosition;
  final bool autoPlay;
  final Function(Duration position)? onPositionChanged;
  final Function(bool isPlaying)? onPlayingChanged;
  final Function(Duration duration)? onDurationChanged;

  const CustomVideoPlayer({
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
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  VideoPlayerController? _controller;
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

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Failed to stream video',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
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
                'Connecting to video stream...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final value = _controller!.value;
    final position = value.position;
    final duration = value.duration;

    if (widget.isMini) {
      // Mini Player Mode for FileDetailsPage
      return GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Frame
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            // Controls Overlay
            if (_showControls) ...[
              Container(
                color: Colors.black38,
              ),
              // Play/Pause Button
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 56,
                ),
                onPressed: () {
                  if (value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                },
              ),
              // Timeline & Timeline controls at bottom
              Positioned(
                bottom: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: theme.colorScheme.primary,
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
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
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Full Screen Player Mode for FilePreviewerPage
    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Full Screen Video Frame
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            
            // Premium control overlay
            if (_showControls) ...[
              // Backdrop shadow
              Container(color: Colors.black45),
              
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

              // Centered Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
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
                        size: 40,
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
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      _startHideTimer();
                      final newPos = position + const Duration(seconds: 10);
                      _controller!.seekTo(newPos > duration ? duration : newPos);
                    },
                  ),
                ],
              ),
              
              // Bottom Progress Bar & Time Labels
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: Colors.white24,
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
                      // Position labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
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
