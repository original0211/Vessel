/// `test/models/references_test.dart` fails when the core reads a rule set
/// somewhere this file does not.
library;

import 'package:kfusion/enum/enum.dart';

import 'clash_config.dart';

const _ruleSetPrefix = 'rule-set:';

/// mihomo reads `rule-set:a,b` up to a second colon, the prefix in any case,
/// except a policy key naming one set, which it takes whole.
(int, int)? _ruleSetRange(String entry, {bool policyKey = false}) {
  if (!entry.toLowerCase().startsWith(_ruleSetPrefix)) {
    return null;
  }
  const start = _ruleSetPrefix.length;
  if (policyKey && !entry.contains(',', start)) {
    return (start, entry.length);
  }
  final colon = entry.indexOf(':', start);
  return (start, colon < 0 ? entry.length : colon);
}

List<String> _ruleSetsIn(String entry, {bool policyKey = false}) =>
    switch (_ruleSetRange(entry, policyKey: policyKey)) {
      (final start, final end) => entry.substring(start, end).split(','),
      null => const [],
    };

final _nestedRuleSet = RegExp(
  r'(\(\s*RULE-SET\s*,\s*)([^,()]+?)(\s*[,)])',
  caseSensitive: false,
);

extension RuleReferences on Rule {
  /// mihomo's ProviderNames: an undeclared one rejects the whole config.
  List<String> get ruleSets => switch (ruleAction) {
    RuleAction.RULE_SET => [?ruleProvider],
    _ when ruleAction.nestsRules => [
      for (final match in _nestedRuleSet.allMatches(content ?? '')) match[2]!,
    ],
    _ => const [],
  };
}

extension ProfileOverridesReferences on ProfileOverrides {
  List<(DnsOverrideKey, Map<String, String>)> get _policies => [
    (DnsOverrideKey.nameserverPolicy, dns.nameserverPolicy),
    (
      DnsOverrideKey.proxyServerNameserverPolicy,
      dns.proxyServerNameserverPolicy,
    ),
  ];

  List<(SnifferOverrideKey, List<String>)> get _snifferMatchers => [
    (SnifferOverrideKey.forceDomain, sniffer.forceDomain),
    (SnifferOverrideKey.skipDomain, sniffer.skipDomain),
    (SnifferOverrideKey.skipSrcAddress, sniffer.skipSrcAddress),
    (SnifferOverrideKey.skipDstAddress, sniffer.skipDstAddress),
  ];

  /// mihomo refuses the whole config for a rule set it lacks.
  Set<String> get ruleSets {
    final filterAsRules =
        dnsOverrideKeys.contains(DnsOverrideKey.fakeIpFilterMode) &&
        dns.fakeIpFilterMode == FakeIpFilterMode.rule;
    return {
      for (final (key, policy) in _policies)
        if (dnsOverrideKeys.contains(key))
          for (final domain in policy.keys)
            ..._ruleSetsIn(domain, policyKey: true),
      if (dnsOverrideKeys.contains(DnsOverrideKey.fakeIpFilter))
        for (final entry in dns.fakeIpFilter)
          ...filterAsRules
              ? Rule.parse(entry, id: 0).ruleSets
              : _ruleSetsIn(entry),
      for (final (key, entries) in _snifferMatchers)
        if (snifferOverrideKeys.contains(key))
          for (final entry in entries) ..._ruleSetsIn(entry),
    };
  }
}
