import 'dart:io';

import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:test/test.dart';

final _source = File('core/Clash.Meta/config/config.go').readAsStringSync();

List<String> _firstArguments(String function) => [
  for (final match in RegExp(
    '(?<!func )\\b$function\\(([^,]+),',
  ).allMatches(_source))
    match[1]!.trim(),
];

ProfileOverrides _dns(Dns dns, DnsOverrideKey key) =>
    ProfileOverrides(dns: dns, dnsOverrideKeys: {key});

ProfileOverrides _sniffer(Sniffer sniffer, SnifferOverrideKey key) =>
    ProfileOverrides(sniffer: sniffer, snifferOverrideKeys: {key});

/// A rule set named `x` in each place the core reads one from.
final _ruleSetSites = {
  'cfg.NameServerPolicy': _dns(
    const Dns(nameserverPolicy: {'rule-set:x': '1.1.1.1'}),
    DnsOverrideKey.nameserverPolicy,
  ),
  'cfg.ProxyServerNameserverPolicy': _dns(
    const Dns(proxyServerNameserverPolicy: {'RULE-SET:x': '1.1.1.1'}),
    DnsOverrideKey.proxyServerNameserverPolicy,
  ),
  'cfg.FakeIPFilter': _dns(
    const Dns(fakeIpFilter: ['rule-set:x']),
    DnsOverrideKey.fakeIpFilter,
  ),
  'snifferRaw.ForceDomain': _sniffer(
    const Sniffer(forceDomain: ['rule-set:x']),
    SnifferOverrideKey.forceDomain,
  ),
  'snifferRaw.SkipDomain': _sniffer(
    const Sniffer(skipDomain: ['rule-set:x']),
    SnifferOverrideKey.skipDomain,
  ),
  'snifferRaw.SkipSrcAddress': _sniffer(
    const Sniffer(skipSrcAddress: ['rule-set:x']),
    SnifferOverrideKey.skipSrcAddress,
  ),
  'snifferRaw.SkipDstAddress': _sniffer(
    const Sniffer(skipDstAddress: ['rule-set:x']),
    SnifferOverrideKey.skipDstAddress,
  ),
};

void main() {
  group('the core reads names only where the references read them', () {
    test('every function taking the rule sets is one the sites cover', () {
      expect(
        {
          for (final match in RegExp(
            r'func (\w+)\([^)]*ruleProviders map\[string\]P\.RuleProvider',
          ).allMatches(_source))
            match[1]!,
        },
        {
          'parseSubRules',
          'parseRules',
          'parseNameServerPolicy',
          'parseDNS',
          'parseFakeIPRules',
          'parseSniffer',
          'parseIPCIDR',
          'parseDomain',
          'parseIPRuleSet',
          'parseDomainRuleSet',
        },
      );
    });

    test('each place a rule set is read from is one ruleSets reads', () {
      final sites = {
        for (final function in [
          'parseDomain',
          'parseIPCIDR',
          'parseNameServerPolicy',
          'parseFakeIPRules',
        ])
          ..._firstArguments(function),
      };
      expect(sites, _ruleSetSites.keys.toSet());
      // Rules carry their own RULE-SET names.
      expect(_firstArguments('parseRules'), ['rawCfg.Rule', 'rawRules']);
      for (final MapEntry(key: site, value: overrides)
          in _ruleSetSites.entries) {
        expect(overrides.ruleSets, {'x'}, reason: site);
      }
    });
  });

  group('rule sets', () {
    test('a policy key with a comma lists sets up to a second colon, one '
        'without names its set whole', () {
      const overrides = ProfileOverrides(
        dns: Dns(
          nameserverPolicy: {
            'rule-set:a,b:c': '1.1.1.1',
            'rule-set:d:e': '1.1.1.1',
            'geosite:cn': '1.1.1.1',
          },
        ),
        dnsOverrideKeys: {DnsOverrideKey.nameserverPolicy},
      );

      expect(overrides.ruleSets, {'a', 'b', 'd:e'});
    });

    test('fake-ip-filter reads rules in rule mode, in either form', () {
      const overrides = ProfileOverrides(
        dns: Dns(
          fakeIpFilter: [
            'RULE-SET,a,fake-ip',
            'AND,((RULE-SET,b),(NETWORK,UDP)),real-ip',
            'rule-set:c',
            '+.example.com',
          ],
          fakeIpFilterMode: FakeIpFilterMode.rule,
        ),
        dnsOverrideKeys: {
          DnsOverrideKey.fakeIpFilter,
          DnsOverrideKey.fakeIpFilterMode,
        },
      );

      expect(overrides.ruleSets, {'a', 'b'});
      expect(
        overrides
            .copyWith(dnsOverrideKeys: {DnsOverrideKey.fakeIpFilter})
            .ruleSets,
        {'c'},
      );
    });

    test('a nested set lists the rule sets it names', () {
      final rule = Rule.parse('OR,((RULE-SET,a),(RULE-SET,ab)),DIRECT', id: 1);
      expect(rule.ruleSets, ['a', 'ab']);
    });
  });
}
