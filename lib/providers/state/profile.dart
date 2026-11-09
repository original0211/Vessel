part of '../state.dart';

@riverpod
ProfilesState profilesState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return ProfilesState(profiles: profiles, currentProfileId: currentProfileId);
}

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Profile? profile(Ref ref, int? profileId) {
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Future<ClashConfig> clashConfig(Ref ref, int profileId) async {
  final outbounds = await ref
      .read(coreHandlerProvider)
      .getProfileOutbounds(profileId);
  return clashConfigTask(outbounds);
}

@riverpod
Future<SetupState> setupState(Ref ref, int? profileId) async {
  final profile = ref.watch(profileProvider(profileId));
  final profileLastUpdateDate = profile?.lastUpdateDate?.millisecondsSinceEpoch;
  final profileType = profile?.type ?? ProfileType.file;
  final overrides = ref.watch(
    patchClashConfigProvider.select(
      (state) => ProfileOverrides(
        dns: state.dns,
        dnsOverrideKeys: state.dnsOverrideKeys.intersection(
          DnsOverrideKey.normalProfileKeys,
        ),
        tun: state.tunOverride,
        tunOverrideKeys: state.tunOverrideKeys,
      ),
    ),
  );
  return SetupState(
    clashProviders: const [],
    profileProviders: const {},
    appProxies: const [],
    proxyDialers: const {},
    rules: const [],
    proxyGroups: const [],
    profileId: profileId,
    profileLastUpdateDate: profileLastUpdateDate,
    profileType: profileType,
    overrides: overrides,
  );
}
