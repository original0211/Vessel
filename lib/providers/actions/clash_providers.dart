part of '../action.dart';

@Riverpod(keepAlive: true)
class ClashProvidersAction extends _$ClashProvidersAction {
  @override
  void build() {}

  CoreController get _core => ref.read(coreHandlerProvider);

  Future<ClashProvider> putProvider(
    ClashProvider provider, {
    ClashProvider? previous,
    List<int>? content,
    bool refresh = false,
  }) async {
    final before = await _stored(provider.id);
    final download =
        provider.isRemote &&
        (refresh || provider.fileName != previous?.fileName);
    final compiled = switch (content) {
      final content? => await _compileContent(provider, content),
      null when download => await _compile(provider, download: true),
      null => provider,
    };
    final latest = before == null ? null : await _stored(provider.id);
    if (before != null &&
        (latest == null || latest.fileName != before.fileName)) {
      if (latest?.fileName != compiled.fileName) {
        unawaited(_clearCache(compiled));
      }
      return latest ?? compiled;
    }
    final next = switch ((before, latest)) {
      (final before?, final latest?) => latest.copyWith(
        label: compiled.label == before.label ? latest.label : compiled.label,
        url: compiled.url,
        behavior: compiled.behavior,
        format: compiled.format,
      ),
      _ => compiled,
    };
    ref.read(clashProvidersProvider.notifier).put(next);
    if (previous != null && previous.fileName != next.fileName) {
      unawaited(_clearCache(previous));
    }
    return next;
  }

  /// Downloads outlast edits, so a result lands on the set as it is by then.
  Future<ClashProvider?> _stored(int id) async {
    final rows =
        ref.read(clashProvidersProvider).value ??
        await database.clashProvidersDao.query().get();
    return rows.where((item) => item.id == id).firstOrNull;
  }

  Future<ClashProvider> _compile(
    ClashProvider provider, {
    bool download = false,
  }) async {
    // Made here, or a Core running as root would create it as its own.
    await File(await provider.path).parent.create(recursive: true);
    final info = await _core.compileRuleSet(
      provider.fileName,
      url: download ? provider.url : '',
    );
    final next = provider.withInfo(info);
    if (!next.isCompiled) {
      await File(await next.compiledPath).safeDelete();
    }
    return next;
  }

  Future<ClashProvider> _compileContent(
    ClashProvider provider,
    List<int> content,
  ) async {
    final stagedName = '${provider.fileName}.new';
    final staged = await appPath.getProviderCachePath(stagedName);
    try {
      await File(staged).safeWriteAsBytes(content);
      final next = provider.withInfo(await _core.compileRuleSet(stagedName));
      if (next.isCompiled) {
        await File('$staged.mrs').rename(await next.compiledPath);
      } else {
        await File(await next.compiledPath).safeDelete();
      }
      await File(staged).rename(await next.path);
      return next;
    } finally {
      await File(staged).safeDelete();
      await File('$staged.mrs').safeDelete();
    }
  }

  /// A subscription's set can share the name, so match by path.
  Future<ClashProvider?> remoteProviderOf(ExternalProvider external) async {
    final path = external.path;
    if (external.type != 'Rule' ||
        external.vehicleType != 'File' ||
        path == null) {
      return null;
    }
    for (final provider in await database.clashProvidersDao.query().get()) {
      if (provider.isRemote && await provider.corePath == path) {
        return provider;
      }
    }
    return null;
  }

  /// Syncs the stored set from its source; the core then reloads it in
  /// place.
  Future<void> syncRemote(ClashProvider provider) async {
    final next = await _compile(provider, download: true);
    if (next == provider) {
      return;
    }
    await database.clashProviders.put(next.toCompanion());
  }

  /// Backups leave remote sets out and older sets have no mrs yet.
  Future<ClashProvider> prepare(ClashProvider provider) async {
    if (await File(await provider.corePath).exists()) {
      return provider;
    }
    try {
      final next = await _compile(
        provider,
        download:
            provider.isRemote && !await File(await provider.path).exists(),
      );
      if (next != provider) {
        await database.clashProviders.put(next.toCompanion());
      }
      return next;
    } catch (e) {
      commonPrint.log(
        'prepare rule set ${provider.label}: $e',
        logLevel: LogLevel.warning,
      );
      return provider;
    }
  }

  Future<void> _clearCache(ClashProvider provider) async {
    await File(await provider.path).safeDelete();
    await File(await provider.compiledPath).safeDelete();
  }
}
