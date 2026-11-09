import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/database/database.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/l10n/l10n.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _FailingSetupAction extends SetupAction {
  @override
  Future<BuiltProfile> renderCustomProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) {
    if (setupState.profileId == _customDbId) {
      throw StateError('fixture rendering failure');
    }
    return super.renderCustomProfile(
      setupState: setupState,
      patchConfig: patchConfig,
    );
  }
}

const _standardId = 101;
const _customDbId = 102;
const _scriptRowId = 103;

const _standardYaml = 'proxies: []\nproxy-groups: []\nrules: []\n';

/// Writes the retired physical shape (the four per-profile tables and the
/// four profile columns schema 22 no longer declares) into the database
/// file at [path], with a custom profile, a script-typed standard profile,
/// and the custom profile's rows.
void _seedLegacyShape(String path) {
  final raw = sqlite.sqlite3.open(path);
  raw.execute(
    'ALTER TABLE profiles ADD COLUMN "extend_type" '
    "TEXT NOT NULL DEFAULT 'standard'",
  );
  raw.execute('ALTER TABLE profiles ADD COLUMN "script_id" INTEGER NULL');
  raw.execute('ALTER TABLE profiles ADD COLUMN "match_target" TEXT NULL');
  raw.execute('ALTER TABLE profiles ADD COLUMN "overrides" TEXT NULL');
  raw.execute('''
    CREATE TABLE "rules" (
      "id" INTEGER NOT NULL,
      "profile_id" INTEGER NULL,
      "rule_action" TEXT NOT NULL,
      "content" TEXT NULL,
      "rule_target" TEXT NULL,
      "rule_provider" TEXT NULL,
      "sub_rule" TEXT NULL,
      "no_resolve" INTEGER NOT NULL DEFAULT 0,
      "src" INTEGER NOT NULL DEFAULT 0,
      "order" TEXT NULL,
      PRIMARY KEY ("id")
    )
  ''');
  raw.execute('''
    CREATE TABLE "disabled_rules" (
      "profile_id" INTEGER NOT NULL,
      "rule_id" INTEGER NOT NULL,
      PRIMARY KEY ("profile_id", "rule_id")
    )
  ''');
  raw.execute('''
    CREATE TABLE "proxy_groups" (
      "id" INTEGER NOT NULL,
      "profile_id" INTEGER NOT NULL,
      "name" TEXT NOT NULL,
      "type" TEXT NOT NULL,
      "proxies" TEXT NULL,
      "use" TEXT NULL,
      "definition" TEXT NOT NULL DEFAULT '{}',
      "order" TEXT NULL,
      PRIMARY KEY ("id")
    )
  ''');
  raw.execute('''
    CREATE TABLE "custom_proxies" (
      "id" INTEGER NOT NULL,
      "definition" TEXT NOT NULL,
      "order" TEXT NULL,
      "empty_options" TEXT NULL,
      PRIMARY KEY ("id")
    )
  ''');
  raw.execute('''
    CREATE TABLE "proxy_dialers" (
      "profile_id" INTEGER NOT NULL,
      "proxy_id" INTEGER NOT NULL,
      "target" TEXT NOT NULL,
      PRIMARY KEY ("profile_id", "proxy_id")
    )
  ''');
  final overrides = jsonEncode(
    const ProfileOverrides(
      tun: ProfileTun(mtu: 1400),
      tunOverrideKeys: {TunOverrideKey.mtu},
    ).toJson(),
  );
  raw.execute(
    'INSERT INTO profiles (id, type, label, url, extend_type, '
    'auto_update_duration_millis, auto_update, selected_map, unfold_set, '
    'overrides) VALUES '
    "($_customDbId, 'custom', 'Mine', '', 'script', 0, 0, '{}', '[]', ?), "
    "($_scriptRowId, 'url', 'Script typed', 'https://example.com/sub', "
    "'script', 0, 0, '{}', '[]', NULL)",
    [overrides],
  );
  raw.execute(
    'INSERT INTO proxy_groups (id, profile_id, name, type, proxies) '
    'VALUES (1, $_customDbId, \'Main\', \'select\', \'["NodeA", "NodeB"]\')',
  );
  raw.execute(
    'INSERT INTO rules (id, profile_id, rule_action, rule_target) '
    "VALUES (1, $_customDbId, 'MATCH', 'Main')",
  );
  raw.execute(
    'INSERT INTO disabled_rules (profile_id, rule_id) '
    'VALUES ($_customDbId, 1)',
  );
  raw.execute(
    'INSERT INTO custom_proxies (id, definition) VALUES '
    '''(1, '{"name":"NodeA","type":"ss","server":"198.51.100.10","port":8388,"cipher":"aes-128-gcm","password":"fixture-a"}'), '''
    '''(2, '{"name":"NodeB","type":"ss","server":"198.51.100.11","port":8388,"cipher":"aes-128-gcm","password":"fixture-b"}')''',
  );
  raw.execute(
    'INSERT INTO proxy_dialers (profile_id, proxy_id, target) '
    "VALUES ($_customDbId, 1, 'NodeB')",
  );
  raw.execute('PRAGMA user_version = 21');
  raw.close();
}

Set<String> _tablesOf(String path) {
  final raw = sqlite.sqlite3.open(path);
  final tables = {
    for (final row in raw.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ))
      row['name'] as String,
  };
  raw.close();
  return tables;
}

Set<String> _profileColumnsOf(String path) {
  final raw = sqlite.sqlite3.open(path);
  final columns = {
    for (final row in raw.select('PRAGMA table_info(profiles)'))
      row['name'] as String,
  };
  raw.close();
  return columns;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;

  setUpAll(() async {
    await mockPreferences({'version': 1});
    await AppLocalizations.load(const Locale('en'));
    home = Directory.systemTemp.createTempSync('b6-legacy-db-');
    await useAppPaths(home);
    globalState.packageInfo = PackageInfo(
      appName: 'Vessel',
      packageName: 'com.kfusion.app',
      version: '0.0.0',
      buildNumber: '0',
    );
  });

  tearDownAll(() {
    if (home.existsSync()) home.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer({bool failing = false}) {
    final core = _MockCoreHandlerInterface();
    when(
      () => core.getProfileBase(any()),
    ).thenThrow(StateError('a custom profile renders without a base'));
    when(
      () => core.getConfig(any()),
    ).thenThrow(StateError('a custom profile renders without a base'));
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles(const [
            Profile(
              id: _standardId,
              label: 'Standard',
              autoUpdateDuration: Duration.zero,
            ),
            Profile(
              id: _customDbId,
              label: 'Mine',
              type: ProfileType.custom,
              autoUpdateDuration: Duration.zero,
            ),
            Profile(
              id: _scriptRowId,
              label: 'Script typed',
              type: ProfileType.url,
              url: 'https://example.com/sub',
              autoUpdateDuration: Duration.zero,
            ),
          ]),
        ),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(
          failing ? _FailingSetupAction.new : SetupAction.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<String> seedDatabaseFile() async {
    final path = p.join(home.path, 'legacy.sqlite');
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    final created = Database(NativeDatabase(File(path)));
    await created.profilesDao.putAll([
      const Profile(
        id: _standardId,
        label: 'Standard',
        autoUpdateDuration: Duration.zero,
      ).toCompanion(),
    ]);
    await created.close();
    _seedLegacyShape(path);
    final standardFile = File(await appPath.getProfilePath('$_standardId'));
    standardFile
      ..createSync(recursive: true)
      ..writeAsStringSync(_standardYaml);
    return path;
  }

  Future<Database> openSeeded(String path) async {
    final db = Database(NativeDatabase(File(path)));
    database = db;
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('a v21 database converts its custom profiles and retires the '
      'legacy shape', () async {
    final path = await seedDatabaseFile();
    final db = await openSeeded(path);
    expect(await db.hasLegacyProfileData, isTrue);

    final container = buildContainer();
    final (:report, :currentProfileId) = await convertDatabaseCustomProfiles(
      container.read(setupActionProvider.notifier),
      patchConfig: defaultClashConfig,
      currentProfileId: _customDbId,
    );

    expect(report.converted, 1);
    expect(report.failedLabels, isEmpty);
    final stored = await db.profilesDao.query().get();
    expect(stored, hasLength(3));
    final converted = stored.singleWhere((profile) => profile.label == 'Mine');
    expect(converted.type, ProfileType.file);
    expect(converted.id, isNot(_customDbId));
    expect(currentProfileId, converted.id);
    final snapshot = await File(
      await appPath.getProfilePath('${converted.id}'),
    ).readAsString();
    expect(snapshot, contains('mtu: 1400'));
    expect(snapshot, contains('dialer-proxy: "NodeB"'));
    final standard = stored.singleWhere((profile) => profile.id == _standardId);
    expect(standard.label, 'Standard');
    expect(
      await File(await appPath.getProfilePath('$_standardId')).readAsString(),
      _standardYaml,
    );
    expect(
      stored.singleWhere((profile) => profile.id == _scriptRowId).type,
      ProfileType.url,
    );
    expect(await db.hasLegacyProfileData, isFalse);
    expect(
      _tablesOf(path),
      isNot(
        anyOf(
          contains('rules'),
          contains('disabled_rules'),
          contains('proxy_groups'),
          contains('custom_proxies'),
          contains('proxy_dialers'),
        ),
      ),
    );
    expect(
      _profileColumnsOf(path),
      isNot(
        anyOf(
          contains('extend_type'),
          contains('script_id'),
          contains('match_target'),
          contains('overrides'),
        ),
      ),
    );
  });

  test('a failed conversion keeps the legacy shape for the next launch, '
      'and a retry finishes it', () async {
    final path = await seedDatabaseFile();
    final db = await openSeeded(path);

    final failing = buildContainer(failing: true);
    final first = await convertDatabaseCustomProfiles(
      failing.read(setupActionProvider.notifier),
      patchConfig: defaultClashConfig,
      currentProfileId: _customDbId,
    );
    expect(first.report.converted, 0);
    expect(first.report.failedLabels, ['Mine']);
    expect(first.currentProfileId, isNull);
    expect(await db.hasLegacyProfileData, isTrue);
    expect(
      (await db.profilesDao.query().get()).map((profile) => profile.type),
      contains(ProfileType.custom),
    );

    final container = buildContainer();
    final second = await convertDatabaseCustomProfiles(
      container.read(setupActionProvider.notifier),
      patchConfig: defaultClashConfig,
      currentProfileId: null,
    );
    expect(second.report.converted, 1);
    expect(await db.hasLegacyProfileData, isFalse);
    expect(_tablesOf(path), isNot(contains('proxy_groups')));
  });

  test('a database without legacy data is left alone', () async {
    final db = Database(NativeDatabase.memory());
    database = db;
    addTearDown(db.close);

    final container = buildContainer();
    final (:report, :currentProfileId) = await convertDatabaseCustomProfiles(
      container.read(setupActionProvider.notifier),
      patchConfig: defaultClashConfig,
      currentProfileId: 7,
    );

    expect(report.isEmpty, isTrue);
    expect(currentProfileId, 7);
  });
}
