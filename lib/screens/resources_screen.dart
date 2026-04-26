import 'package:docker_desktop/screens/common/container_card.dart';
import 'package:docker_desktop/screens/common/utils.dart';
import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';
import 'package:docker_desktop/models/container_spec.dart';
import 'package:docker_desktop/models/image_spec.dart';

class ResourcesScreen extends StatefulWidget {
  final ClientDockerService svc;
  const ResourcesScreen({super.key, required this.svc});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  List<ContainerSpec>? _containers;
  List<ImageSpec>? _images;
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
      final containers = await widget.svc.listContainers();
      final images = await widget.svc.listImages();
      if (!mounted) return;
      setState(() {
        _containers = containers;
        _images = images;
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

  Future<void> _createFromImage(String imageTag) async {
    final name = await _askForName(imageTag);
    if (name == null) return;
    try {
      await widget.svc.createContainer(
        image: imageTag,
        name: name.isEmpty ? null : name,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create: $e')),
      );
    }
  }

  Future<String?> _askForName(String imageTag) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Run $imageTag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Container name',
            hintText: 'leave blank for random name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Run'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(ContainerSpec c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${c.name}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _runAction(
        id: c.id,
        verb: 'remove',
        action: () => widget.svc.removeContainer(c.id, force: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Containers & Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _containers == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sectionHeader(
            'Containers', '${_containers!.length} total', Icons.inventory_2),
        const SizedBox(height: 8),
        if (_containers!.isEmpty)
          const EmptyCard(text: 'No containers yet')
        else
          ..._containers!.map((c) => ContainerCard(
                container: c,
                svc: widget.svc,
                busy: _busy.contains(c.id),
                onStart: () => _runAction(
                  id: c.id,
                  verb: 'start',
                  action: () => widget.svc.startContainer(c.id),
                ),
                onStop: () => _runAction(
                  id: c.id,
                  verb: 'stop',
                  action: () => widget.svc.stopContainer(c.id),
                ),
                onRestart: () => _runAction(
                  id: c.id,
                  verb: 'restart',
                  action: () => widget.svc.restartContainer(c.id),
                ),
                onRemove: () => _confirmRemove(c),
              )),
        const SizedBox(height: 24),
        sectionHeader('Images', '${_images!.length} pulled', Icons.layers),
        const SizedBox(height: 8),
        if (_images!.isEmpty)
          const EmptyCard(text: 'No images pulled')
        else
          ..._images!.map((i) => _imageCard(i)),
      ],
    );
  }

  Widget _imageCard(ImageSpec i) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.layers, size: 32),
        title: Text(i.tag, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${i.shortId} · ${(i.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MiB'),
        trailing: FilledButton.tonalIcon(
          icon: const Icon(Icons.plus_one),
          label: const Text('Create container'),
          onPressed: () => _createFromImage(i.tag),
        ),
      ),
    );
  }
}
