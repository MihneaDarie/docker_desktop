import 'dart:async';

import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';
import 'package:docker_desktop/models/container_spec.dart';
import 'package:docker_desktop/models/stats_spec.dart';
import 'package:docker_desktop/screens/common/utils.dart';

class ContainerCard extends StatefulWidget {
  final ContainerSpec container;
  final ClientDockerService svc;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onRemove;

  const ContainerCard({
    super.key,
    required this.container,
    required this.svc,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onRemove,
  });

  @override
  State<ContainerCard> createState() => _ContainerCardState();
}

class _ContainerCardState extends State<ContainerCard> {
  bool _logsOpen = false;
  bool _statsOpen = false;

  void _toggleLogs() {
    setState(() {
      _logsOpen = !_logsOpen;
      if (_logsOpen) _statsOpen = false;
    });
  }

  void _toggleStats() {
    setState(() {
      _statsOpen = !_statsOpen;
      if (_statsOpen) _logsOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.container;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                StateBadge(state: c.state),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(c.image,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13)),
                      Text('${c.shortId} · ${c.statusText}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                if (widget.busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!c.isRunning)
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          tooltip: 'Start',
                          color: Colors.green,
                          onPressed: widget.onStart,
                        ),
                      if (c.isRunning)
                        IconButton(
                          icon: const Icon(Icons.stop),
                          tooltip: 'Stop',
                          color: Colors.orange,
                          onPressed: widget.onStop,
                        ),
                      IconButton(
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Restart',
                        color: Colors.lightBlue,
                        onPressed: widget.onRestart,
                      ),
                      IconButton(
                        icon: Icon(_logsOpen
                            ? Icons.handyman
                            : Icons.handyman_outlined),
                        tooltip: _logsOpen ? 'Hide logs' : 'Show logs',
                        onPressed: _toggleLogs,
                      ),
                      IconButton(
                        icon: Icon(
                            _statsOpen ? Icons.speed : Icons.speed_outlined),
                        tooltip: _statsOpen ? 'Hide stats' : 'Show stats',
                        onPressed: _toggleStats,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        color: Colors.red,
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: (_logsOpen || _statsOpen) ? 400 : 0,
              child: _logsOpen
                  ? _LogsPanel(svc: widget.svc, containerId: c.id)
                  : _statsOpen
                      ? _StatsPanel(svc: widget.svc, containerId: c.id)
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsPanel extends StatefulWidget {
  final ClientDockerService svc;
  final String containerId;

  const _LogsPanel({required this.svc, required this.containerId});

  @override
  State<_LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<_LogsPanel> {
  final List<String> _lines = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription<String>? _sub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = widget.svc.streamLogs(widget.containerId).listen(
      (line) {
        if (!mounted) return;
        setState(() => _lines.add(line));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: _error != null
          ? Center(
              child: Text('Error: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
            )
          : _lines.isEmpty
              ? const Center(
                  child: Text('Waiting for logs...',
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _lines.length,
                  itemBuilder: (_, i) => SelectableText(
                    _lines[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final ClientDockerService svc;
  final String containerId;

  const _StatsPanel({required this.svc, required this.containerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StatsSpec>(
      stream: svc.streamStats(containerId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snap.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _percentageBar('CPU', '${s.cpuPercent.toStringAsFixed(1)}%',
                  s.cpuPercent / 100),
              const SizedBox(height: 16),
              _percentageBar(
                'Memory',
                '${(s.memoryBytes / 1024 / 1024).toStringAsFixed(1)} / '
                    '${(s.memoryLimitBytes / 1024 / 1024).toStringAsFixed(1)} MiB',
                s.memoryPercent / 100,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _percentageBar(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
