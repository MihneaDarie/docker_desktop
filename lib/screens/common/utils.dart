import 'package:docker_desktop/models/container_spec.dart';
import 'package:flutter/material.dart';

Widget sectionHeader(String title, String subtitle, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(width: 12),
      Text(subtitle, style: TextStyle(color: Colors.grey[600])),
    ],
  );
}

class EmptyCard extends StatelessWidget {
  final String text;
  const EmptyCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(text, style: TextStyle(color: Colors.grey[600])),
        ),
      ),
    );
  }
}

class StateBadge extends StatelessWidget {
  final ContainerState state;
  const StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      ContainerState.running => ('RUN', Colors.green),
      ContainerState.stopped => ('OFF', Colors.grey),
      ContainerState.paused => ('PAU', Colors.orange),
      ContainerState.restarting => ('RST', Colors.blue),
      ContainerState.unknown => ('???', Colors.red),
    };
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style:
            TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11),
      ),
    );
  }
}
