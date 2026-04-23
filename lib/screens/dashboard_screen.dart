import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';

class DashboardScreen extends StatelessWidget {
  final ClientDockerService svc;
  const DashboardScreen({super.key, required this.svc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
    );
  }
}
