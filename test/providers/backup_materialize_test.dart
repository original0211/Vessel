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
import 'package:riverpod/riverpod.dart';

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
    if (setupState.profileId == _badId) {
      throw StateError('fixture rendering failure');
    }
    return super.renderCustomProfile(
      setupState: setupState,
      patchConfig: patchConfig,
    );
  }
}

const _providerProfile = Profile(
  id: 7101,
  type: ProfileType.url,
  label: 'b6-provider',
  url: 'https://subs.example.invalid/p.yaml',
  autoUpdateDuration: defaultUpdateDuration,
);

const _customId = 7102;
const _badId = 7103;

Profile _customProfile(int id, String label) => Profile(
  id: id,
  type: ProfileType.custom,
  label: label,
  autoUpdate: false,
  autoUpdateDuration: defaultUpdateDuration,
);

const _overrides = ProfileOverrides(
  dns: Dns(
    enable: true,
    enhancedMode: DnsMode.fakeIp,
    fakeIpRange: '198.18.0.1/16',
    nameserver: ['https://dns.example.invalid/dns-query'],
  ),
  dnsOverrideKeys: {
    DnsOverrideKey.enable,
    DnsOverrideKey.enhancedMode,
    DnsOverrideKey.fakeIpRange,
    DnsOverrideKey.nameserver,
  },
  tun: ProfileTun(mtu: 1400),
  tunOverrideKeys: {TunOverrideKey.mtu},
  proxyProviders: {'b6-provider': ProxyProviderOptions(filter: 'Node')},
);

const _proxies = [
  CustomProxy(
    id: 7401,
    definition: {
      'name': 'NodeA',
      'type': 'ss',
      'server': '198.51.100.10',
      'port': 8388,
      'cipher': 'aes-128-gcm',
      'password': 'fixture-a',
    },
  ),
  CustomProxy(
    id: 7402,
    definition: {
      'name': 'NodeB',
      'type': 'ss',
      'server': '198.51.100.11',
      'port': 8388,
      'cipher': 'aes-128-gcm',
      'password': 'fixture-b',
    },
  ),
];

MigrationData _fixture({bool withBad = false}) => MigrationData(
  profiles: [
    _providerProfile,
    _customProfile(_customId, 'b6-custom'),
    if (withBad) _customProfile(_badId, 'b6-bad'),
  ],
  profileOverrides: {_customId: _overrides, if (withBad) _badId: _overrides},
  rules: [
    const Rule(
      id: 7301,
      profileId: _customId,
      ruleAction: RuleAction.DOMAIN,
      content: 'example.invalid',
      ruleTarget: 'Main',
    ),
    const Rule(
      id: 7302,
      profileId: _customId,
      ruleAction: RuleAction.RULE_SET,
      ruleProvider: 'b6-ruleset',
      ruleTarget: 'Main',
    ),
    const Rule(
      id: 7303,
      profileId: _customId,
      ruleAction: RuleAction.MATCH,
      ruleTarget: 'Main',
    ),
    if (withBad)
      const Rule(
        id: 7304,
        profileId: _badId,
        ruleAction: RuleAction.MATCH,
        ruleTarget: 'Main',
      ),
  ],
  disabledRules: const [DisabledRule(profileId: _customId, ruleId: 7301)],
  proxyGroups: [
    const ProxyGroup(
      id: 7201,
      profileId: _customId,
      name: 'Main',
      type: GroupType.Selector,
      proxies: ['NodeA', 'NodeB'],
      use: ['b6-provider'],
    ),
    if (withBad)
      const ProxyGroup(
        id: 7202,
        profileId: _badId,
        name: 'Main',
        type: GroupType.Selector,
        proxies: ['NodeA'],
      ),
  ],
  clashProviders: const [
    ClashProvider(
      id: 7501,
      label: 'b6-ruleset',
      behavior: RuleProviderBehavior.domain,
    ),
  ],
  customProxies: _proxies,
  proxyDialers: const [
    ProxyDialer(profileId: _customId, proxyId: 7401, target: 'NodeB'),
  ],
);

PatchClashConfig _patch() => defaultClashConfig.copyWith(
  tunOverride: const ProfileTun(mtu: 9000),
  tunOverrideKeys: {TunOverrideKey.mtu},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory home;

  setUpAll(() async {
    await mockPreferences({'version': 1});
    await AppLocalizations.load(const Locale('en'));
    home = Directory.systemTemp.createTempSync('b6-materialize-');
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

  Database useDatabase() {
    final db = Database(NativeDatabase.memory());
    database = db;
    addTearDown(db.close);
    return db;
  }

  ProviderContainer buildContainer(
    MigrationData data,
    PatchClashConfig patch, {
    bool failing = false,
  }) {
    final core = _MockCoreHandlerInterface();
    when(
      () => core.getProfileBase(any()),
    ).thenThrow(StateError('a custom profile renders without a base'));
    when(
      () => core.getConfig(any()),
    ).thenThrow(StateError('a custom profile renders without a base'));
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(data.profiles)),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(
          failing ? _FailingSetupAction.new : SetupAction.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(patchClashConfigProvider.notifier).update((_) => patch);
    return container;
  }

  // The custom path's rendering of this fixture, frozen from the tree
  // before the live path stopped rendering custom profiles.
  Future<String> frozenOriginal() async {
    final golden = await File(
      'test/fixtures/b6/materialized_custom_golden.yaml',
    ).readAsString();
    return golden.replaceAll('<HOME>', home.path);
  }

  test('a custom profile lands as a file profile whose snapshot renders '
      'byte for byte like the custom path', () async {
    final data = _fixture();
    final patch = _patch();
    final original = await frozenOriginal();
    expect(original, contains('dialer-proxy: "NodeB"'));
    expect(original, contains('mtu: 1400'));
    expect(original, contains('fake-ip-range: "198.18.0.1/16"'));

    final db = useDatabase();
    final container = buildContainer(data, patch);
    final report = await container
        .read(backupActionProvider.notifier)
        .applyRestore(data, RestoreOption.onlyProfiles);

    expect(report.converted, 1);
    expect(report.failedLabels, isEmpty);
    final stored = await db.profilesDao.query().get();
    final converted = stored.singleWhere(
      (profile) => profile.label == 'b6-custom',
    );
    expect(converted.type, ProfileType.file);
    expect(converted.id, isNot(_customId));
    final snapshot = File(await appPath.getProfilePath('${converted.id}'));
    expect(await snapshot.readAsString(), original);
    expect(
      stored.singleWhere((profile) => profile.id == 7101).type,
      ProfileType.url,
    );
    expect(stored, hasLength(2));
  });

  test('a profile whose rendering fails keeps its data, is named, and does '
      'not come back selected', () async {
    final source = ProviderContainer();
    addTearDown(source.dispose);
    source.read(currentProfileIdProvider.notifier).value = _badId;
    final configMap =
        jsonDecode(jsonEncode(source.read(configProvider).toJson()))
            as Map<String, Object?>;
    final data = _fixture(withBad: true).copyWith(configMap: configMap);

    final db = useDatabase();
    final container = buildContainer(data, _patch(), failing: true);
    final subscription = container.listen(currentProfileIdProvider, (_, _) {});
    addTearDown(subscription.close);
    final report = await container
        .read(backupActionProvider.notifier)
        .applyRestore(data, RestoreOption.all);

    expect(report.converted, 1);
    expect(report.failedLabels, ['b6-bad']);
    final stored = await db.profilesDao.query().get();
    final kept = stored.singleWhere((profile) => profile.id == _badId);
    expect(kept.type, ProfileType.custom);
    expect(container.read(currentProfileIdProvider), isNull);

    // The failed profile's rows stay in the data the converter hands back;
    // only the backup file carries them from here on.
    final result = await materializeRestoredCustomProfiles(
      container.read(setupActionProvider.notifier),
      _fixture(withBad: true),
      patchConfig: _patch(),
      stagingDirPath: null,
    );
    expect(result.report.failedLabels, ['b6-bad']);
    expect(
      result.data.rules.where((rule) => rule.profileId == _badId),
      hasLength(1),
    );
    expect(
      result.data.proxyGroups.where((group) => group.profileId == _badId),
      hasLength(1),
    );
    expect(result.data.customProxies, hasLength(2));
    expect(
      result.data.profiles.singleWhere((profile) => profile.id == _badId).type,
      ProfileType.custom,
    );
    final converted = stored.singleWhere(
      (profile) => profile.label == 'b6-custom',
    );
    expect(converted.type, ProfileType.file);
    expect(
      File(await appPath.getProfilePath('${converted.id}')).existsSync(),
      isTrue,
    );
  });

  test('conversion renders with the patch the backup carries, and a '
      'converted current profile stays current under its new id', () async {
    final source = ProviderContainer();
    addTearDown(source.dispose);
    source
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mixedPort: 7899));
    source.read(currentProfileIdProvider.notifier).value = _customId;
    final configMap =
        jsonDecode(jsonEncode(source.read(configProvider).toJson()))
            as Map<String, Object?>;
    final data = _fixture().copyWith(configMap: configMap);

    final db = useDatabase();
    final container = buildContainer(data, _patch());
    final subscription = container.listen(currentProfileIdProvider, (_, _) {});
    addTearDown(subscription.close);
    final report = await container
        .read(backupActionProvider.notifier)
        .applyRestore(data, RestoreOption.all);

    expect(report.converted, 1);
    final converted = (await db.profilesDao.query().get()).singleWhere(
      (profile) => profile.label == 'b6-custom',
    );
    final snapshot = await File(
      await appPath.getProfilePath('${converted.id}'),
    ).readAsString();
    expect(snapshot, contains('mixed-port: 7899'));
    expect(container.read(currentProfileIdProvider), converted.id);
  });
}
