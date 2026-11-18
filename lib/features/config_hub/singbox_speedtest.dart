import 'dart:async';
import 'dart:io';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/features/config_hub/singbox_native.dart';
import 'package:kfusion/features/config_hub/singbox_render.dart';
import 'package:kfusion/features/proxies/speed_test.dart';
import 'package:kfusion/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The one directory the temporary speed test instance ever lives in.
/// Its config path is fixed so the startup orphan reclaim can match a
/// leftover instance by the same binary-plus-config rule as the main one.
Directory singBoxSpeedTestDir(String homeDir) {
  return Directory(p.join(homeDir, 'singbox-speedtest'));
}

String singBoxSpeedTestConfigPath(String homeDir) {
  return p.join(singBoxSpeedTestDir(homeDir).path, 'config.json');
}

/// The full sing-box config for [text] — a native document decoded as
/// is, a Clash profile through the production renderer — reduced to the
/// temporary instance's shape by [buildSingBoxSpeedTestConfig].
Map<String, Object?>? singBoxSpeedTestConfigFromProfileText(
  String text, {
  required String targetTag,
  required int mixedPort,
  required int apiPort,
  required String secret,
}) {
  final Map<String, Object?>? full;
  if (isNativeSingBoxConfig(text)) {
    full = decodeSingBoxConfig(text);
  } else {
    full = _renderProfileText(text, apiPort: apiPort, secret: secret);
  }
  if (full == null) {
    return null;
  }
  return buildSingBoxSpeedTestConfig(
    full,
    targetTag: targetTag,
    mixedPort: mixedPort,
    apiPort: apiPort,
    secret: secret,
  );
}

Map<String, Object?>? _renderProfileText(
  String text, {
  required int apiPort,
  required String secret,
}) {
  final clashMap = _stringKeyedMap(loadPlainYaml(text));
  if (clashMap == null || clashMap.isEmpty) {
    return null;
  }
  try {
    // Only the render's outbounds are taken; the ports it stamps its
    // own inbounds with are discarded by the reduction below.
    return renderSingBoxFromClash(
      clashMap,
      secret: secret,
      clashApiPort: apiPort,
      mixedPort: apiPort,
    ).config;
  } catch (_) {
    return null;
  }
}

/// Reduces a full sing-box config to the temporary instance's config:
/// only the outbounds and endpoints the target's tag closure reaches
/// (group members and detour chains included), one loopback mixed
/// inbound on [mixedPort], and every route falling to the target.
Map<String, Object?>? buildSingBoxSpeedTestConfig(
  Map<String, Object?> fullConfig, {
  required String targetTag,
  required int mixedPort,
  required int apiPort,
  required String secret,
}) {
  final outbounds = _mapList(fullConfig['outbounds']);
  final endpoints = _mapList(fullConfig['endpoints']);
  final byTag = <String, Map<String, Object?>>{};
  for (final outbound in outbounds) {
    final tag = outbound['tag'];
    if (tag is String) {
      byTag[tag] = outbound;
    }
  }
  for (final endpoint in endpoints) {
    final tag = endpoint['tag'];
    if (tag is String) {
      byTag[tag] = endpoint;
    }
  }
  if (!byTag.containsKey(targetTag)) {
    return null;
  }
  final included = <String>{};
  final queue = <String>[targetTag];
  while (queue.isNotEmpty) {
    final tag = queue.removeLast();
    if (tag == 'direct') {
      included.add(tag);
      continue;
    }
    final node = byTag[tag];
    if (node == null) {
      return null;
    }
    if (!included.add(tag)) {
      continue;
    }
    final members = node['outbounds'];
    if (members is List) {
      for (final member in members) {
        if (member is String) {
          queue.add(member);
        }
      }
    }
    final detour = node['detour'];
    if (detour is String) {
      queue.add(detour);
    }
  }
  final keptOutbounds = [
    for (final outbound in outbounds)
      if (included.contains(outbound['tag'])) outbound,
  ];
  if (!keptOutbounds.any((outbound) => outbound['tag'] == 'direct')) {
    keptOutbounds.add(const {'type': 'direct', 'tag': 'direct'});
  }
  final keptEndpoints = [
    for (final endpoint in endpoints)
      if (included.contains(endpoint['tag'])) endpoint,
  ];
  final resolverTags = <String>{'direct'};
  for (final node in [...keptOutbounds, ...keptEndpoints]) {
    final resolver = node['domain_resolver'];
    if (resolver is String && resolver.isNotEmpty) {
      resolverTags.add(resolver);
    } else if (resolver is Map && resolver['server'] is String) {
      resolverTags.add(resolver['server'] as String);
    }
  }
  return {
    'log': {'level': 'info', 'timestamp': true},
    'dns': {
      'servers': [
        for (final tag in resolverTags)
          {'type': 'udp', 'tag': tag, 'server': '223.5.5.5'},
      ],
      'final': 'direct',
      'strategy': 'prefer_ipv4',
    },
    'inbounds': [
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': mixedPort,
      },
    ],
    'outbounds': keptOutbounds,
    if (keptEndpoints.isNotEmpty) 'endpoints': keptEndpoints,
    'route': {
      'final': targetTag,
      'default_domain_resolver': {'server': 'direct'},
    },
    'experimental': {
      'clash_api': {
        'external_controller': '127.0.0.1:$apiPort',
        'secret': secret,
      },
    },
  };
}

Map<String, Object?>? _stringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final entry in value)
      if (entry is Map)
        {for (final e in entry.entries) e.key.toString(): e.value},
  ];
}

class _SourceFailure implements Exception {
  const _SourceFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

String _failureText(Object error) {
  if (error is _SourceFailure) {
    return error.message;
  }
  return error.toString();
}

/// Joins the per-source failures the way speedTestErrorText in
/// core/speedtest.go does: one failure keeps its own wording, several
/// are each prefixed with their source so none hides another.
String _aggregateFailures(List<(String, String)> failures) {
  if (failures.length == 1) {
    return failures.single.$2;
  }
  return failures.map((failure) => '${failure.$1}: ${failure.$2}').join('; ');
}

/// Downloads through a proxy port with the core meter's semantics
/// (core/speedtest.go): one deadline across sources, the warmup
/// discarded once, a capped total, and a source that ends early or
/// answers badly simply yields to the next. A source whose URL names
/// its byte count is one chunk of the window, continued with further
/// requests until a cap or the deadline ends it.
class SingBoxSpeedDownload {
  SingBoxSpeedDownload({
    HttpClient Function()? clientFactory,
    DateTime Function()? clock,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       _clock = clock ?? DateTime.now;

  final HttpClient Function() _clientFactory;
  final DateTime Function() _clock;
  HttpClient? _client;
  bool _aborted = false;

  void abort() {
    _aborted = true;
    _client?.close(force: true);
  }

  Future<SpeedTestResult> run({
    required String name,
    required int proxyPort,
    required List<String> urls,
    required Duration timeout,
    required bool Function() cancelled,
  }) async {
    final deadline = _clock().add(timeout);
    final failures = <(String, String)>[];
    for (final url in urls) {
      if (_aborted || cancelled()) {
        return SpeedTestResult(name: name, error: 'speed test cancelled');
      }
      if (deadline.difference(_clock()) <= Duration.zero) {
        break;
      }
      try {
        return await _measureSource(
          name: name,
          url: url,
          proxyPort: proxyPort,
          deadline: deadline,
          cancelled: cancelled,
        );
      } catch (error) {
        if (_aborted || cancelled()) {
          return SpeedTestResult(name: name, error: 'speed test cancelled');
        }
        failures.add((url, _failureText(error)));
        if (deadline.difference(_clock()) <= Duration.zero) {
          break;
        }
      }
    }
    if (failures.isEmpty) {
      return SpeedTestResult(name: name, error: 'no speed test source');
    }
    return SpeedTestResult(name: name, error: _aggregateFailures(failures));
  }

  Future<SpeedTestResult> _measureSource({
    required String name,
    required String url,
    required int proxyPort,
    required DateTime deadline,
    required bool Function() cancelled,
  }) async {
    final client = _clientFactory();
    _client = client;
    client.autoUncompress = false;
    client.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
    final remaining = deadline.difference(_clock());
    client.connectionTimeout = remaining > Duration.zero
        ? remaining
        : const Duration(milliseconds: 1);
    var deadlineHit = false;
    final timer = Timer(
      remaining > Duration.zero ? remaining : Duration.zero,
      () {
        deadlineHit = true;
        client.close(force: true);
      },
    );
    try {
      final meter = SpeedTestMeter(startedAt: _clock());
      final chunked = Uri.parse(url).queryParameters.containsKey('bytes');
      while (meter.totalBytes < speedTestMaxBytes) {
        if (_aborted || cancelled()) {
          throw const _SourceFailure('speed test cancelled');
        }
        if (deadlineHit || deadline.difference(_clock()) <= Duration.zero) {
          break;
        }
        final before = meter.totalBytes;
        final completed = await _readChunk(
          client: client,
          url: url,
          meter: meter,
          deadlineHit: () => deadlineHit,
          cancelled: cancelled,
        );
        if (!completed || !chunked || meter.totalBytes == before) {
          break;
        }
      }
      final window = meter.window(_clock());
      if (!speedWindowMeasurable(window)) {
        throw const _SourceFailure(
          'speed test source ended before a measurable window',
        );
      }
      return SpeedTestResult(
        name: name,
        mbps: speedMbpsForWindow(window.bytes, window.duration),
        totalBytes: meter.totalBytes,
      );
    } finally {
      timer.cancel();
      client.close(force: true);
      if (identical(_client, client)) {
        _client = null;
      }
    }
  }

  /// Reads one response into [meter]; true when the response ran out or
  /// the byte cap stopped it, false when the deadline cut it short.
  Future<bool> _readChunk({
    required HttpClient client,
    required String url,
    required SpeedTestMeter meter,
    required bool Function() deadlineHit,
    required bool Function() cancelled,
  }) async {
    final HttpClientResponse response;
    try {
      final request = await client.getUrl(Uri.parse(url));
      response = await request.close();
    } catch (error) {
      if (deadlineHit()) {
        return false;
      }
      if (_aborted || cancelled()) {
        throw const _SourceFailure('speed test cancelled');
      }
      rethrow;
    }
    if (response.statusCode != HttpStatus.ok) {
      final reason = response.reasonPhrase;
      throw _SourceFailure(
        'speed test source answered ${response.statusCode}'
        '${reason.isEmpty ? '' : ' $reason'}',
      );
    }
    try {
      await for (final chunk in response) {
        meter.add(chunk.length, _clock());
        if (meter.totalBytes >= speedTestMaxBytes) {
          return true;
        }
        if (_aborted || cancelled()) {
          throw const _SourceFailure('speed test cancelled');
        }
      }
    } catch (error) {
      if (error is _SourceFailure) {
        rethrow;
      }
      if (deadlineHit()) {
        return false;
      }
      if (_aborted || cancelled()) {
        throw const _SourceFailure('speed test cancelled');
      }
      throw const _SourceFailure('speed test download broke');
    }
    return true;
  }
}

typedef SingBoxBinaryLocator = Future<String?> Function(String homeDir);

typedef SingBoxPortAllocator = Future<int> Function();

Future<int> allocateLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Runs one measurement on a throwaway sing-box instance. Every exit
/// path — success, failure, throw, cancel — stops the instance and
/// removes its directory before the future completes.
class SingBoxSpeedTester {
  SingBoxSpeedTester({
    ProcessLauncher? launcher,
    SingBoxBinaryLocator? locateBinary,
    SingBoxPortAllocator? allocatePort,
    SingBoxSpeedDownload Function()? downloadFactory,
    Duration readyTimeout = const Duration(seconds: 10),
  }) : _launcher = launcher ?? IoProcessLauncher(),
       _locateBinary = locateBinary ?? _locateShippedBinary,
       _allocatePort = allocatePort ?? allocateLoopbackPort,
       _downloadFactory = downloadFactory ?? SingBoxSpeedDownload.new,
       _readyTimeout = readyTimeout;

  final ProcessLauncher _launcher;
  final SingBoxBinaryLocator _locateBinary;
  final SingBoxPortAllocator _allocatePort;
  final SingBoxSpeedDownload Function() _downloadFactory;
  final Duration _readyTimeout;

  SingBoxRunner? _runner;
  SingBoxSpeedDownload? _download;
  bool _active = false;

  static Future<String?> _locateShippedBinary(String homeDir) async {
    return findSingBoxBinary(
      singBoxCandidates(
        executableDir: appPath.executableDirPath,
        homeDir: homeDir,
        storedPath: await Preferences().getSingBoxBinaryPath(),
      ),
    );
  }

  void cancel() {
    _download?.abort();
    final runner = _runner;
    if (runner != null) {
      unawaited(runner.stop());
    }
  }

  Future<SpeedTestResult> measure({
    required String targetName,
    required String profileText,
    required String homeDir,
    required bool Function() cancelled,
  }) async {
    if (_active) {
      return SpeedTestResult(
        name: targetName,
        error: 'a speed test is already running',
      );
    }
    _active = true;
    try {
      return await _measure(
        targetName: targetName,
        profileText: profileText,
        homeDir: homeDir,
        cancelled: cancelled,
      );
    } finally {
      await _teardown(homeDir);
      _active = false;
    }
  }

  Future<SpeedTestResult> _measure({
    required String targetName,
    required String profileText,
    required String homeDir,
    required bool Function() cancelled,
  }) async {
    final binary = await _locateBinary(homeDir);
    if (binary == null) {
      commonPrint.log(
        'sing-box speed test: binary not found',
        logLevel: LogLevel.error,
      );
      return SpeedTestResult(
        name: targetName,
        error: 'sing-box binary unavailable',
      );
    }
    if (cancelled()) {
      return SpeedTestResult(name: targetName, error: 'cancelled');
    }
    final mixedPort = await _allocatePort();
    var apiPort = await _allocatePort();
    while (apiPort == mixedPort) {
      apiPort = await _allocatePort();
    }
    final secret = generateSingBoxSecret();
    final config = singBoxSpeedTestConfigFromProfileText(
      profileText,
      targetTag: targetName,
      mixedPort: mixedPort,
      apiPort: apiPort,
      secret: secret,
    );
    if (config == null) {
      commonPrint.log(
        'sing-box speed test: $targetName has no usable outbound',
        logLevel: LogLevel.error,
      );
      return SpeedTestResult(
        name: targetName,
        error: 'proxy "$targetName" has no sing-box outbound',
      );
    }
    final runner = SingBoxRunner(
      launcher: _launcher,
      readyTimeout: _readyTimeout,
      pollInterval: const Duration(milliseconds: 200),
    );
    _runner = runner;
    final started = await runner.start(
      executable: binary,
      config: config,
      configDir: singBoxSpeedTestDir(homeDir),
      apiPort: apiPort,
      secret: secret,
    );
    if (!started.ok) {
      commonPrint.log(
        'sing-box speed test instance failed: ${started.message}',
        logLevel: LogLevel.error,
      );
      return SpeedTestResult(name: targetName, error: started.message);
    }
    if (cancelled()) {
      return SpeedTestResult(name: targetName, error: 'cancelled');
    }
    final download = _downloadFactory();
    _download = download;
    return download.run(
      name: targetName,
      proxyPort: mixedPort,
      urls: speedTestDownloadUrls,
      timeout: speedTestTimeoutDuration,
      cancelled: cancelled,
    );
  }

  Future<void> _teardown(String homeDir) async {
    _download?.abort();
    _download = null;
    final runner = _runner;
    _runner = null;
    if (runner != null) {
      try {
        await runner.stop();
      } catch (_) {}
    }
    try {
      await singBoxSpeedTestDir(homeDir).delete(recursive: true);
    } catch (_) {}
  }
}

/// The sing-box speed test exists only where the second-instance path
/// does: Windows. Everywhere else the entry stays as BUILD-1 left it.
final speedTestSingBoxSupportedProvider = Provider<bool>(
  (ref) => system.isWindows,
);

final singBoxSpeedTesterProvider = Provider<SingBoxSpeedTester>(
  (ref) => SingBoxSpeedTester(),
);
