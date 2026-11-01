import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The retired theme color pipeline's symbols stay out of hand-written lib.
void main() {
  test('theme color pipeline symbols have no residual in lib', () {
    const retired = [
      'ColorStyle',
      'primaryColor',
      'primaryColors',
      'defaultPrimaryColors',
      'ThemeColorsSelectorState',
      'dynamicColorProvider',
      'DynamicColorSeeds',
      'DynamicColorPlugin',
    ];
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      if (file.path.contains('/generated/') ||
          file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final symbol in retired) {
        if (source.contains(symbol)) {
          offenders.add('${file.path}: $symbol');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
