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
  Ref ref,
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
  final setupAction = ref.read(setupActionProvider.notifier);
  var profiles = data.profiles;
  final convertedIds = <int, int>{};
  final failedIds = <int>{};
  final failedLabels = <String>[];
  for (final profile in customs) {
    try {
      final built = await setupAction.getProfile(
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
          overrides: profile.overrides.overAppTun(
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
            item.copyWith(
              id: newId,
              type: ProfileType.file,
              overrides: const ProfileOverrides(),
              scriptId: null,
              matchTarget: null,
              extendType: ExtendType.standard,
              autoUpdate: false,
            )
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
    ),
    report: RestoreConversionReport(
      converted: convertedIds.length,
      failedLabels: failedLabels,
    ),
  );
}
