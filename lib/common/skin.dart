import 'package:material_ui/material_ui.dart';

import 'color.dart';

/// A curated look: an accent seed, the Material scheme variant it reads best
/// with, and whether the dark palette is taken down to pure black.
///
/// A skin deliberately stores nothing the config does not already keep, so
/// applying one needs no new persisted field, and the selection survives a
/// downgrade of the app.
@immutable
class AppSkin {
  const AppSkin({
    required this.name,
    required this.seed,
    required this.variant,
    this.pureBlack = false,
  });

  /// Shown as-is in every locale: these are product names for looks, not
  /// descriptions of them.
  final String name;

  /// Accent the whole palette is generated from.
  final Color seed;

  final DynamicSchemeVariant variant;

  /// Take the dark surfaces to true black, for OLED panels.
  final bool pureBlack;

  /// The scheme this skin resolves to, used to draw its picker thumbnail.
  ColorScheme schemeFor(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    ).toPureBlack(pureBlack);
  }

  /// Whether the persisted theme settings currently describe this skin.
  bool matches({
    required int? primaryColor,
    required DynamicSchemeVariant variant,
    required bool pureBlack,
  }) {
    return primaryColor == seed.toARGB32() &&
        this.variant == variant &&
        this.pureBlack == pureBlack;
  }
}

/// The shipped looks, ordered from the most colourful to the calmest.
///
/// Every seed is paired with a variant that keeps its hue: `expressive` shifts
/// primary by +240 degrees and `fruitSalad` by -50, which would make a skin
/// named after a colour render as a different one.
const appSkins = <AppSkin>[
  AppSkin(
    name: '极光',
    seed: Color(0xFF7C4DFF),
    variant: DynamicSchemeVariant.content,
  ),
  AppSkin(
    name: '深海',
    seed: Color(0xFF00E5FF),
    variant: DynamicSchemeVariant.vibrant,
  ),
  AppSkin(
    name: '霓虹',
    seed: Color(0xFFFF2D78),
    variant: DynamicSchemeVariant.fidelity,
  ),
  AppSkin(
    name: '翡翠',
    seed: Color(0xFF00E676),
    variant: DynamicSchemeVariant.fidelity,
  ),
  AppSkin(
    name: '熔金',
    seed: Color(0xFFFFB300),
    variant: DynamicSchemeVariant.vibrant,
  ),
  AppSkin(
    name: '虹彩',
    seed: Color(0xFF536DFE),
    variant: DynamicSchemeVariant.rainbow,
  ),
  AppSkin(
    name: '极夜',
    seed: Color(0xFF7C4DFF),
    variant: DynamicSchemeVariant.content,
    pureBlack: true,
  ),
  AppSkin(
    name: '石墨',
    seed: Color(0xFF90A4AE),
    variant: DynamicSchemeVariant.neutral,
  ),
];
