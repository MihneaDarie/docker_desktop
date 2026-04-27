import '../models/container_spec.dart';
import '../models/image_spec.dart';
import '../models/stats_spec.dart';

abstract class DockerService {
  Future<List<ContainerSpec>> listContainers();
  Future<List<ImageSpec>> listImages();

  Future<void> startContainer(String id);
  Future<void> stopContainer(String id);
  Future<void> restartContainer(String id);
  Future<void> removeContainer(String id, {bool force = false});

  Future<String> execCommand(String id, List<String> cmd);

  Future<String> createContainer({
    required String image,
    String? name,
    List<String>? cmd,
  });

  Stream<String> streamLogs(String id);
  Stream<StatsSpec> streamStats(String id);

  Future<void> killprocesses();
}
