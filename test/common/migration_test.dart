import 'dart:convert';

import 'package:kfusion/common/constant.dart';
import 'package:kfusion/common/migration.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration', () {
    test('returns current config without rewriting storage', () async {
      final configMap = _createConfigMap();
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: Migration.currentVersion,
      );

      final config = await Migration(store: store).run();

      expect(config, Config.realFromJson(configMap));
      expect(store.events, ['getConfigMap', 'getVersion']);
    });

    test('clears the WebDAV settings an older version stored', () async {
      final configMap = _createConfigMap()
        ..['davProps'] = <String, Object?>{
          'uri': 'https://example.com/dav',
          'user': 'user',
          'password': 'secret',
          'fileName': 'backup.zip',
        };
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: Migration.currentVersion,
      );

      final config = await Migration(store: store).run();

      expect(config, Config.realFromJson(configMap));
      expect(store.savedConfig, config);
      expect(store.events, ['getConfigMap', 'getVersion', 'saveConfig']);
      final savedConfigMap =
          jsonDecode(jsonEncode(store.savedConfig)) as Map<String, Object?>;
      expect(savedConfigMap.containsKey('davProps'), isFalse);
    });

    test(
      'commits v0 cleanup and version only after migrated data is saved',
      () async {
        final configMap = <String, Object?>{
          'proxiesStyle': <String, Object?>{},
          'dav': <String, Object?>{
            'uri': 'https://example.com/dav',
            'user': 'user',
            'password': 'secret',
          },
        };
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: 0,
          clashConfigMap: <String, Object?>{'mixed-port': 7890},
        );
        final migration = Migration(
          store: store,
          migrateV0: (configMap) async {
            store.events.add('migrateV0');
            expect(configMap['patchClashConfig'], store.clashConfigMap);
            return MigrationData(configMap: _createConfigMap());
          },
        );

        await migration.run();

        expect(store.events, [
          'getConfigMap',
          'getVersion',
          'getClashConfigMap',
          'migrateV0',
          'restore',
          'saveConfig',
          'clearClashConfig',
          'setVersion',
        ]);
        expect(store.didClearClashConfig, isTrue);
        expect(store.version, Migration.currentVersion);
      },
    );

    test(
      'preserves legacy clash config when current-shaped data has version zero',
      () async {
        final configMap = _createConfigMap()..remove('patchClashConfig');
        final clashConfigMap = _createClashConfigMap(mixedPort: 1234);
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: 0,
          clashConfigMap: clashConfigMap,
        );

        final config = await Migration(store: store).run();

        expect(config.patchClashConfig.mixedPort, 1234);
        expect(store.savedConfig?.patchClashConfig.mixedPort, 1234);
        expect(store.didClearClashConfig, isTrue);
        expect(store.events, [
          'getConfigMap',
          'getVersion',
          'getClashConfigMap',
          'restore',
          'saveConfig',
          'clearClashConfig',
          'setVersion',
        ]);
      },
    );

    test('does not clear legacy clash config when saving fails', () async {
      final configMap = _createConfigMap()..remove('patchClashConfig');
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: 0,
        clashConfigMap: _createClashConfigMap(mixedPort: 1234),
        configSaveResult: false,
      );

      await expectLater(
        Migration(store: store).run(),
        throwsA(isA<StateError>()),
      );

      expect(store.didClearClashConfig, isFalse);
      expect(store.version, 0);
      expect(store.events, [
        'getConfigMap',
        'getVersion',
        'getClashConfigMap',
        'restore',
        'saveConfig',
        'isAvailable',
      ]);
    });

    test('starts with defaults when the store cannot be opened', () async {
      final store = _FakeMigrationStore(
        configMap: null,
        version: 0,
        configSaveResult: false,
        available: false,
      );

      final config = await Migration(store: store).run();

      expect(config, isNotNull);
      expect(store.didClearClashConfig, isFalse);
      expect(store.version, 0);
      expect(store.events, [
        'getConfigMap',
        'getVersion',
        'getClashConfigMap',
        'restore',
        'saveConfig',
        'isAvailable',
      ]);
    });

    group('upgrade', () {
      Map<String, Object?> customized() =>
          _createConfigMap()
            ..['themeProps'] = {
              'primaryColor': 0xFF123456,
              'primaryColors': [0xFF795548, 0xFF123456],
              'schemeVariant': 'tonalSpot',
              'themeMode': 'dark',
              'pureBlack': true,
              'liquidGlass': true,
              'systemFontFamily': 'Beta Serif',
            };

      test('stored theme colors fall away and the rest is kept', () async {
        final store = _FakeMigrationStore(
          configMap: customized(),
          version: Migration.currentVersion,
          upgradeVersion: 0,
        );

        final config = await Migration(store: store).run();

        final theme = config.themeProps;
        expect(theme.themeMode, ThemeMode.dark);
        expect(theme.pureBlack, isTrue);
        expect(theme.liquidGlass, LiquidGlassMode.standard);
        final themeJson = theme.toJson();
        for (final key in [
          'primaryColor',
          'primaryColors',
          'colorStyle',
          'schemeVariant',
        ]) {
          expect(themeJson, isNot(contains(key)), reason: key);
        }
        expect(store.savedConfig, isNull);
        expect(store.version, Migration.currentVersion);
        expect(store.upgradeVersion, Migration.upgradeVersion);
        expect(store.events, [
          'getConfigMap',
          'getVersion',
          'setUpgradeVersion',
        ]);

        final later = _FakeMigrationStore(
          configMap: jsonDecode(
            jsonEncode(config.copyWith.themeProps(themeMode: ThemeMode.light)),
          ),
          version: store.version,
          upgradeVersion: store.upgradeVersion,
        );
        final kept = await Migration(store: later).run();

        expect(kept.themeProps.themeMode, ThemeMode.light);
        expect(later.events, ['getConfigMap', 'getVersion']);
      });

      test(
        'glass settles on standard now the ultra tier has retired',
        () async {
          Future<LiquidGlassMode> upgrade(String mode, int from) async {
            final configMap = _createConfigMap();
            (configMap['themeProps']! as Map<String, Object?>)['liquidGlass'] =
                mode;
            final store = _FakeMigrationStore(
              configMap: configMap,
              version: Migration.currentVersion,
              upgradeVersion: from,
            );
            return (await Migration(store: store).run()).themeProps.liquidGlass;
          }

          expect(await upgrade('standard', 1), LiquidGlassMode.standard);
          expect(await upgrade('none', 1), LiquidGlassMode.none);
          expect(await upgrade('standard', 2), LiquidGlassMode.standard);
          expect(await upgrade('ultra', 2), LiquidGlassMode.standard);
        },
      );

      test('resets changed ports to the fixed defaults once', () async {
        final configMap = _createConfigMap();
        (configMap['patchClashConfig']! as Map<String, Object?>).addAll({
          'mixed-port': 8899,
          'port': 8080,
          'socks-port': 1080,
          'redir-port': 8081,
          'tproxy-port': 8082,
        });
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 2,
        );

        final config = await Migration(store: store).run();

        final patch = config.patchClashConfig;
        expect(patch.mixedPort, defaultMixedPort);
        expect(patch.port, 0);
        expect(patch.socksPort, 0);
        expect(patch.redirPort, 0);
        expect(patch.tproxyPort, 0);
        expect(store.upgradeVersion, Migration.upgradeVersion);
      });

      test('renames a TUN device still holding the retired default', () async {
        final configMap = _createConfigMap();
        final patch = configMap['patchClashConfig']! as Map<String, Object?>;
        (patch['tun']! as Map<String, Object?>)['device'] = 'KFusion';
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 3,
        );

        final config = await Migration(store: store).run();

        expect(config.patchClashConfig.tun.device, appName);
        expect(store.savedConfig?.patchClashConfig.tun.device, appName);
        expect(store.upgradeVersion, Migration.upgradeVersion);
      });

      test('keeps a TUN device name the user picked', () async {
        final configMap = _createConfigMap();
        final patch = configMap['patchClashConfig']! as Map<String, Object?>;
        (patch['tun']! as Map<String, Object?>)['device'] = 'Homelab';
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 3,
        );

        final config = await Migration(store: store).run();

        expect(config.patchClashConfig.tun.device, 'Homelab');
        expect(store.savedConfig, isNull);
        expect(store.upgradeVersion, Migration.upgradeVersion);
      });

      test('leaves an absent TUN device unwritten', () async {
        final configMap = _createConfigMap();
        final patch = configMap['patchClashConfig']! as Map<String, Object?>;
        (patch['tun']! as Map<String, Object?>).remove('device');
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 3,
        );

        final config = await Migration(store: store).run();

        expect(config.patchClashConfig.tun.device, appName);
        expect(store.savedConfig, isNull);
        expect(store.upgradeVersion, Migration.upgradeVersion);
      });

      test('renames the TUN device once and later launches skip it', () async {
        final configMap = _createConfigMap();
        final patch = configMap['patchClashConfig']! as Map<String, Object?>;
        (patch['tun']! as Map<String, Object?>)['device'] = 'KFusion';
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 3,
        );

        final migrated = await Migration(store: store).run();

        final later = _FakeMigrationStore(
          configMap: jsonDecode(jsonEncode(migrated)) as Map<String, Object?>,
          version: Migration.currentVersion,
          upgradeVersion: store.upgradeVersion,
        );
        final kept = await Migration(store: later).run();

        expect(kept.patchClashConfig.tun.device, appName);
        expect(later.savedConfig, isNull);
        expect(later.events, ['getConfigMap', 'getVersion']);
      });

      test('a new install only records it', () async {
        final store = _FakeMigrationStore(
          configMap: null,
          version: 0,
          upgradeVersion: 0,
        );

        final config = await Migration(store: store).run();

        expect(config.themeProps, defaultThemeProps);
        expect(store.upgradeVersion, Migration.upgradeVersion);
        expect(
          store.events.where((event) => event == 'saveConfig'),
          hasLength(1),
        );
      });

      test('waits for the next launch when saving fails', () async {
        final configMap = _createConfigMap();
        (configMap['patchClashConfig']! as Map<String, Object?>)['mixed-port'] =
            8899;
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          upgradeVersion: 2,
          configSaveResult: false,
        );

        final config = await Migration(store: store).run();

        expect(config.patchClashConfig.mixedPort, 8899);
        expect(store.upgradeVersion, 2);
      });
    });

    test('keeps what it can read of a damaged current config', () async {
      final configMap = _createConfigMap()
        ..['currentProfileId'] = 7
        ..['excludeSSIDs'] = 'home';
      final store = _FakeMigrationStore(
        configMap: configMap,
        version: Migration.currentVersion,
      );

      final config = await Migration(store: store).run();

      expect(config.currentProfileId, 7);
      expect(config.excludeSSIDs, isEmpty);
      expect(store.events, ['getConfigMap', 'getVersion']);
    });

    test(
      'keeps the current version when clearing WebDAV settings fails',
      () async {
        final configMap = _createConfigMap()
          ..['davProps'] = <String, Object?>{
            'uri': 'https://example.com/dav',
            'user': 'user',
            'password': 'secret',
          };
        final store = _FakeMigrationStore(
          configMap: configMap,
          version: Migration.currentVersion,
          configSaveResult: false,
        );

        await expectLater(
          Migration(store: store).run(),
          throwsA(isA<StateError>()),
        );

        expect(store.events, ['getConfigMap', 'getVersion', 'saveConfig']);
        expect(store.version, Migration.currentVersion);
      },
    );
  });
}

Map<String, Object?> _createConfigMap() {
  return jsonDecode(jsonEncode(const Config(themeProps: defaultThemeProps)))
      as Map<String, Object?>;
}

Map<String, Object?> _createClashConfigMap({required int mixedPort}) {
  return jsonDecode(jsonEncode(PatchClashConfig(mixedPort: mixedPort)))
      as Map<String, Object?>;
}

class _FakeMigrationStore implements MigrationStore {
  final Map<String, Object?>? configMap;
  final Map<String, Object?>? clashConfigMap;
  final bool configSaveResult;
  final bool available;
  final List<String> events = [];

  int version;
  int upgradeVersion;
  Config? savedConfig;
  MigrationData? restoredData;
  bool didClearClashConfig = false;

  _FakeMigrationStore({
    required this.configMap,
    required this.version,
    this.upgradeVersion = Migration.upgradeVersion,
    this.clashConfigMap,
    this.configSaveResult = true,
    this.available = true,
  });

  @override
  Future<bool> get isAvailable async {
    events.add('isAvailable');
    return available;
  }

  @override
  Future<void> clearClashConfig() async {
    events.add('clearClashConfig');
    didClearClashConfig = true;
  }

  @override
  Future<Map<String, Object?>?> getClashConfigMap() async {
    events.add('getClashConfigMap');
    return clashConfigMap;
  }

  @override
  Future<Map<String, Object?>?> getConfigMap() async {
    events.add('getConfigMap');
    return configMap;
  }

  @override
  Future<int> getVersion() async {
    events.add('getVersion');
    return version;
  }

  @override
  Future<void> restore(MigrationData data) async {
    events.add('restore');
    restoredData = data;
  }

  @override
  Future<bool> saveConfig(Config config) async {
    events.add('saveConfig');
    savedConfig = config;
    return configSaveResult;
  }

  @override
  Future<void> setVersion(int version) async {
    events.add('setVersion');
    this.version = version;
  }

  @override
  Future<int> getUpgradeVersion() async => upgradeVersion;

  @override
  Future<void> setUpgradeVersion(int version) async {
    events.add('setUpgradeVersion');
    upgradeVersion = version;
  }
}
