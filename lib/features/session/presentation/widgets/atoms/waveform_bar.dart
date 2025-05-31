// lib/features/session/presentation/widgets/atoms/waveform_bar.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/durations.dart';

/// A single animated bar for visualizing audio waveforms.
/// Part of a larger waveform visualization during speech input.
class WaveformBar extends StatefulWidget {
  final double maxHeight;
  final Color color;
  final bool isAnimating;
  final Duration animationDelay;

  const WaveformBar({
    super.key,
    this.maxHeight = 40.0,
    required this.color,
    this.isAnimating = true,
    this.animationDelay = Duration.zero,
  });

  @override
  State<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<WaveformBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: HermesDurations.slow,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.1,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isAnimating) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _startAnimation();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.stop();
      _controller.value = 0.1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 4,
          height: widget.maxHeight * _animation.value,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
