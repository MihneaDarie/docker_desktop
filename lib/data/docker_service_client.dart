import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';

import 'docker_service.dart';
import '../models/container_spec.dart';
import '../models/image_spec.dart';
import '../models/stats_spec.dart';

class ClientDockerService implements DockerService {
  final _processes = <Process>[];

  Future<List<Map<String, dynamic>>> _runargs(List<String> args) async {
    final result = await Process.run('docker', args);
    if (result.exitCode != 0) {
      throw Exception('docker ${args.join(' ')}: ${result.stderr}');
    }
    return (result.stdout as String)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();
  }

  @override
  Future<List<ContainerSpec>> listContainers() async {
    final rows = await _runargs(['ps', '-a', '--format', '{{json .}}']);
    return rows.map((r) {
      final state = switch (r['State']) {
        'running' => ContainerState.running,
        'exited' => ContainerState.stopped,
        'paused' => ContainerState.paused,
        'restarting' => ContainerState.restarting,
        _ => ContainerState.unknown,
      };
      return ContainerSpec(
        id: r['ID'] as String,
        name: r['Names'] as String,
        image: r['Image'] as String,
        state: state,
        statusText: r['Status'] as String,
        created: DateTime.tryParse(r['CreatedAt'] as String? ?? '') ??
            DateTime.now(),
        ports: ((r['Ports'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
    }).toList();
  }

  Future<List<ContainerSpec>> listRunningContainers() async {
    final rows = await _runargs(['ps', '--format', '{{json .}}']);
    return rows.map((r) {
      const state = ContainerState.running;

      return ContainerSpec(
        id: r['ID'] as String,
        name: r['Names'] as String,
        image: r['Image'] as String,
        state: state,
        statusText: r['Status'] as String,
        created: DateTime.tryParse(r['CreatedAt'] as String? ?? '') ??
            DateTime.now(),
        ports: ((r['Ports'] as String?) ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
    }).toList();
  }

  @override
  Future<List<ImageSpec>> listImages() async {
    final rows = await _runargs(['images', '--format', '{{json .}}']);
    return rows.map((r) {
      final repo = r['Repository'] as String? ?? '<none>';
      final tag = r['Tag'] as String? ?? '<none>';
      return ImageSpec(
        id: r['ID'] as String,
        tag: '$repo:$tag',
        sizeBytes: _parseDockerSize(r['Size'] as String? ?? '0B'),
        created: DateTime.tryParse(r['CreatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> startContainer(String id) => _run(['start', id]);
  @override
  Future<void> stopContainer(String id) => _run(['stop', id]);
  @override
  Future<void> restartContainer(String id) => _run(['restart', id]);
  @override
  Future<void> removeContainer(String id, {bool force = false}) =>
      _run(['rm', if (force) '-f', id]);

  Future<void> _run(List<String> args) async {
    final r = await Process.run('docker', args);
    if (r.exitCode != 0) {
      throw Exception('docker ${args.join(' ')}: ${r.stderr}');
    }
  }

  @override
  Future<String> createContainer({
    required String image,
    String? name,
    List<String>? cmd,
  }) async {
    final args = [
      'run',
      '-d',
      if (name != null) ...['--name', name],
      image,
      ...?cmd,
    ];
    final r = await Process.run('docker', args);
    if (r.exitCode != 0) throw Exception('docker run: ${r.stderr}');
    return (r.stdout as String).trim();
  }

  @override
  Stream<String> streamLogs(String id) async* {
    final proc =
        await Process.start('docker', ['logs', '-f', '--tail', '100', id]);
    _processes.add(proc);
    yield* StreamGroup.merge([
      proc.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      proc.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    ]);
  }

  @override
  Stream<StatsSpec> streamStats(String id) async* {
    while (true) {
      try {
        final result = await Process.run(
          'docker',
          ['stats', '--no-stream', '--format', '{{json .}}', id],
        );
        if (result.exitCode != 0) {
          return;
        }
        final line = (result.stdout as String).trim();
        if (line.isEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        final json = jsonDecode(line) as Map<String, dynamic>;
        yield _parseStatsJson(id, json);
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  StatsSpec _parseStatsJson(String id, Map<String, dynamic> r) {
    return StatsSpec(
      containerId: id,
      cpuPercent: _parsePercent(r['CPUPerc'] as String? ?? '0%'),
      memoryBytes: _parseMemUsage(r['MemUsage'] as String? ?? '0B / 0B').$1,
      memoryLimitBytes:
          _parseMemUsage(r['MemUsage'] as String? ?? '0B / 0B').$2,
      networkRxBytes: 0,
      networkTxBytes: 0,
    );
  }

  @override
  Future<void> killprocesses() async {
    for (final p in _processes) {
      p.kill();
    }
  }

  static double _parsePercent(String s) =>
      double.tryParse(s.replaceAll('%', '').trim()) ?? 0;

  static (int, int) _parseMemUsage(String s) {
    final parts = s.split('/');
    if (parts.length != 2) return (0, 0);
    return (
      _parseDockerSize(parts[0].trim()),
      _parseDockerSize(parts[1].trim()),
    );
  }

  static int _parseDockerSize(String s) {
    final match = RegExp(r'([\d.]+)\s*([KMGT]?i?B)').firstMatch(s);
    if (match == null) return 0;
    final num = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!;
    const mult = {
      'B': 1,
      'kB': 1000,
      'KB': 1024,
      'KiB': 1024,
      'MB': 1000 * 1000,
      'MiB': 1024 * 1024,
      'GB': 1000 * 1000 * 1000,
      'GiB': 1024 * 1024 * 1024,
      'TB': 1000 * 1000 * 1000 * 1000,
      'TiB': 1024 * 1024 * 1024 * 1024,
    };
    return (num * (mult[unit] ?? 1)).toInt();
  }
}
