import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/core/controller.dart';
import 'package:kfusion/core/interface.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/config_hub.dart';
import 'package:kfusion/l10n/l10n.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_profiles.dart';

// Equivalence net for the B6 cut (B6-SCOPE section 4): standard profiles
// rendered on the unmodified tree are pinned as goldens, and every later
// B6 pen must reproduce them byte for byte. Regenerate only on the tree
// the net was designed against, never to absorb a rendering change:
//   B6_REGEN=1 flutter test test/providers/b6_equivalence_test.dart
class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

const _fixturesDir = 'test/fixtures/b6';
const _goldenDir = 'test/fixtures/b6/golden';
const _profilesToken = '<PROFILES>';
final _regen = Platform.environment['B6_REGEN'] == '1';

Object? _deepConvert(Object? value) {
  if (value is YamlMap) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _deepConvert(entry.value),
    };
  }
  if (value is YamlList) {
    return [for (final item in value) _deepConvert(item)];
  }
  return value;
}

Map<String, dynamic> _fixtureMap(String name) {
  final text = File('$_fixturesDir/$name').readAsStringSync();
  return _deepConvert(loadYaml(text)) as Map<String, dynamic>;
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> map) {
  return jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
}

Object? _sortDeep(Object? value) {
  if (value is Map) {
    final keys = [for (final key in value.keys) key.toString()]..sort();
    return <String, Object?>{
      for (final key in keys) key: _sortDeep(value[key]),
    };
  }
  if (value is List) {
    return [for (final item in value) _sortDeep(item)];
  }
  return value;
}

// The shape of the patch surface the B6 scan found in the field (tun,
// dns fake-ip, geox), with fictional values throughout.
PatchClashConfig _fictionalPatch() {
  final patch = PatchClashConfig.fromJson(<String, Object?>{
    'mixed-port': 7890,
    'mode': 'rule',
    'log-level': 'info',
    'find-process-mode': 'always',
    'interface-name-mode': 'clear',
    'keep-alive-interval': 30,
    'keep-alive-idle': 15,
    'unified-delay': true,
    'tcp-concurrent': true,
    'ipv6': true,
    'tun': <String, Object?>{
      'enable': true,
      'device': 'Vessel',
      'stack': 'mixed',
      'mtu': 9000,
      'congestion-controller': 'bbr',
    },
    'dns': <String, Object?>{
      'enable': true,
      'use-hosts': true,
      'use-system-hosts': true,
      'ipv6-timeout': 100,
      'cache-algorithm': 'lru',
      'cache-max-size': 4096,
      'default-nameserver': [
        '203.0.113.1',
        '203.0.113.2',
        '198.51.100.1',
        '198.51.100.2',
      ],
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'fake-ip-filter': ['*.lan', 'localhost', 'time.example.invalid'],
      'fake-ip-filter-mode': 'blacklist',
      'fake-ip-ttl': 1,
      'nameserver': [
        'https://dns.example.invalid/dns-query',
        'tls://203.0.113.53:853',
      ],
      'fallback-filter': <String, Object?>{'geoip': true, 'geoip-code': 'CN'},
    },
    'tun-override': <String, Object?>{
      'mtu': 9000,
      'congestion-controller': 'bbr',
      'dns-hijack': ['any:53'],
      'udp-timeout': 300,
    },
    'geox-url': <String, Object?>{
      'mmdb': 'https://geo.example.invalid/country.mmdb',
      'asn': 'https://geo.example.invalid/asn.mmdb',
      'geoip': 'https://geo.example.invalid/geoip.dat',
      'geosite': 'https://geo.example.invalid/geosite.dat',
    },
    'geodata-loader': 'memconservative',
    'geo-auto-update': true,
    'geo-update-interval': 24,
  });
  return patch.copyWith(
    dnsOverrideKeys: {
      DnsOverrideKey.useHosts,
      DnsOverrideKey.useSystemHosts,
      DnsOverrideKey.ipv6Timeout,
      DnsOverrideKey.cacheAlgorithm,
      DnsOverrideKey.cacheMaxSize,
      DnsOverrideKey.defaultNameserver,
      DnsOverrideKey.enhancedMode,
      DnsOverrideKey.fakeIpRange,
      DnsOverrideKey.fakeIpFilter,
      DnsOverrideKey.fakeIpFilterMode,
      DnsOverrideKey.fakeIpTtl,
      DnsOverrideKey.nameserver,
      DnsOverrideKey.fallbackFilterGeoip,
      DnsOverrideKey.fallbackFilterGeoipCode,
    },
    tunOverrideKeys: {
      TunOverrideKey.mtu,
      TunOverrideKey.congestionController,
      TunOverrideKey.dnsHijack,
      TunOverrideKey.udpTimeout,
    },
  );
}

// Mirrors the Core's handleGetProfileBase: the bulk sections stay behind,
// everything else becomes the head the host renders an overlay from.
ProfileBase _baseOf(Map<String, dynamic> full, String digest) {
  final head = _deepCopy(full)
    ..remove('proxies')
    ..remove('proxy-groups')
    ..remove('rules')
    ..remove('sub-rules');
  final rules = (full['rules'] as List?) ?? const [];
  return ProfileBase(
    config: head,
    digest: digest,
    matchRules: [
      for (final rule in rules)
        if (rule.toString().startsWith('MATCH')) rule.toString(),
    ],
    proxies: (full['proxies'] as List?)?.length ?? 0,
    proxyGroups: (full['proxy-groups'] as List?)?.length ?? 0,
    rules: rules.length,
  );
}

class _Case {
  const _Case({
    required this.name,
    required this.fixture,
    required this.profile,
    required this.digest,
  });

  final String name;
  final String fixture;
  final Profile profile;
  final String digest;
}

const _cases = <_Case>[
  _Case(
    name: 'a',
    fixture: 'fixture_a.yaml',
    profile: Profile(
      id: 7001,
      type: ProfileType.url,
      label: 'b6-a',
      url: 'https://subs.example.invalid/a.yaml',
      autoUpdateDuration: defaultUpdateDuration,
    ),
    digest: 'b6-digest-a',
  ),
  _Case(
    name: 'b',
    fixture: 'fixture_b.yaml',
    profile: Profile(
      id: 7002,
      type: ProfileType.file,
      label: 'b6-b',
      autoUpdateDuration: defaultUpdateDuration,
    ),
    digest: 'b6-digest-b',
  ),
  _Case(
    name: 'c',
    fixture: 'fixture_c.yaml',
    profile: Profile(
      id: 7003,
      type: ProfileType.url,
      label: 'b6-c',
      url: 'https://subs.example.invalid/c.yaml',
      autoUpdateDuration: defaultUpdateDuration,
    ),
    digest: 'b6-digest-c',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PatchClashConfig patch;
  final manifest = <String, Object?>{};

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('b6_equivalence');
    await useAppPaths(tempDir);
    await AppLocalizations.load(const Locale('en'));
    globalState.packageInfo = PackageInfo(
      appName: 'Vessel',
      packageName: 'com.kfusion.app',
      version: '0.0.0',
      buildNumber: '0',
    );
    patch = _fictionalPatch();
  });

  tearDownAll(() async {
    if (_regen) {
      final file = File('$_goldenDir/manifest.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_sortDeep(manifest)),
      );
    }
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> checkGolden(
    String goldenName,
    String text,
    Map<String, Object?> meta,
  ) async {
    final file = File('$_goldenDir/$goldenName');
    final fullMeta = <String, Object?>{...meta, 'textMd5': text.toMd5()};
    if (_regen) {
      await file.parent.create(recursive: true);
      await file.writeAsString(text);
      manifest[goldenName] = fullMeta;
      return;
    }
    expect(
      file.readAsStringSync(),
      text,
      reason: '$goldenName drifted from its golden rendering',
    );
    final recorded =
        jsonDecode(File('$_goldenDir/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final recordedMeta = recorded[goldenName] as Map<String, dynamic>;
    for (final entry in fullMeta.entries) {
      expect(
        recordedMeta[entry.key],
        entry.value,
        reason: '$goldenName ${entry.key} drifted from its golden value',
      );
    }
  }

  Future<({BuiltProfile built, RealProfile full})> render(
    _Case testCase,
  ) async {
    final fullMap = _fixtureMap(testCase.fixture);
    final core = _MockCoreHandlerInterface();
    when(
      () => core.getProfileBase(any()),
    ).thenAnswer((_) async => _baseOf(fullMap, testCase.digest));
    when(
      () => core.getConfig(any()),
    ).thenThrow(StateError('a standard profile must render from its base'));
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([testCase.profile])),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(SetupAction.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(patchClashConfigProvider.notifier).update((_) => patch);
    final setupState = await container.read(
      setupStateProvider(testCase.profile.id).future,
    );
    final built = await container
        .read(setupActionProvider.notifier)
        .getProfile(setupState: setupState, patchConfig: patch);
    verifyNever(() => core.getConfig(any()));
    final network = container.read(networkSettingProvider);
    final full = await makeRealProfileTask(
      MakeRealProfileState(
        rules: const [],
        proxyGroups: const [],
        profilesPath: '/b6-profiles',
        profileId: testCase.profile.id,
        rawConfig: _deepCopy(fullMap),
        realPatchConfig: patch,
        overrides: setupState.overrides,
        bypassPrivateRoute: network.bypassPrivateRoute,
        keepEmptyDnsOverrides: true,
        appendSystemDns: network.appendSystemDns,
        defaultUA: globalState.packageInfo.ua,
        safeMode: container.read(safeModeProvider),
      ),
    );
    return (built: built, full: full);
  }

  test('the fictional patch parses with its override surface intact', () {
    expect(patch.mixedPort, 7890);
    expect(patch.tun.mtu, 9000);
    expect(patch.tun.stack, TunStack.mixed);
    expect(patch.dns.enhancedMode, DnsMode.fakeIp);
    expect(patch.dns.fakeIpRange, '198.18.0.1/16');
    expect(patch.tunOverride.mtu, 9000);
    expect(patch.dnsOverrideKeys, contains(DnsOverrideKey.fakeIpRange));
    expect(patch.tunOverrideKeys, contains(TunOverrideKey.mtu));
  });

  for (final testCase in _cases) {
    test(
      'case ${testCase.name}: rendering matches the golden byte for byte',
      () async {
        final (:built, :full) = await render(testCase);
        final overlayText = built.yaml.replaceAll(tempDir.path, _profilesToken);
        final fullText = full.yaml.replaceAll('/b6-profiles', _profilesToken);
        await checkGolden('${testCase.name}_overlay.yaml', overlayText, {
          'counts': {
            'groups': built.counts.groups,
            'proxies': built.counts.proxies,
            'rules': built.counts.rules,
          },
          'basePath': built.base?.path.replaceAll(tempDir.path, _profilesToken),
          // The combined md5 is only reproducible when the overlay holds
          // no host path (case c confines provider paths under the host
          // profiles directory); there the normalized text is the anchor.
          'builtMd5': overlayText == built.yaml ? built.md5 : null,
        });
        await checkGolden('${testCase.name}_full.yaml', fullText, {
          'counts': {
            'groups': full.counts.groups,
            'proxies': full.counts.proxies,
            'rules': full.counts.rules,
          },
          'taskMd5': full.md5,
        });
        expect(full.counts.proxies, greaterThan(0));
        expect(full.counts.groups, greaterThan(0));
        expect(full.counts.rules, greaterThan(0));
      },
    );
  }

  test(
    'case a: the global patch fingerprints reach the full rendering',
    () async {
      final (:built, :full) = await render(_cases.first);
      expect(full.yaml, contains('mtu: 9000'));
      expect(full.yaml, contains('fake-ip-range: "198.18.0.1/16"'));
      expect(full.yaml, contains('mixed-port: 7890'));
      expect(built.yaml, contains('fake-ip-range: "198.18.0.1/16"'));
    },
  );

  test(
    'control: the sing-box rendering of case a matches its golden',
    () async {
      final result = renderSingBoxFromClash(
        _deepCopy(_fixtureMap('fixture_a.yaml')),
        secret: 'b6-secret',
        mixedPort: 7890,
      );
      final canonical = const JsonEncoder.withIndent(
        '  ',
      ).convert(_sortDeep(result.config));
      await checkGolden('a_singbox.json', canonical, {
        'degradations': [for (final d in result.degradations) d.message],
      });
    },
  );
}
