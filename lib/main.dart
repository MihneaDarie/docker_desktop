import 'package:docker_desktop/data/docker_service_client.dart';
import 'package:docker_desktop/models/image_spec.dart';
import 'package:flutter/material.dart';
import 'models/container_spec.dart';

void main() {
  runApp(const MaterialApp(home: TestScreen()));
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _svc = ClientDockerService();
  List<ContainerSpec>? _containers;
  List<ImageSpec>? _images;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final containers = await _svc.listContainers();
      final images = await _svc.listImages();
      if (!mounted) return;
      setState(() {
        _containers = containers;
        _images = images;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _svc.killprocesses();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Docker test')),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : (_containers == null)
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    const ListTile(
                      title: Text('Containers',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (_containers!.isEmpty)
                      const ListTile(title: Text('(none)')),
                    for (final c in _containers!)
                      ListTile(
                        dense: true,
                        title: Text('${c.name} — ${c.image}'),
                        subtitle: Text('${c.shortId}  ${c.state.name}  ${c.statusText}'),
                      ),
                    const Divider(),
                    const ListTile(
                      title: Text('Images',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (_images!.isEmpty)
                      const ListTile(title: Text('(none)')),
                    for (final i in _images!)
                      ListTile(
                        dense: true,
                        title: Text(i.tag),
                        subtitle: Text(
                            '${i.shortId}  ${(i.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MiB'),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _load,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}