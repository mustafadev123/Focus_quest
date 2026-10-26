import 'dart:async';

import 'package:flutter/material.dart';

/// The completion moment after Save: a check mark grows in with the minutes
/// recorded, then [onDone] runs. With reduced motion the final frame is shown
/// at once and only the short hold remains.
class CompletionOverlay extends StatefulWidget {
  const CompletionOverlay({
    super.key,
    required this.minutes,
    required this.onDone,
  });

  final int minutes;
  final VoidCallback onDone;

  static const animationDuration = Duration(milliseconds: 700);
  static const holdDuration = Duration(milliseconds: 600);

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay>
    with SingleTickerProviderStateMixin {
  // Explicit animation for the session-completion moment.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CompletionOverlay.animationDuration,
  );
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _finishAfterHold();
    } else {
      _controller.forward().whenComplete(_finishAfterHold);
    }
  }

  Timer? _hold;

  void _finishAfterHold() {
    _hold = Timer(CompletionOverlay.holdDuration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes = widget.minutes;

    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Session saved. $minutes '
            '${minutes == 1 ? 'minute' : 'minutes'} added to History.',
        excludeSemantics: true,
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 56, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session saved',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$minutes ${minutes == 1 ? 'minute' : 'minutes'} '
                'added to History',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
