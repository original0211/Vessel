import 'dart:async';
import 'dart:io';

import 'package:kfusion/common/constant.dart';
import 'package:kfusion/core/singbox/singbox_runner.dart';
import 'package:kfusion/features/config_hub/singbox_speedtest.dart';
import 'package:kfusion/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileText = '''
proxies:
  - name: JP-03
    type: ss
    server: 203.0.113.1
    port: 8388
    cipher: aes-128-gcm
    password: pw1
''';

class _FakeRunningProcess implements RunningProcess {
  final Completer<int> _exit = Completer<int>();
  bool killed = false;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) {
      _exit.complete(0);
    }
    return true;
  }
}

class _FakeLauncher implements ProcessLauncher {
  final List<List<String>> calls = [];
  final List<_FakeRunningProcess> processes = [];
  Object? error;

  @override
  Future<RunningProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add([executable, ...arguments]);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final process = _FakeRunningProcess();
    processes.add(process);
    return process;
  }
}

class _FakeDownload extends SingBoxSpeedDownload {
  _FakeDownload({this.reading, this.hangUntilAbort = false});

  final double? reading;
  final bool hangUntilAbort;
  final Completer<void> _abortSignal = Completer<void>();
  bool ran = false;
  int? seenPort;
  List<String>? seenUrls;

  @override
  void abort() {
    if (!_abortSignal.isCompleted) {
      _abortSignal.complete();
    }
  }

  @override
  Future<SpeedTestResult> run({
    required String name,
    required int proxyPort,
    required List<String> urls,
    required Duration timeout,
    required bool Function() cancelled,
  }) async {
    ran = true;
    seenPort = proxyPort;
    seenUrls = urls;
    if (hangUntilAbort) {
      await _abortSignal.future;
      return SpeedTestResult(name: name, error: 'aborted');
    }
    final mbps = reading;
    if (mbps == null) {
      return SpeedTestResult(name: name, error: 'source down');
    }
    return SpeedTestResult(name: name, mbps: mbps, totalBytes: 123456);
  }
}

void main() {
  late Directory home;
  late HttpServer apiServer;
  late int apiPort;
  late int mixedPort;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('singbox_speedtest_test_');
    apiServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    apiPort = apiServer.port;
    apiServer.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{}');
      unawaited(request.response.close());
    });
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    mixedPort = probe.port;
    await probe.close();
  });

  tearDown(() async {
    await apiServer.close(force: true);
    if (await home.exists()) {
      await home.delete(recursive: true);
    }
  });

  SingBoxPortAllocator allocator({bool deadApi = false}) {
    final ports = [mixedPort, deadApi ? mixedPort + 1 : apiPort];
    var next = 0;
    return () async => ports[next++ % ports.length];
  }

  SingBoxSpeedTester makeTester({
    _FakeLauncher? launcher,
    _FakeDownload? download,
    String? binary = 'sing-box',
    bool deadApi = false,
    Duration readyTimeout = const Duration(seconds: 5),
  }) {
    return SingBoxSpeedTester(
      launcher: launcher ?? _FakeLauncher(),
      locateBinary: (_) async => binary,
      allocatePort: allocator(deadApi: deadApi),
      downloadFactory: () => download ?? _FakeDownload(reading: 42),
      readyTimeout: readyTimeout,
    );
  }

  Future<SpeedTestResult> measure(
    SingBoxSpeedTester tester, {
    String target = 'JP-03',
    bool Function()? cancelled,
  }) {
    return tester.measure(
      targetName: target,
      profileText: _profileText,
      homeDir: home.path,
      cancelled: cancelled ?? () => false,
    );
  }

  test('a successful test tears the instance and its directory down', () async {
    final launcher = _FakeLauncher();
    final download = _FakeDownload(reading: 42);
    final tester = makeTester(launcher: launcher, download: download);

    final result = await measure(tester);

    expect(result.succeeded, isTrue);
    expect(result.mbps, 42);
    expect(launcher.calls, hasLength(1));
    expect(
      launcher.calls.single,
      contains(singBoxSpeedTestConfigPath(home.path)),
    );
    expect(download.ran, isTrue);
    expect(download.seenPort, mixedPort);
    expect(download.seenUrls, speedTestDownloadUrls);
    expect(launcher.processes.single.killed, isTrue);
    expect(await singBoxSpeedTestDir(home.path).exists(), isFalse);
  });

  test('a launcher failure still removes the directory', () async {
    final launcher = _FakeLauncher()..error = StateError('cannot start');
    final tester = makeTester(launcher: launcher);

    final result = await measure(tester);

    expect(result.succeeded, isFalse);
    expect(result.mbps, isNull);
    expect(await singBoxSpeedTestDir(home.path).exists(), isFalse);
  });

  test('an instance that never becomes ready is torn down', () async {
    final launcher = _FakeLauncher();
    final tester = makeTester(
      launcher: launcher,
      deadApi: true,
      readyTimeout: const Duration(milliseconds: 400),
    );

    final result = await measure(tester);

    expect(result.succeeded, isFalse);
    expect(launcher.processes.single.killed, isTrue);
    expect(await singBoxSpeedTestDir(home.path).exists(), isFalse);
  });

  test('a target with no outbound never starts an instance', () async {
    final launcher = _FakeLauncher();
    final tester = makeTester(launcher: launcher);

    final result = await measure(tester, target: 'NOPE');

    expect(result.succeeded, isFalse);
    expect(launcher.calls, isEmpty);
  });

  test('a missing binary never starts an instance', () async {
    final launcher = _FakeLauncher();
    final tester = makeTester(launcher: launcher, binary: null);

    final result = await measure(tester);

    expect(result.succeeded, isFalse);
    expect(launcher.calls, isEmpty);
    expect(await singBoxSpeedTestDir(home.path).exists(), isFalse);
  });

  test('cancelling aborts the download and tears everything down', () async {
    final launcher = _FakeLauncher();
    final download = _FakeDownload(hangUntilAbort: true);
    final tester = makeTester(launcher: launcher, download: download);

    final running = measure(tester);
    while (!download.ran) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    tester.cancel();
    final result = await running;

    expect(result.succeeded, isFalse);
    expect(launcher.processes.single.killed, isTrue);
    expect(await singBoxSpeedTestDir(home.path).exists(), isFalse);
  });

  test('a second measure is refused while one is running', () async {
    final download = _FakeDownload(hangUntilAbort: true);
    final tester = makeTester(download: download);

    final running = measure(tester);
    while (!download.ran) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final second = await measure(tester);
    expect(second.succeeded, isFalse);
    expect(second.error, contains('already running'));

    tester.cancel();
    await running;
    // Cancelling with nothing running is a no-op, not an error.
    tester.cancel();
  });

  group('the real download', () {
    test('a dead proxy port yields no reading', () async {
      final result = await SingBoxSpeedDownload().run(
        name: 'JP-03',
        proxyPort: mixedPort,
        urls: speedTestDownloadUrls,
        timeout: const Duration(seconds: 5),
        cancelled: () => false,
      );
      expect(result.succeeded, isFalse);
      expect(result.mbps, isNull);
    });

    test('a download through a proxy is metered past the warmup', () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => proxy.close(force: true));
      proxy.listen((request) async {
        final response = request.response;
        response.statusCode = HttpStatus.ok;
        response.add(List<int>.filled(600 * 1024, 7));
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 350));
        response.add(List<int>.filled(200 * 1024, 7));
        await response.close();
      });

      final result = await SingBoxSpeedDownload().run(
        name: 'JP-03',
        proxyPort: proxy.port,
        urls: ['http://speed.example/blob'],
        timeout: const Duration(seconds: 10),
        cancelled: () => false,
      );

      expect(result.succeeded, isTrue, reason: result.error);
      expect(result.totalBytes, 800 * 1024);
      expect(result.mbps, isNotNull);
      expect(result.mbps, greaterThan(0));
    });

    test(
      'a sized source is continued across requests into one window',
      () async {
        final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => proxy.close(force: true));
        var requests = 0;
        proxy.listen((request) async {
          requests++;
          final response = request.response;
          response.statusCode = HttpStatus.ok;
          response.add(List<int>.filled(300 * 1024, 7));
          await response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          response.add(List<int>.filled(300 * 1024, 7));
          await response.close();
        });

        final result = await SingBoxSpeedDownload().run(
          name: 'JP-03',
          proxyPort: proxy.port,
          urls: ['http://speed.example/__down?bytes=614400'],
          timeout: const Duration(seconds: 1),
          cancelled: () => false,
        );

        expect(result.succeeded, isTrue, reason: result.error);
        expect(requests, greaterThanOrEqualTo(3));
        expect(result.totalBytes, greaterThanOrEqualTo(3 * 600 * 1024));
        expect(result.mbps, isNotNull);
        expect(result.mbps, greaterThan(0));
      },
    );

    test('failures from every source are kept, each with its source', () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => proxy.close(force: true));
      proxy.listen((request) async {
        request.response.statusCode = request.uri.path == '/a'
            ? HttpStatus.forbidden
            : HttpStatus.notFound;
        await request.response.close();
      });

      final result = await SingBoxSpeedDownload().run(
        name: 'JP-03',
        proxyPort: proxy.port,
        urls: ['http://speed.example/a', 'http://speed.example/b'],
        timeout: const Duration(seconds: 5),
        cancelled: () => false,
      );

      expect(result.succeeded, isFalse);
      expect(result.mbps, isNull);
      expect(
        result.error,
        contains('http://speed.example/a: speed test source answered 403'),
      );
      expect(
        result.error,
        contains('http://speed.example/b: speed test source answered 404'),
      );
    });

    test(
      'a single failure keeps its own wording, with no source prefix',
      () async {
        final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => proxy.close(force: true));
        proxy.listen((request) async {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
        });

        final result = await SingBoxSpeedDownload().run(
          name: 'JP-03',
          proxyPort: proxy.port,
          urls: ['http://speed.example/a'],
          timeout: const Duration(seconds: 5),
          cancelled: () => false,
        );

        expect(result.succeeded, isFalse);
        expect(result.error, startsWith('speed test source answered 403'));
        expect(result.error, isNot(contains('http://speed.example/a:')));
      },
    );
  });
}
