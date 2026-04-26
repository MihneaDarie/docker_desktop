import 'dart:async';

import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';
import 'package:docker_desktop/models/container_spec.dart';
import 'package:docker_desktop/models/stats_spec.dart';
import 'package:docker_desktop/screens/common/utils.dart';

class DashboardScreen extends StatefulWidget {
  final ClientDockerService svc;
  const DashboardScreen({super.key, required this.svc});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ContainerSpec>? _running;
  final Map<String, StatsSpec> _latest = {};
  final List<StreamSubscription<StatsSpec>> _subs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    setState(() {
      _latest.clear();
      _running = null;
      _error = null;
    });

    try {
      final running = await widget.svc.listRunningContainers();

      if (!mounted) return;
      setState(() => _running = running);

      for (final c in running) {
        final sub = widget.svc.streamStats(c.id).listen(
          (stats) {
            if (!mounted) return;
            setState(() => _latest[c.id] = stats);
          },
          onError: (_) {},
        );
        _subs.add(sub);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  double get _totalCpu =>
      _latest.values.fold(0.0, (sum, s) => sum + s.cpuPercent);

  int get _totalMemUsed =>
      _latest.values.fold(0, (sum, s) => sum + s.memoryBytes);

  int get _hostMemoryTotal =>
      _latest.isEmpty ? 0 : _latest.values.first.memoryLimitBytes;

  double get _memPercent =>
      _hostMemoryTotal > 0 ? (_totalMemUsed / _hostMemoryTotal) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _running == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_running!.isEmpty) {
      return const Center(child: EmptyCard(text: 'No running containers'));
    }

    final byCpu = _latest.values.toList()
      ..sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sectionHeader(
          'System',
          '${_running!.length} running',
          Icons.speed,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total CPU',
                value: '${_totalCpu.toStringAsFixed(1)}%',
                progress: (_totalCpu / 100).clamp(0.0, 1.0),
                icon: Icons.memory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Total Memory',
                value:
                    '${_fmtMiB(_totalMemUsed)} / ${_fmtMiB(_hostMemoryTotal)}',
                subtitle: '${_memPercent.toStringAsFixed(1)}% of host',
                progress: (_memPercent / 100).clamp(0.0, 1.0),
                icon: Icons.sd_card,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        sectionHeader(
          'By Container',
          '${_latest.length} reporting',
          Icons.list_alt,
        ),
        const SizedBox(height: 8),
        if (byCpu.isEmpty)
          const EmptyCard(text: 'Waiting for first containers...')
        else
          ...byCpu.map((s) => _PerContainerRow(
                stats: s,
                container: _running!.firstWhere(
                  (c) => c.id == s.containerId,
                  orElse: () => _placeholder(s.containerId),
                ),
              )),
      ],
    );
  }

  static String _fmtMiB(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB';

  static ContainerSpec _placeholder(String id) => ContainerSpec(
        id: id,
        name: id,
        image: '?',
        state: ContainerState.unknown,
        statusText: '',
        created: DateTime.now(),
        ports: const [],
      );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final double progress;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerContainerRow extends StatelessWidget {
  final StatsSpec stats;
  final ContainerSpec container;

  const _PerContainerRow({required this.stats, required this.container});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            StateBadge(state: container.state),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(container.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(container.image,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Text('${stats.cpuPercent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
            SizedBox(
              width: 100,
              child: Text(
                '${(stats.memoryBytes / 1024 / 1024).toStringAsFixed(1)} MiB',
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
