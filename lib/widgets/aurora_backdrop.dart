import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

/// A slow-drifting gradient wash painted behind the whole app.
///
/// The blobs travel a long, low-frequency path, so the widget redraws from a
/// timer rather than a ticker: a full-window ticker would ask for a frame on
/// every vsync for as long as the window stays open. The paint is isolated in
/// its own layer, so a step only re-rasterises the backdrop.
///
/// While [frosted] the whole wash is translucent, which is what lets a desktop
/// blur effect read through it. Otherwise it falls back to a solid surface: a
/// translucent window with no effect behind it would show the raw frame colour.
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({super.key, required this.frosted, this.child});

  /// Whether the window is currently running a desktop blur effect.
  final bool frosted;

  final Widget? child;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop> {
  static const _tick = Duration(milliseconds: 66);
  static const _period = Duration(seconds: 48);

  final _phase = ValueNotifier<double>(0);
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _canAnimate = true;
  bool _washVisible = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canAnimate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    // At full window transparency the wash has faded out to nothing, so
    // drifting it would spend a frame budget re-rasterising an invisible
    // full-window blur. That is exactly the setting this backdrop is most
    // likely to be used with, so it is worth not paying for.
    _washVisible = _resolveAurora().aurora.any((color) => color.a > 0);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _phase.dispose();
    super.dispose();
  }

  bool get _isForeground => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };

  void _sync() {
    if (!_canAnimate || !_isForeground || !_washVisible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_tick, (_) => _step());
  }

  void _step() {
    final steps = _period.inMicroseconds / _tick.inMicroseconds;
    _phase.value = (_phase.value + 1 / steps) % 1;
  }

  /// The tokens actually painted: the transparency scales the wash down with
  /// the window, which is only right while there is a blurred desktop behind it
  /// to take over. Without the effect the window is solid again, so the wash has
  /// to be too — at full strength, or turning the effect off would flatten the
  /// whole look.
  AuroraTheme _resolveAurora() {
    if (widget.frosted) {
      return AuroraTheme.of(context);
    }
    final theme = Theme.of(context);
    return AuroraTheme.fromColorScheme(
      theme.colorScheme,
      brightness: theme.brightness,
      windowTransparency: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aurora = _resolveAurora();
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: widget.frosted ? aurora.windowFill : scheme.surface),
        RepaintBoundary(
          child: CustomPaint(
            painter: _AuroraPainter(phase: _phase, aurora: aurora),
          ),
        ),
        ColoredBox(color: aurora.veil),
        ?widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.phase, required this.aurora})
    : super(repaint: phase);

  final ValueNotifier<double> phase;
  final AuroraTheme aurora;

  /// Where each blob rests, as a fraction of the window.
  static const _anchors = [
    Offset(0.14, 0.10),
    Offset(0.88, 0.24),
    Offset(0.50, 0.95),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final shortest = size.shortestSide;
    final t = phase.value;
    for (var i = 0; i < aurora.aurora.length; i++) {
      final angle = (t + i * 0.33) * 2 * math.pi;
      final anchor = _anchors[i % _anchors.length];
      final drift = 0.12 + 0.02 * i;
      final center = Offset(
        size.width * (anchor.dx + math.sin(angle) * drift),
        size.height * (anchor.dy + math.cos(angle * 0.8) * drift),
      );
      final radius = shortest * (0.52 + 0.10 * math.sin(angle * 1.15));
      final base = aurora.aurora[i];
      // Breathe the blob's strength as well as its size, so the wash visibly
      // swells and recedes instead of only sliding around.
      final pulse = 0.70 + 0.30 * (0.5 + 0.5 * math.sin(angle * 1.35 + i));
      final color = base.withValues(alpha: base.a * pulse);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    // A sheen along the top edge, so the window reads as lit from above.
    final sheenHeight = size.height * 0.45;
    final sheenRect = Offset.zero & Size(size.width, sheenHeight);
    final sheenPulse = 0.22 + 0.12 * math.sin(t * 2 * math.pi);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            aurora.glow.withValues(alpha: aurora.glow.a * sheenPulse),
            aurora.glow.withValues(alpha: 0),
          ],
        ).createShader(sheenRect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.aurora != aurora;
}
