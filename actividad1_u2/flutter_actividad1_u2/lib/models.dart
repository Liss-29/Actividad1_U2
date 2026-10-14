// Modelos de entidad del esquema IoT.

class Node {
  final int? id;
  final String name;
  final String location;

  Node({this.id, required this.name, required this.location});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'location': location};
}

class SensorReading {
  final int? id;
  final int nodeId; // FK -> nodes.id
  final String sensorType; // 'temperature' | 'humidity'
  final double value;
  final String timestamp; // ISO-8601

  SensorReading({
    this.id,
    required this.nodeId,
    required this.sensorType,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nodeId': nodeId,
        'sensorType': sensorType,
        'value': value,
        'timestamp': timestamp,
      };

  factory SensorReading.fromMap(Map<String, dynamic> m) => SensorReading(
        id: m['id'] as int?,
        nodeId: m['nodeId'] as int,
        sensorType: m['sensorType'] as String,
        value: (m['value'] as num).toDouble(),
        timestamp: m['timestamp'] as String,
      );
}

class Alert {
  final int? id;
  final int nodeId; // FK -> nodes.id
  final int readingId; // FK -> readings.id
  final String message;
  final String createdAt;

  Alert({
    this.id,
    required this.nodeId,
    required this.readingId,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nodeId': nodeId,
        'readingId': readingId,
        'message': message,
        'createdAt': createdAt,
      };

  factory Alert.fromMap(Map<String, dynamic> m) => Alert(
        id: m['id'] as int?,
        nodeId: m['nodeId'] as int,
        readingId: m['readingId'] as int,
        message: m['message'] as String,
        createdAt: m['createdAt'] as String,
      );
}