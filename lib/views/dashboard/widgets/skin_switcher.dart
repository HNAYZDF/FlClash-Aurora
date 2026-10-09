import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Window transparency and the skin picker, stacked under the dashboard grid.
///
/// They are one cluster: both change what the window looks like, and the
/// dashboard is where a look gets changed on a whim rather than from settings.
class SkinSwitcher extends StatelessWidget {
  const SkinSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [_TransparencyStrip(), SizedBox(height: 6), _SkinPill()],
    );
  }
}

/// A compact slider for how far the desktop shows through the window. Disabled
/// while no blur effect is running, since it would do nothing.
class _TransparencyStrip extends ConsumerStatefulWidget {
  const _TransparencyStrip();

  @override
  ConsumerState<_TransparencyStrip> createState() => _TransparencyStripState();
}

class _TransparencyStripState extends ConsumerState<_TransparencyStrip> {
  static const _sliderWidth = 130.0;

  final _draft = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final aurora = AuroraTheme.of(context);
    final stored = ref.watch(
      themeSettingProvider.select((state) => state.windowTransparency),
    );
    final frosted = ref.watch(windowBlurProvider);
    return Tooltip(
      message: appLocalizations.windowTransparency,
      // Above the strip, never below: a tooltip under it would cover the skin
      // pill that sits directly underneath.
      preferBelow: false,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: aurora.glassFill,
          shape: AppShape.full.copyWith(
            side: BorderSide(color: aurora.glassBorder),
          ),
          shadows: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 12,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlyphIcon(
                AppGlyphs.blur,
                size: 14,
                color: frosted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: _sliderWidth,
                height: 36,
                child: ValueListenableBuilder<double?>(
                  valueListenable: _draft,
                  builder: (context, draft, _) {
                    final percent = windowTransparencyPercent(draft ?? stored);
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: percent,
                        min: minWindowTransparencyPercent,
                        max: maxWindowTransparencyPercent,
                        label: '${percent.round()}%',
                        // The draft keeps a drag from writing the config every
                        // frame; letting go is what persists it.
                        onChanged: frosted
                            ? (next) => _draft.value =
                                  windowTransparencyFromPercent(next)
                            : null,
                        onChangeEnd: frosted
                            ? (next) {
                                _draft.value = null;
                                ref
                                    .read(themeSettingProvider.notifier)
                                    .update(
                                      (state) => state.copyWith(
                                        windowTransparency:
                                            windowTransparencyFromPercent(next),
                                      ),
                                    );
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<double?>(
                valueListenable: _draft,
                builder: (context, draft, _) {
                  final percent = windowTransparencyPercent(draft ?? stored);
                  return Text(
                    '${percent.round()}%',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: frosted
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinPill extends ConsumerWidget {
  const _SkinPill();

  static const _dotSize = 10.0;

  /// Widest label any skin can show, so the pill keeps one width instead of
  /// resizing as the selection changes.
  static double _labelWidthOf(BuildContext context, List<String> labels) {
    final style = context.textTheme.bodySmall;
    var widest = 0.0;
    for (final label in labels) {
      widest = max(
        widest,
        globalState.measure.computeTextSize(Text(label, style: style)).width,
      );
    }
    return widest;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final aurora = AuroraTheme.of(context);
    final current = ref.watch(
      themeSettingProvider.select(
        (state) => (
          primaryColor: state.primaryColor,
          schemeVariant: state.schemeVariant,
          pureBlack: state.pureBlack,
        ),
      ),
    );
    final selected = appSkins
        .where(
          (skin) => skin.matches(
            primaryColor: current.primaryColor,
            variant: current.schemeVariant,
            pureBlack: current.pureBlack,
          ),
        )
        .firstOrNull;
    final swatch = selected?.seed ?? Theme.of(context).colorScheme.primary;
    final labelWidth = _labelWidthOf(context, [
      for (final skin in appSkins) skin.name,
      appLocalizations.custom,
    ]);
    return MenuAnchor(
      menuChildren: [
        for (final skin in appSkins)
          MenuItemButton(
            onPressed: () {
              ref
                  .read(themeSettingProvider.notifier)
                  .update(
                    (state) => state.copyWith(
                      primaryColor: skin.seed.toARGB32(),
                      schemeVariant: skin.variant,
                      pureBlack: skin.pureBlack,
                    ),
                  );
            },
            leadingIcon: _SkinDot(color: skin.seed, selected: skin == selected),
            child: Text(skin.name),
          ),
      ],
      builder: (context, controller, _) {
        return Tooltip(
          message: appLocalizations.skins,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: aurora.glassFill,
                  shape: AppShape.full.copyWith(
                    side: BorderSide(color: aurora.glassBorder),
                  ),
                  // A faint halo in the current skin's colour, just enough to
                  // tie the control to the look it switches.
                  shadows: [
                    BoxShadow(
                      color: swatch.withValues(alpha: 0.14),
                      blurRadius: 12,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 5, 8, 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkinDot(color: swatch, selected: true),
                      const SizedBox(width: 7),
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          selected?.name ?? appLocalizations.custom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 3),
                      GlyphIcon(
                        AppGlyphs.caretDown,
                        size: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkinDot extends StatelessWidget {
  const _SkinDot({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SkinPill._dotSize,
      height: _SkinPill._dotSize,
      decoration: ShapeDecoration(
        shape: AppShape.full,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.lighten(22)],
        ),
        shadows: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.65),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
    );
  }
}
