import 'dart:collection';

import 'package:docker_desktop/models/container_spec.dart';
import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';
import 'package:docker_desktop/screens/common/utils.dart';

class DashboardScreen extends StatefulWidget {
  final ClientDockerService svc;
  const DashboardScreen({super.key, required this.svc});

  @override
  State<StatefulWidget> createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashboardScreen> {
  List<ContainerSpec>? _runningContainers;
  String? _error;
  bool _loading = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final runningContainers = await widget.svc.listRunningContainers();
      if (!mounted) return;
      setState(() {
        _runningContainers = runningContainers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DashBoard'),
        actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _runningContainers == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sectionHeader('Running Containers',
            '${_runningContainers!.length} total', Icons.inventory),
        if (_runningContainers!.isEmpty)
          const EmptyCard(text: 'No running contaibers !')
        else
          ..._runningContainers!.map((c) => _containerCard(c)),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _runAction({
    required String id,
    required String verb,
    required Future<void> Function() action,
  }) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $verb: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _containerCard(ContainerSpec c) {
    final busy = _busy.contains(c.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            StateBadge(state: c.state),
            const SizedBox(
              width: 12,
            ),
            Text(c.name),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 10),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      onPressed: () {}, icon: const Icon(Icons.handyman)),
                  IconButton(
                      onPressed: () {}, icon: const Icon(Icons.speed_outlined))
                ],
              )
          ],
        ),
      ),
    );
  }
}
