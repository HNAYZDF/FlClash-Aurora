import 'package:fl_clash/common/color.dart';
import 'package:fl_clash/common/skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/hct/hct.dart';
import 'package:material_ui/material_ui.dart';

/// A skin is named after a colour, so its primary must stay on that hue. The
/// hue-rotating variants (`expressive` +240, `fruitSalad` -50) would silently
/// make "Neon" render as blue, which is what this guards against.
void main() {
  test('every skin keeps its seed hue in its primary', () {
    const tolerance = 40.0;
    for (final skin in appSkins) {
      final seedHue = Hct.fromInt(skin.seed.toARGB32()).hue;
      for (final brightness in [Brightness.dark, Brightness.light]) {
        final primary = skin.schemeFor(brightness).primary;
        final primaryHue = Hct.fromInt(primary.toARGB32()).hue;
        var delta = (primaryHue - seedHue).abs() % 360;
        if (delta > 180) {
          delta = 360 - delta;
        }
        // ignore: avoid_print
        print(
          'SKIN ${skin.name.padRight(4)} ${brightness.name.padRight(5)} '
          'seed=${skin.seed.hex} hue=${seedHue.toStringAsFixed(0)} '
          '-> primary=${primary.hex} hue=${primaryHue.toStringAsFixed(0)} '
          'delta=${delta.toStringAsFixed(0)}',
        );
        expect(
          delta,
          lessThan(tolerance),
          reason:
              '${skin.name} (${skin.variant.name}) drifts '
              '${delta.toStringAsFixed(0)} degrees off its seed hue in '
              '${brightness.name}',
        );
      }
    }
  });

  test('skins are distinguishable from one another', () {
    final darkPrimaries = {
      for (final skin in appSkins) skin.name: skin.schemeFor(Brightness.dark).primary.hex,
    };
    // ignore: avoid_print
    print('SKIN primaries: $darkPrimaries');
    expect(
      darkPrimaries.values.toSet().length,
      greaterThanOrEqualTo(appSkins.length - 1),
      reason: 'two skins resolve to the same primary',
    );
  });
}
