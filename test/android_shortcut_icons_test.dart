import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _attributeOf(String tag, String attribute) {
  return RegExp('android:$attribute="([^"]+)"').firstMatch(tag)!.group(1)!;
}

List<String> _tags(String source, String element) {
  return RegExp('<$element\\b[^>]*>')
      .allMatches(source)
      .map((match) => match.group(0)!)
      .toList();
}

String _resolveColor(String value) {
  if (!value.startsWith('@color/')) {
    return value;
  }
  final colors = File('android/app/src/main/res/values/colors.xml')
      .readAsStringSync();
  final name = value.substring('@color/'.length);
  return RegExp('<color name="$name">([^<]+)</color>')
      .firstMatch(colors)!
      .group(1)!;
}

const _discPathData = 'M24,2 A22,22 0 1 1 24,46 A22,22 0 1 1 24,2 Z';

void main() {
  const glyphPathData = {
    'start':
        'M8.30,7.74 A1.2,1.2 0 0 1 10.12,6.71 L17.12,10.98 A1.2,1.2 0 0 1 '
        '17.12,13.02 L10.12,17.29 A1.2,1.2 0 0 1 8.30,16.26 Z',
    'stop':
        'M14.90,7.00 A1.1,1.1 0 0 1 16.00,5.90 L16.00,5.90 A1.1,1.1 0 0 1 '
        '17.10,7.00 L17.10,17.00 A1.1,1.1 0 0 1 16.00,18.10 L16.00,18.10 '
        'A1.1,1.1 0 0 1 14.90,17.00 Z M6.90,7.00 A1.1,1.1 0 0 1 8.00,5.90 '
        'L8.00,5.90 A1.1,1.1 0 0 1 9.10,7.00 L9.10,17.00 A1.1,1.1 0 0 1 '
        '8.00,18.10 L8.00,18.10 A1.1,1.1 0 0 1 6.90,17.00 Z',
    'toggle':
        'M2.90,12.00 A5.5,5.5 0 0 1 8.40,6.50 L15.60,6.50 A5.5,5.5 0 0 1 '
        '21.10,12.00 L21.10,12.00 A5.5,5.5 0 0 1 15.60,17.50 L8.40,17.50 '
        'A5.5,5.5 0 0 1 2.90,12.00 Z',
  };

  for (final MapEntry(key: name, value: glyph) in glyphPathData.entries) {
    test('ic_shortcut_$name pairs a white field with an ink glyph', () {
      final source = File(
        'android/app/src/main/res/drawable/ic_shortcut_$name.xml',
      ).readAsStringSync();
      final paths = _tags(source, 'path');

      final disc = paths.first;
      expect(_attributeOf(disc, 'pathData'), _discPathData);
      expect(_resolveColor(_attributeOf(disc, 'fillColor')), '#FFFFFF');

      final glyphPath = paths[1];
      expect(_attributeOf(glyphPath, 'pathData'), glyph);
      expect(_attributeOf(glyphPath, 'fillColor'), '#1A1A1A');
      expect(_attributeOf(glyphPath, 'strokeColor'), '#1A1A1A');
    });
  }

  test('ic_shortcut_toggle knob stays knocked out in the field colour', () {
    final source = File(
      'android/app/src/main/res/drawable/ic_shortcut_toggle.xml',
    ).readAsStringSync();
    final knob = _tags(source, 'path')[2];
    expect(
      _attributeOf(knob, 'pathData'),
      'M8.4,9.2 A2.8,2.8 0 1 1 8.4,14.8 A2.8,2.8 0 1 1 8.4,9.2 Z',
    );
    expect(_resolveColor(_attributeOf(knob, 'fillColor')), '#FFFFFF');
  });

  test('shortcut resources carry no upstream purple', () {
    final colors = File('android/app/src/main/res/values/colors.xml')
        .readAsStringSync();
    expect(_resolveColor('@color/shortcut_background'), '#FFFFFF');
    expect(colors.toUpperCase(), isNot(contains('#6666FB')));
    for (final name in ['start', 'stop', 'toggle']) {
      final source = File(
        'android/app/src/main/res/drawable/ic_shortcut_$name.xml',
      ).readAsStringSync();
      expect(source.toUpperCase(), isNot(contains('#6666FB')));
    }
  });
}
