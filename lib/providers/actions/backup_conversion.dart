part of '../action.dart';

/// How many of the custom profiles a restore carried were materialized
/// into file profiles, and the labels of those that were not.
class RestoreConversionReport {
  const RestoreConversionReport({
    this.converted = 0,
    this.failedLabels = const [],
  });

  final int converted;
  final List<String> failedLabels;

  bool get isEmpty => converted == 0 && failedLabels.isEmpty;
}

/// Materializes every custom profile in [data] into a file profile whose
/// YAML file snapshots its current rendering, before any of it lands.
Future<({MigrationData data, RestoreConversionReport report})>
materializeRestoredCustomProfiles(
  SetupAction setupAction,
  MigrationData data, {
  required PatchClashConfig patchConfig,
  required String? stagingDirPath,
}) async {
  final customs = [
    for (final profile in data.profiles)
      if (profile.type == ProfileType.custom) profile,
  ];
  if (customs.isEmpty) {
    return (data: data, report: const RestoreConversionReport());
  }
  final profileProviders = {
    for (final profile in data.profiles)
      if (profile.type != ProfileType.custom) profile.realLabel: profile.id,
  };
  var profiles = data.profiles;
  final convertedIds = <int, int>{};
  final failedIds = <int>{};
  final failedLabels = <String>[];
  for (final profile in customs) {
    try {
      final built = await setupAction.renderCustomProfile(
        setupState: SetupState(
          profileId: profile.id,
          profileLastUpdateDate: profile.lastUpdateDate?.millisecondsSinceEpoch,
          profileType: ProfileType.custom,
          rules: [
            for (final rule in data.rules)
              if (rule.profileId == profile.id) rule,
          ],
          proxyGroups: [
            for (final group in data.proxyGroups)
              if (group.profileId == profile.id) group,
          ],
          overrides:
              (data.profileOverrides[profile.id] ?? const ProfileOverrides())
                  .overAppTun(
                    patchConfig.tunOverride,
                    patchConfig.tunOverrideKeys,
                  ),
          clashProviders: data.clashProviders,
          profileProviders: profileProviders,
          appProxies: data.customProxies,
          proxyDialers: {
            for (final dialer in data.proxyDialers)
              if (dialer.profileId == profile.id) dialer.proxyId: dialer.target,
          },
        ),
        patchConfig: patchConfig,
      );
      if (built.yaml.isEmpty) {
        throw StateError('custom profile ${profile.id} rendered empty');
      }
      final newId = snowflake.id;
      final snapshot = stagingDirPath != null
          ? File(
              BackupEntries.resolve(
                stagingDirPath,
                BackupEntries.profile(newId),
              ),
            )
          : File(await appPath.getProfilePath('$newId'));
      await snapshot.create(recursive: true);
      await snapshot.writeAsString(built.yaml);
      convertedIds[profile.id] = newId;
      profiles = [
        for (final item in profiles)
          if (item.id == profile.id)
            item.copyWith(id: newId, type: ProfileType.file, autoUpdate: false)
          else
            item,
      ];
    } catch (e) {
      // A failed profile keeps all of its rows; it is named, never halved.
      failedIds.add(profile.id);
      failedLabels.add(profile.realLabel);
      commonPrint.log(
        'materializing ${profile.realLabel} failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }
  var configMap = data.configMap;
  final currentId = configMap?['currentProfileId'];
  if (configMap != null && currentId is int) {
    if (convertedIds.containsKey(currentId)) {
      configMap = {...configMap, 'currentProfileId': convertedIds[currentId]};
    } else if (failedIds.contains(currentId)) {
      // A profile that did not convert must not come back selected.
      configMap = {...configMap, 'currentProfileId': null};
    }
  }
  final converted = convertedIds.keys.toSet();
  final stillCustom = profiles.any(
    (profile) => profile.type == ProfileType.custom,
  );
  return (
    data: data.copyWith(
      configMap: configMap,
      profiles: profiles,
      rules: [
        for (final rule in data.rules)
          if (!converted.contains(rule.profileId)) rule,
      ],
      disabledRules: [
        for (final rule in data.disabledRules)
          if (!converted.contains(rule.profileId)) rule,
      ],
      proxyGroups: [
        for (final group in data.proxyGroups)
          if (!converted.contains(group.profileId)) group,
      ],
      proxyDialers: [
        for (final dialer in data.proxyDialers)
          if (!converted.contains(dialer.profileId)) dialer,
      ],
      // Shared by every custom profile; dropped only when none remain.
      customProxies: stillCustom ? data.customProxies : const [],
      profileOverrides: {
        for (final MapEntry(key: id, value: overrides)
            in data.profileOverrides.entries)
          if (!converted.contains(id)) id: overrides,
      },
    ),
    report: RestoreConversionReport(
      converted: convertedIds.length,
      failedLabels: failedLabels,
    ),
  );
}

/// The schema-22 upgrade of a live database, run once at startup before
/// the profiles load: materializes any custom profiles the retired
/// per-profile tables still carry — the same conversion a restore runs —
/// then retires the shape. Profiles that fail to convert keep their rows
/// and the tables stay, so the next launch retries them; the retired
/// tables only drop once nothing unconverted remains.
Future<({RestoreConversionReport report, int? currentProfileId})>
convertDatabaseCustomProfiles(
  SetupAction setupAction, {
  required PatchClashConfig patchConfig,
  required int? currentProfileId,
}) async {
  final customsPresent = await database
      .customSelect("SELECT id FROM profiles WHERE type = 'custom'")
      .get();
  if (customsPresent.isEmpty && !await database.hasLegacyProfileData) {
    return (
      report: const RestoreConversionReport(),
      currentProfileId: currentProfileId,
    );
  }
  final legacy = await database.readLegacyProfileData();
  final customIds = {
    for (final profile in legacy.profiles)
      if (profile.type == ProfileType.custom) profile.id,
  };
  final (:data, :report) = await materializeRestoredCustomProfiles(
    setupAction,
    legacy.copyWith(configMap: {'currentProfileId': currentProfileId}),
    patchConfig: patchConfig,
    stagingDirPath: null,
  );
  await database.profilesDao.setAll(data.profiles);
  final failedIds = {
    for (final profile in data.profiles)
      if (profile.type == ProfileType.custom) profile.id,
  };
  if (failedIds.isEmpty) {
    await database.dropLegacyProfileData();
  } else {
    await database.deleteLegacyProfileRows(customIds.difference(failedIds));
    commonPrint.log(
      'legacy profiles kept for a later retry: ${report.failedLabels}',
      logLevel: LogLevel.warning,
    );
  }
  return (
    report: report,
    currentProfileId: data.configMap?['currentProfileId'] as int?,
  );
}

/// Drops a dialer that leads back to its proxy; mihomo would loop on it.
List<Map<String, dynamic>> appProxiesPayload(
  Iterable<CustomProxy> proxies, {
  required Map<int, String> dialers,
  required List<ProxyGroup> groups,
}) {
  final named = {for (final group in groups) ...?group.proxies};
  final chain = {
    for (final proxy in proxies)
      if (named.contains(proxy.name)) proxy.name: ?dialers[proxy.id],
  };
  final looping = _DialLoops(groups, chain).looping;
  final payload = <Map<String, dynamic>>[];
  for (final proxy in proxies) {
    if (!named.contains(proxy.name)) {
      continue;
    }
    final dialer = chain[proxy.name];
    if (dialer != null && !looping.contains(proxy.name)) {
      payload.add({...proxy.definition, 'dialer-proxy': dialer});
      continue;
    }
    if (dialer != null) {
      commonPrint.log(
        'Dropped the dialer of ${proxy.name}: $dialer leads back to it',
        logLevel: LogLevel.warning,
      );
    }
    payload.add({...proxy.definition}..remove('dialer-proxy'));
  }
  return payload;
}

/// Tarjan's components of [edges], numbered as they close, so an edge never
/// leads to a component numbered higher than its own.
List<int> _componentsOf(List<List<int>> edges) {
  final index = List.filled(edges.length, -1);
  final low = List.filled(edges.length, 0);
  final component = List.filled(edges.length, -1);
  final stack = <int>[];
  var visited = 0;
  var closed = 0;
  void connect(int node) {
    index[node] = low[node] = visited++;
    stack.add(node);
    for (final next in edges[node]) {
      if (index[next] == -1) {
        connect(next);
        low[node] = min(low[node], low[next]);
      } else if (component[next] == -1) {
        low[node] = min(low[node], index[next]);
      }
    }
    if (low[node] != index[node]) {
      return;
    }
    int item;
    do {
      item = stack.removeLast();
      component[item] = closed;
    } while (item != node);
    closed++;
  }

  for (var node = 0; node < edges.length; node++) {
    if (index[node] == -1) {
      connect(node);
    }
  }
  return component;
}

bool _takesInEveryProxy(ProxyGroup group) =>
    group.includeAllProxies == true &&
    (group.filter ?? '').isEmpty &&
    (group.excludeFilter ?? '').isEmpty &&
    (group.excludeType ?? '').isEmpty;

class _DialerGraph {
  final declared = <String>{};
  final chained = <String, String>{};
  final members = <String, List<String>>{};
  final groupNames = <String>{};
  final takingEveryProxy = <String>{};
  final parents = <String, List<String>>{};

  _DialerGraph(Iterable<ProxyGroup> groups, Map<String, String> dialers) {
    for (final group in groups) {
      declared.addAll(group.proxies ?? const <String>[]);
    }
    for (final MapEntry(key: name, value: dialer) in dialers.entries) {
      if (declared.contains(name)) {
        chained[name] = dialer;
        members[name] = [dialer];
      }
    }
    for (final group in groups) {
      final takesAll = _takesInEveryProxy(group);
      members[group.name] = [...?group.proxies, if (takesAll) ...chained.keys];
      groupNames.add(group.name);
      if (takesAll) {
        takingEveryProxy.add(group.name);
      } else {
        takingEveryProxy.remove(group.name);
      }
    }
    for (final MapEntry(key: name, value: items) in members.entries) {
      for (final item in items) {
        parents.putIfAbsent(item, () => []).add(name);
      }
    }
  }

  /// The proxy's own dialer is the dial being checked, never a way back.
  Set<String> Function(String target) loopsOf(String proxy) {
    if (!declared.contains(proxy)) {
      return (_) => const {};
    }
    final passesThrough = groupNames.contains(proxy);
    final takenIn = !chained.containsKey(proxy);
    final reaching = <String>{};
    final pending = [...?parents[proxy], if (takenIn) ...takingEveryProxy];
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if ((passesThrough || name != proxy) && reaching.add(name)) {
        pending.addAll(parents[name] ?? const []);
      }
    }
    return (target) {
      if (target == proxy) {
        return {proxy};
      }
      final loop = <String>{};
      void walk(String name) {
        if (!reaching.contains(name) || !loop.add(name)) {
          return;
        }
        for (final next in members[name] ?? const <String>[]) {
          walk(next);
        }
        if (takenIn && takingEveryProxy.contains(name)) {
          walk(proxy);
        }
      }

      walk(target);
      return loop;
    };
  }
}

/// Every dial of [dialers] at once: those that loop, and the groups each
/// loop passes through, from reachability between the graph's components
/// rather than one walk per dial.
class _DialLoops {
  final looping = <String>{};
  final throughGroups = <String, List<CustomIssue>>{};

  _DialLoops(Iterable<ProxyGroup> groups, Map<String, String> dialers) {
    final graph = _DialerGraph(groups, dialers);
    final dials = [
      for (final MapEntry(key: proxy, value: target) in dialers.entries)
        if (graph.declared.contains(proxy)) (proxy: proxy, target: target),
    ];
    if (dials.isEmpty) {
      return;
    }
    final ids = <String, int>{};
    for (final MapEntry(key: name, value: items) in graph.members.entries) {
      for (final item in [name, ...items]) {
        ids.putIfAbsent(item, () => ids.length);
      }
    }
    final edges = List.generate(ids.length, (_) => <int>[]);
    for (final MapEntry(key: name, value: items) in graph.members.entries) {
      edges[ids[name]!].addAll([for (final item in items) ids[item]!]);
    }
    final component = _componentsOf(edges);
    final count = component.fold(0, (count, item) => max(count, item + 1));
    final nodes = List.generate(count, (_) => <int>[]);
    for (final (node, item) in component.indexed) {
      nodes[item].add(node);
    }
    final words = (dials.length + 31) >> 5;
    final reaches = List.generate(count, (_) => Uint32List(words));
    final reachedFrom = List.generate(count, (_) => Uint32List(words));
    bool has(Uint32List bits, int dial) =>
        bits[dial >> 5] & (1 << (dial & 31)) != 0;
    void add(Uint32List bits, int dial) => bits[dial >> 5] |= 1 << (dial & 31);
    void merge(Uint32List into, Uint32List from) {
      for (var word = 0; word < words; word++) {
        into[word] |= from[word];
      }
    }

    for (final (dial, (:proxy, :target)) in dials.indexed) {
      add(reaches[component[ids[proxy]!]], dial);
      final node = ids[target];
      if (target != proxy && node != null) {
        add(reachedFrom[component[node]], dial);
      }
    }
    for (var item = 0; item < count; item++) {
      for (final node in nodes[item]) {
        for (final next in edges[node]) {
          if (component[next] != item) {
            merge(reaches[item], reaches[component[next]]);
          }
        }
      }
    }
    for (var item = count - 1; item >= 0; item--) {
      for (final node in nodes[item]) {
        for (final next in edges[node]) {
          if (component[next] != item) {
            merge(reachedFrom[component[next]], reachedFrom[item]);
          }
        }
      }
    }
    for (final (dial, (:proxy, :target)) in dials.indexed) {
      final node = ids[target];
      if (target == proxy ||
          node != null && has(reaches[component[node]], dial)) {
        looping.add(proxy);
      }
    }
    for (final name in graph.groupNames) {
      final node = ids[name]!;
      final item = component[node];
      final onLoop = nodes[item].length > 1 || edges[node].contains(node);
      for (final (dial, (:proxy, :target)) in dials.indexed) {
        final through = target == proxy
            ? name == proxy
            : (name == proxy ? onLoop : has(reaches[item], dial)) &&
                  has(reachedFrom[item], dial);
        if (through) {
          throughGroups
              .putIfAbsent(name, () => [])
              .add(CustomIssue.dialerLoop(proxy, target));
        }
      }
    }
  }
}
