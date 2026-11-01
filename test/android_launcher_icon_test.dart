import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _attributeOf(String tag, String attribute) {
  return RegExp('android:$attribute="([^"]+)"').firstMatch(tag)!.group(1)!;
}

String _elementAttribute(String source, String element, String attribute) {
  final tag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return _attributeOf(tag, attribute);
}

List<String> _tags(String source, String element) {
  return RegExp(
    '<$element\\b[^>]*>',
  ).allMatches(source).map((match) => match.group(0)!).toList();
}

List<double> _numbers(String text) {
  return RegExp(
    r'-?\d+\.?\d*',
  ).allMatches(text).map((match) => double.parse(match.group(0)!)).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final name in ['ic_launcher', 'ic_launcher_round']) {
    test('$name adaptive icon uses the vector foreground', () {
      final adaptiveIcon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/$name.xml',
      ).readAsStringSync();
      expect(
        _elementAttribute(adaptiveIcon, 'foreground', 'drawable'),
        '@drawable/ic_launcher_foreground',
      );
      expect(
        _elementAttribute(adaptiveIcon, 'background', 'drawable'),
        '@color/ic_launcher_background',
      );
      expect(
        _elementAttribute(adaptiveIcon, 'monochrome', 'drawable'),
        '@drawable/ic_launcher_foreground',
      );
    });
  }

  test('launcher foreground ring stays inside the adaptive safe zone', () {
    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    ).readAsStringSync();
    expect(foreground, contains('<vector'));
    expect(foreground, isNot(contains('<bitmap')));
    expect(foreground, isNot(contains('<gradient')));

    final paths = _tags(foreground, 'path');
    expect(paths, hasLength(2));
    final ring = paths[0];
    expect(_attributeOf(ring, 'fillType'), 'evenOdd');
    expect(_attributeOf(ring, 'fillColor'), '#1A1A1A');
    expect(
      _attributeOf(ring, 'pathData'),
      'M24,120 A96,96 0 1,1 216,120 A96,96 0 1,1 24,120 Z '
      'M37.2,120 A82.8,82.8 0 1,1 202.8,120 A82.8,82.8 0 1,1 37.2,120 Z',
    );

    var scale = 1.0;
    for (final group in _tags(foreground, 'group')) {
      scale *= double.parse(_attributeOf(group, 'scaleX'));
    }
    expect(96 * scale, lessThanOrEqualTo(80));
  });

  test('launcher foreground dot sits enlarged on the ring midline', () {
    final foreground = File(
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    ).readAsStringSync();
    final dot = _tags(foreground, 'path')[1];
    expect(_attributeOf(dot, 'fillColor'), '#7F0019');

    final numbers = _numbers(_attributeOf(dot, 'pathData'));
    final radius = numbers[2];
    final centreX = numbers[0] + radius;
    final centreY = numbers[1];
    expect(radius, 15);
    final dx = centreX - 120;
    final dy = centreY - 120;
    expect(math.sqrt(dx * dx + dy * dy), closeTo(89.4, 0.05));
    expect(math.atan2(dy, dx) * 180 / math.pi, closeTo(157, 0.5));
  });

  test('launcher foreground rasters carry the safe-zone composition', () async {
    const expectedSizes = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };
    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final bytes = await file.readAsBytes();
      expect(bytes.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ], reason: '${file.path} is not a PNG');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      if (density == 'xxxhdpi') {
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final data = byteData!.buffer.asUint8List();
        var ink = 0;
        var vermilion = 0;
        var maxOpaqueRadius = 0.0;
        final centre = (size - 1) / 2;
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            final i = (y * size + x) * 4;
            final alpha = data[i + 3];
            if (alpha <= 10) {
              continue;
            }
            final radius =
                math.sqrt(
                  (x - centre) * (x - centre) + (y - centre) * (y - centre),
                ) *
                240 /
                size;
            if (radius > maxOpaqueRadius) {
              maxOpaqueRadius = radius;
            }
            if (alpha > 200) {
              final r = data[i];
              final g = data[i + 1];
              final b = data[i + 2];
              if ((r - 26).abs() + (g - 26).abs() + (b - 26).abs() < 40) {
                ink++;
              }
              if ((r - 127).abs() + g.abs() + (b - 25).abs() < 60) {
                vermilion++;
              }
            }
          }
        }
        expect(maxOpaqueRadius, lessThanOrEqualTo(80));
        expect(ink, greaterThan(4000));
        expect(vermilion, greaterThan(300));
      }
      frame.image.dispose();
      codec.dispose();
    }
  });
}
