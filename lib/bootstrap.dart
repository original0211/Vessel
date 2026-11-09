import 'dart:async';
import 'dart:io';

import 'package:kfusion/common/boot_guard.dart';
import 'package:kfusion/common/boot_record.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/common/launch.dart';
import 'package:kfusion/common/migration.dart';
import 'package:kfusion/common/tray.dart';
import 'package:kfusion/common/window.dart';
import 'package:kfusion/database/database.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/l10n/l10n.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/views/disclaimer.dart';
import 'package:kfusion/views/navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Bootstrap {
  static Bootstrap? _instance;

  Bootstrap._internal();

  factory Bootstrap() {
    _instance ??= Bootstrap._internal();
    return _instance!;
  }

  BootDecision _bootDecision = const BootDecision();

  /// Schema 22 retires the per-profile tables: custom profiles a
  /// pre-upgrade database still carries are materialized into file
  /// profiles before the first profiles read, and the retired shape is
  /// dropped behind them. A failure leaves the data in place for the
  /// next launch rather than blocking startup on it.
  Future<Config> _convertLegacyProfiles(
    ProviderContainer container,
    Config config,
  ) async {
    try {
      final (:report, :currentProfileId) = await convertDatabaseCustomProfiles(
        container.read(setupActionProvider.notifier),
        patchConfig: config.patchClashConfig,
        currentProfileId: config.currentProfileId,
      );
      if (!report.isEmpty) {
        commonPrint.log(
          'converted ${report.converted} legacy custom profiles'
          '${report.failedLabels.isEmpty ? '' : '; failed: ${report.failedLabels}'}',
        );
      }
      if (currentProfileId == config.currentProfileId) {
        return config;
      }
      final converted = config.copyWith(currentProfileId: currentProfileId);
      container.read(currentProfileIdProvider.notifier).value =
          converted.currentProfileId;
      await preferences.saveConfig(converted);
      return converted;
    } catch (e) {
      commonPrint.log(
        'legacy profile conversion failed: ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      return config;
    }
  }

  Future<ProviderContainer> init(int version) async {
    globalState.appEnv = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'pre',
    );
    windowPort = window;
    trayPort = appTray;
    navigationPort = navigation;
    return _initData(version);
  }

  /// Runs before migration and the database: a copy started from another
  /// install path gets past the platform's single-instance hand-off.
  Future<void> _claimDataDirectory() async {
    if (!system.isDesktop || await singleInstanceLock.acquire()) {
      return;
    }
    commonPrint.log('another instance owns the data directory, exiting');
    exit(0);
  }

  Future<ProviderContainer> _initData(int version) async {
    await _claimDataDirectory();
    globalState.packageInfo = await PackageInfo.fromPlatform();
    var config = await migration.run();
    _bootDecision = await bootGuard.evaluate(
      profileId: config.currentProfileId,
    );
    if (_bootDecision.recovery == BootRecovery.clearProfile) {
      config = config.copyWith(currentProfileId: null);
      await preferences.saveConfig(config);
    }
    final patchClashConfig = config.patchClashConfig.ensureControllerSecret();
    if (patchClashConfig != config.patchClashConfig) {
      config = config.copyWith(patchClashConfig: patchClashConfig);
      await preferences.saveConfig(config);
    }
    final appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxRequestsLength),
      logs: FixedList(maxLogsLength),
      traffics: FixedList(trafficSampleLength),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final appStateOverrides = buildAppStateOverrides(appState);
    final configOverrides = buildConfigOverrides(config);
    final container = ProviderContainer(
      overrides: [...appStateOverrides, ...configOverrides],
    );
    globalState.container = container;
    config = await _convertLegacyProfiles(container, config);
    final profiles = await database.profilesDao.query().get();
    container.read(profilesProvider.notifier).reorder(profiles);
    await AppLocalizations.load(
      getLocaleForString(config.appSettingProps.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    await window?.init(version, config.windowProps);
    if (system.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    return container;
  }

  Future<void> attach() async {
    if (globalState.isAttach == true) {
      return;
    }
    await _initApp();
    globalState.isAttach = true;
  }

  ProviderContainer get _container => globalState.container;

  Future<void> _initApp() async {
    unawaited(_container.read(systemActionProvider.notifier).updateTray());
    unawaited(
      _container.read(profilesActionProvider.notifier).autoUpdateProfiles(),
    );
    unawaited(_container.read(commonActionProvider.notifier).autoCheckUpdate());
    unawaited(
      autoLaunch?.updateStatus(_container.read(appSettingProvider).autoLaunch),
    );
    if (!_container.read(appSettingProvider).silentLaunch) {
      unawaited(window?.show());
    } else {
      unawaited(window?.hide());
    }
    await _handleFailedPreference();
    if (!await _handlerDisclaimer()) {
      return;
    }
    await _showCrashRecoveryTip();
    await _container.read(coreActionProvider.notifier).startCore();
    if (!_bootDecision.isDegraded) {
      await _container.read(setupActionProvider.notifier).initStatus();
    }
    _container.read(initProvider.notifier).value = true;
    unawaited(_container.read(resourcesActionProvider.notifier).autoUpdate());
    await bootGuard.markRunning();
    unawaited(_container.read(locationPermissionsProvider.notifier).refresh());
  }

  Future<void> _showCrashRecoveryTip() async {
    switch (_bootDecision.recovery) {
      case BootRecovery.none:
        return;
      case BootRecovery.skipAutoSetup:
        await dialogs.showMessage(
          title: currentAppLocalizations.launchInterrupted,
          cancelable: false,
          dismissible: false,
          message: TextSpan(text: currentAppLocalizations.launchInterruptedTip),
        );
      case BootRecovery.clearProfile:
        await dialogs.showMessage(
          title: currentAppLocalizations.crashDetected,
          cancelable: false,
          dismissible: false,
          message: TextSpan(
            text: currentAppLocalizations.crashDetectedTip(_failedProfileLabel),
          ),
        );
    }
  }

  String get _failedProfileLabel {
    final profileId = _bootDecision.failedProfileId;
    if (profileId == null) {
      return '';
    }
    final profile = _container.read(profilesProvider).getProfile(profileId);
    return profile?.label.takeFirstValid(['$profileId']) ?? '$profileId';
  }

  Future<void> _handleFailedPreference() async {
    if (await preferences.isInit) return;
    final res = await dialogs.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(text: currentAppLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      await file.safeDelete();
    }
    // Saving here would rewrite the preferences file the user just chose to delete.
    await _container.read(systemActionProvider.notifier).handleExit(false);
  }

  /// Android's exit only finishes the activity, so Dart keeps running after
  /// [SystemAction.handleExit] returns and must not go on to start the app.
  Future<bool> _handlerDisclaimer() async {
    final acceptedVersion = _container.read(
      appSettingProvider.select((state) => state.acceptedDisclaimerVersion),
    );
    if (acceptedVersion >= disclaimerVersion) {
      return true;
    }
    final isDisclaimerAccepted = await requestDisclaimerConsent();
    if (!isDisclaimerAccepted) {
      await _container.read(systemActionProvider.notifier).handleExit();
      return false;
    }
    _container
        .read(appSettingProvider.notifier)
        .update(
          (state) =>
              state.copyWith(acceptedDisclaimerVersion: disclaimerVersion),
        );
    return true;
  }
}

final bootstrap = Bootstrap();
