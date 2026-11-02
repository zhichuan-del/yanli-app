import 'dart:async';

import 'package:flutter/material.dart';

/// Shows the supplied launch artwork briefly before revealing the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 650),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _showSplash
        ? ColoredBox(
            key: const ValueKey('launch-artwork'),
            color: const Color(0xff70b9e4),
            child: SizedBox.expand(
              child: Image.asset(
                'assets/launch.jpg',
                fit: BoxFit.fill,
                semanticLabel: '西南民族大学校园启动画面',
              ),
            ),
          )
        : KeyedSubtree(key: const ValueKey('application'), child: widget.child);
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}
