import 'package:kfusion/features/config_hub/singbox_speedtest.dart';
import 'package:flutter_test/flutter_test.dart';

const _clashProfile = '''
proxies:
  - name: JP-03
    type: ss
    server: 203.0.113.1
    port: 8388
    cipher: aes-128-gcm
    password: pw1
  - name: HK-01
    type: socks5
    server: 203.0.113.2
    port: 1080
  - name: CHAIN
    type: ss
    server: 203.0.113.3
    port: 8388
    cipher: aes-128-gcm
    password: pw2
    dialer-proxy: JP-03
  - name: OLD
    type: snell
    server: 203.0.113.4
    port: 8388
    psk: pw3
proxy-groups:
  - name: GLOBAL
    type: select
    proxies:
      - JP-03
      - HK-01
      - CHAIN
''';

Set<String> _tags(Map<String, Object?> config, String key) {
  final entries = config[key];
  if (entries is! List) {
    return const {};
  }
  return {
    for (final entry in entries)
      if (entry is Map && entry['tag'] is String) entry['tag'] as String,
  };
}

Map<String, Object?> _byTag(Map<String, Object?> config, String tag) {
  for (final entry in config['outbounds'] as List) {
    if (entry is Map && entry['tag'] == tag) {
      return {for (final e in entry.entries) e.key.toString(): e.value};
    }
  }
  throw StateError('no outbound tagged $tag');
}

void main() {
  group('from a Clash profile', () {
    Map<String, Object?>? build(String target) {
      return singBoxSpeedTestConfigFromProfileText(
        _clashProfile,
        targetTag: target,
        mixedPort: 24601,
        apiPort: 24602,
        secret: 'test-secret',
      );
    }

    test('a leaf target keeps only its own outbound', () {
      final config = build('JP-03');
      expect(config, isNotNull);
      expect(_tags(config!, 'outbounds'), {'JP-03', 'direct'});
      expect(config.containsKey('endpoints'), isFalse);
      final route = config['route'] as Map;
      expect(route['final'], 'JP-03');
      final inbounds = config['inbounds'] as List;
      expect(inbounds, hasLength(1));
      final inbound = inbounds.single as Map;
      expect(inbound['type'], 'mixed');
      expect(inbound['listen'], '127.0.0.1');
      expect(inbound['listen_port'], 24601);
      final clashApi = (config['experimental'] as Map)['clash_api'] as Map;
      expect(clashApi['external_controller'], '127.0.0.1:24602');
      expect(clashApi['secret'], 'test-secret');
    });

    test('a chained target keeps its detour node, resolved', () {
      final config = build('CHAIN');
      expect(config, isNotNull);
      expect(_tags(config!, 'outbounds'), {'CHAIN', 'JP-03', 'direct'});
      expect(_byTag(config, 'CHAIN')['detour'], 'JP-03');
      expect((config['route'] as Map)['final'], 'CHAIN');
    });

    test('a group target keeps the group and its member closure', () {
      final config = build('GLOBAL');
      expect(config, isNotNull);
      expect(_tags(config!, 'outbounds'), {
        'GLOBAL',
        'JP-03',
        'HK-01',
        'CHAIN',
        'direct',
      });
      final group = _byTag(config, 'GLOBAL');
      expect(group['type'], 'selector');
      expect(group['outbounds'], containsAll(['JP-03', 'HK-01', 'CHAIN']));
      expect((config['route'] as Map)['final'], 'GLOBAL');
    });

    test('a node the renderer drops cannot be measured', () {
      expect(build('OLD'), isNull);
    });

    test('an unknown target cannot be measured', () {
      expect(build('NOPE'), isNull);
    });

    test('text that is not a profile cannot be measured', () {
      expect(
        singBoxSpeedTestConfigFromProfileText(
          'just a string',
          targetTag: 'JP-03',
          mixedPort: 24601,
          apiPort: 24602,
          secret: 'test-secret',
        ),
        isNull,
      );
    });
  });

  group('from a full sing-box config', () {
    Map<String, Object?>? build(Map<String, Object?> full, String target) {
      return buildSingBoxSpeedTestConfig(
        full,
        targetTag: target,
        mixedPort: 24601,
        apiPort: 24602,
        secret: 'test-secret',
      );
    }

    test('a wireguard target stays an endpoint', () {
      final config = build({
        'outbounds': [
          {'type': 'direct', 'tag': 'direct'},
        ],
        'endpoints': [
          {
            'type': 'wireguard',
            'tag': 'WG-1',
            'address': ['172.16.0.2/32'],
            'private_key': 'key',
            'peers': [
              {'address': '203.0.113.9', 'port': 51820, 'public_key': 'pub'},
            ],
          },
        ],
      }, 'WG-1');
      expect(config, isNotNull);
      expect(_tags(config!, 'endpoints'), {'WG-1'});
      expect(_tags(config, 'outbounds'), {'direct'});
      expect((config['route'] as Map)['final'], 'WG-1');
    });

    test('a two-hop detour chain is kept whole, nothing else', () {
      final config = build({
        'outbounds': [
          {'type': 'socks', 'tag': 'A', 'detour': 'B'},
          {'type': 'socks', 'tag': 'B', 'detour': 'C'},
          {'type': 'socks', 'tag': 'C'},
          {'type': 'socks', 'tag': 'D'},
          {'type': 'direct', 'tag': 'direct'},
        ],
      }, 'A');
      expect(config, isNotNull);
      expect(_tags(config!, 'outbounds'), {'A', 'B', 'C', 'direct'});
    });

    test('a dangling detour cannot be measured', () {
      expect(
        build({
          'outbounds': [
            {'type': 'socks', 'tag': 'A', 'detour': 'GHOST'},
          ],
        }, 'A'),
        isNull,
      );
    });

    test('an outbound domain resolver gets a dns server of its tag', () {
      final config = build({
        'outbounds': [
          {'type': 'socks', 'tag': 'A', 'domain_resolver': 'resolver-x'},
          {'type': 'direct', 'tag': 'direct'},
        ],
      }, 'A');
      expect(config, isNotNull);
      final servers = (config!['dns'] as Map)['servers'] as List;
      expect(
        {for (final server in servers) (server as Map)['tag']},
        {'direct', 'resolver-x'},
      );
    });

    test('a native document reduces through the same door', () {
      final config = singBoxSpeedTestConfigFromProfileText(
        '''
{
  "outbounds": [
    {"type": "socks", "tag": "NODE-1", "server": "203.0.113.5", "server_port": 1080},
    {"type": "socks", "tag": "NODE-2", "server": "203.0.113.6", "server_port": 1080},
    {"type": "direct", "tag": "direct"}
  ]
}
''',
        targetTag: 'NODE-1',
        mixedPort: 24601,
        apiPort: 24602,
        secret: 'test-secret',
      );
      expect(config, isNotNull);
      expect(_tags(config!, 'outbounds'), {'NODE-1', 'direct'});
      expect((config['route'] as Map)['final'], 'NODE-1');
    });
  });
}
