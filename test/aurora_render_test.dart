import 'dart:ui' as ui;

import 'package:fl_clash/common/aurora.dart';
import 'package:fl_clash/common/color.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/widgets/aurora_backdrop.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the backdrop offscreen and returns a coarse fingerprint of the
/// pixels, so both its colours and its motion can be checked without launching
/// the desktop app.
Future<({List<String> samples, int distinct})> _fingerprint(
  WidgetTester tester,
  GlobalKey key,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  ui.Image? image;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 1.0);
  });
  final img = image!;
  final raw = await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final data = raw!.buffer.asUint8List();
  String px(int x, int y) {
    final i = (y * img.width + x) * 4;
    return '#${data[i].toRadixString(16).padLeft(2, '0')}'
        '${data[i + 1].toRadixString(16).padLeft(2, '0')}'
        '${data[i + 2].toRadixString(16).padLeft(2, '0')}';
  }

  final samples = <String>[];
  for (var y = 20; y < img.height - 20; y += 90) {
    for (var x = 20; x < img.width - 20; x += 120) {
      samples.add(px(x, y));
    }
  }
  final distinct = samples.toSet().length;
  final result = (samples: samples, distinct: distinct);
  img.dispose();
  return result;
}

Future<GlobalKey> _pumpBackdrop(
  WidgetTester tester,
  Brightness brightness,
  Color seed, {
  double windowTransparency = 0,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(900, 560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.content,
        ),
      ).withAurora(windowTransparency: windowTransparency),
      home: RepaintBoundary(
        key: key,
        child: const AuroraBackdrop(frosted: false, child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  return key;
}

void main() {
  test('a higher window transparency lets more of the desktop through', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF));
    AuroraTheme at(double transparency) => AuroraTheme.fromColorScheme(
      scheme,
      brightness: Brightness.dark,
      windowTransparency: transparency,
    );

    final opaque = at(0);
    final glass = at(maxWindowTransparency);
    expect(opaque.windowFill.a, 1.0, reason: 'zero transparency must be solid');
    // Fully transparent means nothing of the app's own background is left, so
    // the desktop cannot be tinted by a scrim that stayed behind.
    expect(glass.windowFill.a, 0.0);
    expect(glass.veil.a, 0.0);
    expect(glass.aurora.every((blob) => blob.a == 0.0), isTrue);
    expect(at(1).windowFill.a, glass.windowFill.a);
  });

  for (final (name, brightness, seed) in <(String, Brightness, Color)>[
    ('dark', Brightness.dark, const Color(0xFF7C4DFF)),
    ('light', Brightness.light, const Color(0xFF7C4DFF)),
  ]) {
    testWidgets('backdrop paints a graded wash ($name)', (tester) async {
      final key = await _pumpBackdrop(tester, brightness, seed);
      final context = tester.element(find.byType(AuroraBackdrop));
      final aurora = AuroraTheme.of(context);
      debugPrint(
        'PROBE[$name] surface=${Theme.of(context).colorScheme.surface.hex} '
        'blobs=${aurora.aurora.map((c) => c.hex).join(",")}',
      );
      final print = await _fingerprint(tester, key);
      debugPrint('PROBE[$name] distinct sampled colours = ${print.distinct}');
      expect(
        print.distinct,
        greaterThan(1),
        reason: 'a single flat colour means the backdrop never painted',
      );
    });
  }

  testWidgets('a solid window keeps the wash at full strength', (tester) async {
    // Transparency only means anything over a blurred desktop. With no effect
    // running the window is solid again, so the wash must not stay scaled away
    // with it: that would leave a bare flat panel with no aurora at all.
    final key = await _pumpBackdrop(
      tester,
      Brightness.dark,
      const Color(0xFF7C4DFF),
      windowTransparency: maxWindowTransparency,
    );
    final print = await _fingerprint(tester, key);
    debugPrint('PROBE solid distinct sampled colours = ${print.distinct}');
    expect(
      print.distinct,
      greaterThan(1),
      reason: 'the wash vanished while the window has no blur behind it',
    );
  });

  testWidgets('backdrop keeps drifting as time passes', (tester) async {
    final key = await _pumpBackdrop(
      tester,
      Brightness.dark,
      const Color(0xFF7C4DFF),
    );
    // Grab the first three frames so a drift that only shows up later is caught.
    final before = await _fingerprint(tester, key);
    await tester.pump(const Duration(seconds: 5));
    final middle = await _fingerprint(tester, key);
    await tester.pump(const Duration(seconds: 7));
    final after = await _fingerprint(tester, key);

    final movedEarly = before.samples.join() != middle.samples.join();
    final movedLate = middle.samples.join() != after.samples.join();
    debugPrint('PROBE motion: t0!=t5 -> $movedEarly, t5!=t12 -> $movedLate');
    expect(
      movedEarly || movedLate,
      isTrue,
      reason: 'the backdrop is static, so the drift timer is not running',
    );
  });
}
