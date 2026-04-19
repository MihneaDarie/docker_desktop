enum ContainerState { running, stopped, paused, restarting, unknown }

class ContainerSpec {
  final String id;
  final String name;
  final String image;
  final ContainerState state;
  final String statusText;
  final DateTime created;
  final List<String> ports;

  ContainerSpec({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.statusText,
    required this.created,
    required this.ports,
  });

  String get shortId => id.length > 12 ? id.substring(0, 12) : id;
  bool get isRunning => state == ContainerState.running;
}
