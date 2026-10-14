import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // 1. Importa el paquete ffi
import 'database_helper.dart';
import 'models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa FFI y asigna el databaseFactory
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final List<String> _log = [];
  final _db = DatabaseHelper.instance;

  void _add(String msg) => setState(() => _log.insert(0, msg));

  Future<void> _checkPragma() async {
    final on = await _db.foreignKeysEnabled();
    _add('PRAGMA foreign_keys = ${on ? "ON ✔" : "OFF ✘"}');
  }

  Future<void> _insertTestData() async {
    final nodeId = await _db.insertNode(
      Node(name: 'ESP32_01', location: 'Laboratorio'),
    );
    final now = DateTime.now().toIso8601String();

    await _db.insertBatchReadings([
      SensorReading(nodeId: nodeId, sensorType: 'temperature', value: 28.5, timestamp: now),
      SensorReading(nodeId: nodeId, sensorType: 'temperature', value: 36.2, timestamp: now),
      SensorReading(nodeId: nodeId, sensorType: 'humidity', value: 60.0, timestamp: now),
    ]);

    // Alerta para la lectura que supera el umbral (35 °C)
    final temps = await _db.getReadingsByType('temperature');
    for (final r in temps.where((r) => r.value > 35.0)) {
      await _db.insertAlert(Alert(
        nodeId: r.nodeId,
        readingId: r.id!,
        message: 'Temperatura alta: ${r.value} °C',
        createdAt: now,
      ));
    }
    _add('Datos de prueba insertados (nodo $nodeId).');
  }

  Future<void> _queryTemps() async {
    final temps = await _db.getReadingsByType('temperature');
    if (temps.isEmpty) {
      _add('Sin lecturas de temperatura.');
      return;
    }
    for (final r in temps) {
      _add('TEMP #${r.id} nodo ${r.nodeId}: ${r.value} °C');
    }
  }

  Future<void> _testForeignKey() async {
    try {
      await _db.insertReading(SensorReading(
        nodeId: 999, // nodo inexistente
        sensorType: 'temperature',
        value: 20,
        timestamp: DateTime.now().toIso8601String(),
      ));
      _add('✘ Se insertó (las FK NO están activas)');
    } catch (e) {
      _add('✔ FK bloqueó la inserción inválida: $e');
    }
  }

  Future<void> _deleteFirstNode() async {
    final n = await _db.deleteNode(1);
    _add('Nodo 1 eliminado ($n fila). Sus lecturas y alertas se borran en cascada.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actividad 1 U2 - SQLite')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(onPressed: _checkPragma, child: const Text('Verificar PRAGMA')),
              ElevatedButton(onPressed: _insertTestData, child: const Text('Insertar datos')),
              ElevatedButton(onPressed: _queryTemps, child: const Text('Consultar temp.')),
              ElevatedButton(onPressed: _testForeignKey, child: const Text('Probar FK')),
              ElevatedButton(onPressed: _deleteFirstNode, child: const Text('Borrar nodo 1')),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (_, i) => ListTile(dense: true, title: Text(_log[i])),
            ),
          ),
        ],
      ),
    );
  }
}