import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

/// Helper de base de datos local (SQLite) para el proyecto Smart-Environment IoT.
/// Aplica el patrón **Singleton**: el constructor privado `_init()` impide crear
/// más instancias, y `instance` es el único punto de acceso. Así existe una sola
/// conexión a la base de datos en toda la app.
class DatabaseHelper {
  /// Única instancia de la clase (Singleton).
  static final DatabaseHelper instance = DatabaseHelper._init();

  /// Conexión única a la base de datos (se crea de forma perezosa).
  static Database? _database;

  /// Constructor privado: nadie fuera de esta clase puede instanciarla.
  DatabaseHelper._init();

  /// Devuelve la base de datos; si aún no existe, la inicializa.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('iot_local.db');
    return _database!;
  }

  /// Abre (o crea) el archivo de base de datos.
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
    );
  }

  /// Se ejecuta ANTES de onCreate. Activa las claves foráneas, que en SQLite
  /// vienen desactivadas por defecto en cada conexión.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Crea el esquema relacional:
  ///   nodes (1) ──< readings (N)
  ///   nodes (1) ──< alerts   (N)
  ///   readings (1) ──< alerts (N)
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE nodes (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT NOT NULL,
        location TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE readings (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        nodeId     INTEGER NOT NULL,
        sensorType TEXT NOT NULL CHECK (sensorType IN ('temperature','humidity')),
        value      REAL NOT NULL,
        timestamp  TEXT NOT NULL,
        FOREIGN KEY (nodeId) REFERENCES nodes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        nodeId    INTEGER NOT NULL,
        readingId INTEGER NOT NULL,
        message   TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (nodeId)    REFERENCES nodes (id)    ON DELETE CASCADE,
        FOREIGN KEY (readingId) REFERENCES readings (id) ON DELETE CASCADE
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // INSERCIONES (parametrizadas: sqflite enlaza los valores, no los concatena)
  // ---------------------------------------------------------------------------

  Future<int> insertNode(Node node) async {
    final db = await instance.database;
    return await db.insert('nodes', node.toMap());
  }

  Future<int> insertReading(SensorReading reading) async {
    final db = await instance.database;
    return await db.insert('readings', reading.toMap());
  }

  Future<int> insertAlert(Alert alert) async {
    final db = await instance.database;
    return await db.insert('alerts', alert.toMap());
  }

  /// Inserta un lote de lecturas en una transacción ACID: o se guardan todas
  /// o no se guarda ninguna.
  Future<void> insertBatchReadings(List<SensorReading> readings) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in readings) {
        batch.insert('readings', r.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  // ---------------------------------------------------------------------------
  // CONSULTAS (con whereArgs para evitar inyección SQL)
  // ---------------------------------------------------------------------------

  Future<List<SensorReading>> getReadingsByType(String type) async {
    final db = await instance.database;
    final result = await db.query(
      'readings',
      where: 'sensorType = ?',
      whereArgs: [type],
      orderBy: 'id DESC',
    );
    return result.map(SensorReading.fromMap).toList();
  }

  Future<List<Alert>> getAlertsByNode(int nodeId) async {
    final db = await instance.database;
    final result = await db.query(
      'alerts',
      where: 'nodeId = ?',
      whereArgs: [nodeId],
      orderBy: 'id DESC',
    );
    return result.map(Alert.fromMap).toList();
  }

  /// Borra un nodo; por ON DELETE CASCADE también se borran sus lecturas y alertas.
  Future<int> deleteNode(int id) async {
    final db = await instance.database;
    return await db.delete('nodes', where: 'id = ?', whereArgs: [id]);
  }

  /// Comprueba que PRAGMA foreign_keys esté activo (1 = activo).
  Future<bool> foreignKeysEnabled() async {
    final db = await instance.database;
    final r = await db.rawQuery('PRAGMA foreign_keys');
    return r.first.values.first == 1;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}