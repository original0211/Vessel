import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/action.dart';
import 'package:kfusion/providers/app.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod/riverpod.dart';

class _FakeSetupAction extends SetupAction {
  int applyProfileCalls = 0;
  final List<bool> appliedForce = [];

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applyProfileCalls++;
    appliedForce.add(force);
    return true;
  }
}

final _refProbe = Provider<Ref>((ref) => ref);

const _dirtyAppSettings = AppSettingProps(
  autoLaunch: true,
  openLogs: true,
  testUrl: 'https://example.com/check',
  acceptedDisclaimerVersion: 7,
);

const _dirtyTheme = ThemeProps(themeMode: ThemeMode.dark, pureBlack: true);

const _dirtyVpn = VpnProps(
  enable: false,
  accessControlProps: AccessControlProps(
    enable: true,
    mode: AccessControlMode.acceptSelected,
    acceptList: ['com.example.app'],
  ),
);

const _dirtyNetwork = NetworkProps(
  systemProxy: false,
  bypassDomain: ['example.com'],
  appendSystemDns: true,
);

const _dirtyProxiesStyle = ProxiesStyleProps(cardType: ProxyCardType.compact);

const _dirtyPatch = PatchClashConfig(
  allowLan: true,
  externalController: ExternalControllerStatus.open,
  secret: 'dirty-secret',
  hosts: {'example.com': '192.0.2.1'},
  dnsOverrideKeys: {DnsOverrideKey.enable},
  tunOverrideKeys: {TunOverrideKey.mtu},
);

const _dirtyWindow = WindowProps(width: 111, height: 222);

Config _dirtyConfig() {
  return const Config(
    currentProfileId: 42,
    appSettingProps: _dirtyAppSettings,
    themeProps: _dirtyTheme,
    networkProps: _dirtyNetwork,
    vpnProps: _dirtyVpn,
    proxiesStyleProps: _dirtyProxiesStyle,
    windowProps: _dirtyWindow,
    patchClashConfig: _dirtyPatch,
    excludeSSIDs: ['HomeWiFi'],
  );
}

void _dirtyProviders(ProviderContainer container) {
  container.read(appSettingProvider.notifier).update((_) => _dirtyAppSettings);
  container.read(themeSettingProvider.notifier).update((_) => _dirtyTheme);
  container.read(vpnSettingProvider.notifier).update((_) => _dirtyVpn);
  container.read(networkSettingProvider.notifier).update((_) => _dirtyNetwork);
  container
      .read(proxiesStyleSettingProvider.notifier)
      .update((_) => _dirtyProxiesStyle);
  container.read(patchClashConfigProvider.notifier).update((_) => _dirtyPatch);
  container.read(windowSettingProvider.notifier).update((_) => _dirtyWindow);
  container.read(currentProfileIdProvider.notifier).value = 42;
  container.read(excludeSSIDsProvider.notifier).value = ['HomeWiFi'];
}

void _expectResetProviders(ProviderContainer container) {
  expect(
    container.read(appSettingProvider),
    defaultAppSettingProps.copyWith(acceptedDisclaimerVersion: 7),
  );
  expect(container.read(themeSettingProvider), defaultThemeProps);
  expect(container.read(vpnSettingProvider), defaultVpnProps);
  expect(container.read(networkSettingProvider), defaultNetworkProps);
  expect(container.read(proxiesStyleSettingProvider), defaultProxiesStyleProps);
  final patch = container.read(patchClashConfigProvider);
  expect(patch, defaultClashConfig);
  expect(patch.secret, isEmpty);
  expect(patch.externalController, ExternalControllerStatus.close);
  expect(patch.hosts, isEmpty);
  expect(patch.dnsOverrideKeys, isEmpty);
  expect(patch.tunOverrideKeys, isEmpty);
  expect(container.read(windowSettingProvider), _dirtyWindow);
  expect(container.read(currentProfileIdProvider), 42);
  expect(container.read(excludeSSIDsProvider), isEmpty);
}

void main() {
  group('buildResetConfig', () {
    test('every settings object returns to its default', () {
      final result = buildResetConfig(_dirtyConfig());
      expect(
        result.appSettingProps,
        defaultAppSettingProps.copyWith(acceptedDisclaimerVersion: 7),
      );
      expect(result.themeProps, defaultThemeProps);
      expect(result.networkProps, defaultNetworkProps);
      expect(result.vpnProps, defaultVpnProps);
      expect(result.vpnProps.accessControlProps, defaultAccessControlProps);
      expect(result.proxiesStyleProps, defaultProxiesStyleProps);
      expect(result.proxiesStyleProps.cardType, ProxyCardType.standard);
      expect(result.patchClashConfig, defaultClashConfig);
    });

    test('the named clears land empty or closed', () {
      final patch = buildResetConfig(_dirtyConfig()).patchClashConfig;
      expect(patch.dnsOverrideKeys, isEmpty);
      expect(patch.tunOverrideKeys, isEmpty);
      expect(patch.hosts, isEmpty);
      expect(patch.secret, isEmpty);
      expect(patch.externalController, ExternalControllerStatus.close);
    });

    test('state carries over while the SSID list clears', () {
      final result = buildResetConfig(_dirtyConfig());
      expect(result.appSettingProps.acceptedDisclaimerVersion, 7);
      expect(result.currentProfileId, 42);
      expect(result.windowProps, _dirtyWindow);
      expect(result.excludeSSIDs, isEmpty);
    });
  });

  group('applySettingsReset', () {
    late _FakeSetupAction setupAction;
    late ProviderContainer container;

    setUp(() {
      setupAction = _FakeSetupAction();
      container = ProviderContainer(
        overrides: [setupActionProvider.overrideWith(() => setupAction)],
      );
      addTearDown(container.dispose);
    });

    test('a stopped core only persists the defaults', () async {
      _dirtyProviders(container);
      await applySettingsReset(container.read(_refProbe));
      _expectResetProviders(container);
      expect(setupAction.applyProfileCalls, 0);
    });

    test('a running core re-applies the profile once, forced', () async {
      container.read(runTimeProvider.notifier).value = 1;
      expect(container.read(isStartProvider), isTrue);
      _dirtyProviders(container);
      await applySettingsReset(container.read(_refProbe));
      _expectResetProviders(container);
      expect(setupAction.applyProfileCalls, 1);
      expect(setupAction.appliedForce, [true]);
    });
  });
}
