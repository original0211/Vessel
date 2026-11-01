import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _attributeOf(String tag, String attribute) {
  return RegExp('android:$attribute="([^"]+)"').firstMatch(tag)!.group(1)!;
}

String _elementAttribute(String source, String element, String attribute) {
  final tag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return _attributeOf(tag, attribute);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.webp',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('TV adaptive launcher icon uses the vector foreground', () {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _elementAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@drawable/ic_launcher_foreground_tv',
    );
    expect(
      _elementAttribute(adaptiveIcon, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    final foreground = File(
      'android/app/src/main/res/drawable/'
      'ic_launcher_foreground_tv.xml',
    ).readAsStringSync();
    expect(foreground, contains('<vector'));
    expect(foreground, isNot(contains('<bitmap')));
    expect(foreground, isNot(contains('<gradient')));

    final paths = RegExp(
      '<path\\b[^>]*>',
    ).allMatches(foreground).map((match) => match.group(0)!).toList();
    expect(paths, hasLength(2));
    expect(_attributeOf(paths[0], 'fillColor'), '#1A1A1A');
    expect(_attributeOf(paths[1], 'fillColor'), '#7F0019');
    final dotNumbers = RegExp(r'-?\d+\.?\d*')
        .allMatches(_attributeOf(paths[1], 'pathData'))
        .map((match) => double.parse(match.group(0)!))
        .toList();
    expect(dotNumbers[2], 15);
  });
}
