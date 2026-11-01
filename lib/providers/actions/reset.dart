part of '../action.dart';

/// Runs a full settings reset: the assembled defaults go through the same
/// whole-config write a backup restore uses, persistence follows from the
/// store listener, and a running core re-applies the profile once, forced.
/// A stopped core only persists; its next start reads the defaults.
Future<void> applySettingsReset(Ref ref) async {
  writeConfig(ref, buildResetConfig(ref.read(configProvider)));
  if (ref.read(isStartProvider)) {
    await ref.read(setupActionProvider.notifier).applyProfile(force: true);
  }
}
