import 'package:flutter/foundation.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:material_ui/material_ui.dart';

import 'constant.dart';
import 'shape.dart';

/// Visual tokens the Material [ColorScheme] does not carry: the hues of the
/// ambient backdrop, the halo behind highlighted controls, and the fills used
/// by frosted surfaces.
///
/// Everything is derived from the active [ColorScheme], so the aurora follows
/// whichever accent colour the user picked instead of pinning a palette.
@immutable
class AuroraTheme extends ThemeExtension<AuroraTheme> {
  const AuroraTheme({
    required this.aurora,
    required this.glow,
    required this.glassFill,
    required this.glassBorder,
    required this.veil,
    required this.windowFill,
  });

  /// Drifting blobs of the ambient backdrop, painted from front to back.
  final List<Color> aurora;

  /// Halo painted behind an active control.
  final Color glow;

  /// Fill of a frosted surface: translucent, so the backdrop shows through.
  final Color glassFill;

  /// Hairline border of a frosted surface.
  final Color glassBorder;

  /// Scrim laid over the backdrop so text keeps its contrast.
  final Color veil;

  /// Base laid over the desktop while the window runs a translucent effect.
  /// The backdrop swaps it for a solid surface otherwise, since a translucent
  /// window with no effect behind it would show the raw frame colour.
  final Color windowFill;

  factory AuroraTheme.fromColorScheme(
    ColorScheme scheme, {
    required Brightness brightness,
    double windowTransparency = defaultWindowTransparency,
  }) {
    final isDark = brightness == Brightness.dark;
    // How far the desktop shows through the window. At 1 nothing of the app's
    // own background is left, so every scrim scales by what remains: the veil
    // and the ambient wash would otherwise keep painting over the desktop even
    // once the base has gone.
    final glass = windowTransparency.clamp(0.0, maxWindowTransparency);
    final keep = 1 - glass;
    // Scale the whole wash by how colourful the palette actually is: a muted
    // accent would disappear at full strength, a neon one would blow out. This
    // is what makes each skin carry its own character rather than only its own
    // hue.
    final vividness = (Hct.fromInt(scheme.primary.toARGB32()).chroma / 60)
        .clamp(0.0, 1.0);
    final blobAlpha =
        ((isDark ? 0.26 : 0.15) + vividness * (isDark ? 0.16 : 0.10)) * keep;
    Color blob(Color color) => color.withValues(alpha: blobAlpha);
    return AuroraTheme(
      aurora: [
        blob(scheme.tertiary),
        blob(scheme.primary),
        blob(scheme.secondary),
      ],
      glow: scheme.primary.withValues(
        alpha: (isDark ? 0.28 : 0.16) + vividness * 0.18,
      ),
      glassFill: scheme.surfaceContainerLow.withValues(
        alpha: isDark ? 0.66 : 0.78,
      ),
      glassBorder: scheme.primary.withValues(
        alpha: (isDark ? 0.12 : 0.08) + vividness * 0.10,
      ),
      veil: scheme.surface.withValues(alpha: (isDark ? 0.30 : 0.34) * keep),
      windowFill: scheme.surface.withValues(alpha: keep),
    );
  }

  static AuroraTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AuroraTheme>() ??
        AuroraTheme.fromColorScheme(
          theme.colorScheme,
          brightness: theme.brightness,
        );
  }

  @override
  AuroraTheme copyWith({
    List<Color>? aurora,
    Color? glow,
    Color? glassFill,
    Color? glassBorder,
    Color? veil,
    Color? windowFill,
  }) {
    return AuroraTheme(
      aurora: aurora ?? this.aurora,
      glow: glow ?? this.glow,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      veil: veil ?? this.veil,
      windowFill: windowFill ?? this.windowFill,
    );
  }

  @override
  AuroraTheme lerp(covariant AuroraTheme? other, double t) {
    if (other == null) {
      return this;
    }
    final length = aurora.length < other.aurora.length
        ? aurora.length
        : other.aurora.length;
    return AuroraTheme(
      aurora: [
        for (var i = 0; i < length; i++)
          Color.lerp(aurora[i], other.aurora[i], t)!,
      ],
      glow: Color.lerp(glow, other.glow, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      veil: Color.lerp(veil, other.veil, t)!,
      windowFill: Color.lerp(windowFill, other.windowFill, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuroraTheme &&
        listEquals(other.aurora, aurora) &&
        other.glow == glow &&
        other.glassFill == glassFill &&
        other.glassBorder == glassBorder &&
        other.veil == veil &&
        other.windowFill == windowFill;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(aurora),
    glow,
    glassFill,
    glassBorder,
    veil,
    windowFill,
  );
}

extension AuroraThemeDataExt on ThemeData {
  /// Layers the aurora look over [AppShapeThemeExt.withAppShapes].
  ///
  /// The scaffold is deliberately transparent: the ambient backdrop is painted
  /// once behind the whole window, so every page has to let it through instead
  /// of re-painting an opaque surface of its own.
  ThemeData withAurora({
    double windowTransparency = defaultWindowTransparency,
  }) {
    final scheme = colorScheme;
    final aurora = AuroraTheme.fromColorScheme(
      scheme,
      brightness: brightness,
      windowTransparency: windowTransparency,
    );
    return copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      extensions: [aurora],
      cardTheme: CardThemeData(
        color: aurora.glassFill,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.primary.withValues(alpha: 0.24),
        elevation: 0,
        margin: cardTheme.margin,
        clipBehavior: cardTheme.clipBehavior,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppRadius.all(AppCorner.md),
          side: BorderSide(color: aurora.glassBorder),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        crossAxisMargin: 2,
        minThumbLength: 40,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.8);
          }
          return scheme.primary.withValues(alpha: 0.38);
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: aurora.glassBorder,
        thickness: 1,
        space: 1,
        radius: BorderRadius.circular(1),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: scheme.inverseSurface,
          shape: AppShape.sm,
        ),
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 12,
          decoration: TextDecoration.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
