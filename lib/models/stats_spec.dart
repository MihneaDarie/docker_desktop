class StatsSpec {
  final String containerId;
  final double cpuPercent;
  final int memoryBytes;
  final int memoryLimitBytes;
  final int networkRxBytes;
  final int networkTxBytes;

  StatsSpec({
    required this.containerId,
    required this.cpuPercent,
    required this.memoryBytes,
    required this.memoryLimitBytes,
    required this.networkRxBytes,
    required this.networkTxBytes,
  });

  double get memoryPercent =>
      memoryLimitBytes > 0 ? (memoryBytes / memoryLimitBytes) * 100 : 0;
}