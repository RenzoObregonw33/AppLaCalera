import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  /// Reemplaza la blacklist local con la lista recibida de la API
  static Future<void> updateBlacklist(List<dynamic> blacklist) async {
    final db = await database;
    // Borra la tabla blacklist
    await db.delete(tableBlacklist);
    // Inserta los nuevos datos
    for (final item in blacklist) {
      await db.insert(tableBlacklist, {
        'dni': item['document'],
        'reason': item['reason'] ?? 'Sin motivo',
        'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    print('✅ Blacklist actualizada (${blacklist.length} registros)');
  }

  // Verifica si el DNI ya existe en la tabla personas
  static Future<bool> dniExiste(String dni) async {
    final db = await database;
    final result = await db.query(
      tablePersonas,
      where: 'dni = ?',
      whereArgs: [dni],
    );
    return result.isNotEmpty;
  }

  /// Verifica si un DNI está en la blacklist local
  /// Borra la tabla local de blacklist y la reemplaza con los datos recibidos de la API
  static Database? _database;
  static const String _dbName = 'personas.db';
  static const int _dbVersion = 4; // ✅ INCREMENTA a 4

  // Tablas
  static const String tablePersonas = 'personas';
  static const String tableBlacklist = 'blacklist';

  // Getter de la base
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initializeDatabase();
    return _database!;
  }

  static Future<Database> initializeDatabase() async {
    final dbPath = join(await getDatabasesPath(), _dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        print("📦 Creando base de datos en $dbPath");
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print("⚡ Migrando BD de v$oldVersion → v$newVersion");
        await _upgradeDatabase(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Crear tabla personas
    await db.execute('''
      CREATE TABLE $tablePersonas(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        nombre TEXT, 
        apellidoPaterno TEXT,  
        dni TEXT UNIQUE, 
        telefono TEXT, 
        modeloContrato TEXT, 
        fotoDniFrente TEXT,
        fotoDniReverso TEXT,
        isBlacklisted INTEGER DEFAULT 0,
        organi_id INTEGER,
        enviadaNube INTEGER DEFAULT 0,
        fechaRegistro TEXT
      )
    ''');

    // Crear tabla blacklist
    await db.execute('''
      CREATE TABLE $tableBlacklist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT UNIQUE,
        reason TEXT,
        created_at TEXT
      )
    ''');

    await _insertDefaultBlacklistedDnis(db);
    print("✅ Tablas creadas correctamente");
  }

  static Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migración paso a paso
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
  }

  static Future<void> _migrateToV2(Database db) async {
    // Migración para versión 2 (si existiera)
    print("🔄 Migrando a v2");
  }

  static Future<void> _migrateToV3(Database db) async {
    print("🔄 Migrando a v3");

    // Asegurar tabla blacklist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBlacklist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT UNIQUE,
        reason TEXT,
        created_at TEXT
      )
    ''');
    await _insertDefaultBlacklistedDnis(db);
  }

  static Future<void> _migrateToV4(Database db) async {
    print("🔄 Migrando a v4 - Agregando columna modeloContrato");

    try {
      // Verificar si la columna modeloContrato ya existe
      final columns = await db.rawQuery("PRAGMA table_info($tablePersonas)");
      final hasModeloContrato = columns.any(
        (column) => column['name'] == 'modeloContrato',
      );

      if (!hasModeloContrato) {
        // Agregar la columna faltante
        await db.execute(
          'ALTER TABLE $tablePersonas ADD COLUMN modeloContrato TEXT',
        );
        print("✅ Columna 'modeloContrato' agregada a la tabla personas");

        // Actualizar registros existentes con un valor por defecto
        await db.update(tablePersonas, {
          'modeloContrato': 'operario',
        }, where: 'modeloContrato IS NULL');
      }
    } catch (e) {
      print("❌ Error en migración v4: $e");
      // Si falla, recrear la tabla
      await _recreateTables(db);
    }
  }

  static Future<void> _recreateTables(Database db) async {
    print("🔄 Recreando tablas...");

    // Eliminar tablas existentes
    await db.execute('DROP TABLE IF EXISTS $tablePersonas');
    await db.execute('DROP TABLE IF EXISTS $tableBlacklist');

    // Crear tablas nuevamente
    await _createTables(db);
  }

  // Insertar DNIs de ejemplo
  static Future<void> _insertDefaultBlacklistedDnis(Database db) async {
    final defaultDnis = [
      {'dni': '12345678', 'reason': 'Ejemplo 1'},
      {'dni': '87654321', 'reason': 'Ejemplo 2'},
      {'dni': '11111111', 'reason': 'Ejemplo 3'},
      {'dni': '22222222', 'reason': 'Ejemplo 4'},
      {'dni': '33333333', 'reason': 'Ejemplo 5'},
    ];

    for (var dniData in defaultDnis) {
      await db.insert(tableBlacklist, {
        'dni': dniData['dni'],
        'reason': dniData['reason'],
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    print("🛡️ Blacklist inicial cargada (${defaultDnis.length} DNIs)");
  }

  // Insertar persona con manejo de errores mejorado
  static Future<int> insertPerson(
    Map<String, dynamic> person,
    BuildContext context,
  ) async {
    try {
      final db = await database;

      // Verificar que todos los campos requeridos estén presentes
      final completePerson = {
        'nombre': person['nombre'] ?? '',
        'apellidoPaterno': person['apellidoPaterno'] ?? '',
        'dni': person['dni'] ?? '',
        'telefono': person['telefono'] ?? '',
        'modeloContrato': person['modeloContrato'] ?? 'operario',
        'fotoDniFrente': person['fotoDniFrente'] ?? '',
        'fotoDniReverso': person['fotoDniReverso'] ?? '',
        'isBlacklisted': person['isBlacklisted'] ?? 0,
        'organi_id': person['organi_id'] ?? 0,
        'enviadaNube': person['enviadaNube'] ?? 0,
        'fechaRegistro': DateTime.now().toIso8601String(),
      };

      final id = await db.insert(
        tablePersonas,
        completePerson,
        conflictAlgorithm: ConflictAlgorithm.ignore, // <-- Ignora duplicados
      );

      if (id == 0) {
        // El registro no se insertó porque el DNI ya existe
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El DNI ya está registrado")),
        );
      } else {
        print("✅ Persona insertada con ID: $id");
      }
      return id;
    } catch (e) {
      print("❌ Error insertando persona: $e");
      // Debug adicional
      await debugDatabase();
      rethrow;
    }
  }

  // Obtener personas
  static Future<List<Map<String, dynamic>>> getPeople() async {
    try {
      final db = await database;
      final result = await db.query(tablePersonas);
      print("📂 Se encontraron ${result.length} personas en BD");
      return result;
    } catch (e) {
      print("❌ Error obteniendo personas: $e");
      return [];
    }
  }

  // Métodos Blacklist
  static Future<bool> isDniBlacklisted(String dni) async {
    try {
      final db = await database;
      final result = await db.query(
        tableBlacklist,
        where: 'dni = ?',
        whereArgs: [dni],
      );
      return result.isNotEmpty;
    } catch (e) {
      print("❌ Error verificando blacklist: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBlacklist() async {
    try {
      final db = await database;
      return await db.query(tableBlacklist);
    } catch (e) {
      print("❌ Error obteniendo blacklist: $e");
      return [];
    }
  }

  static Future<int> addToBlacklist(String dni, {String? reason}) async {
    try {
      final db = await database;
      return await db.insert(tableBlacklist, {
        'dni': dni,
        'reason': reason ?? 'Añadido manualmente',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print("❌ Error añadiendo a blacklist: $e");
      return -1;
    }
  }

  static Future<int> removeFromBlacklist(String dni) async {
    try {
      final db = await database;
      return await db.delete(
        tableBlacklist,
        where: 'dni = ?',
        whereArgs: [dni],
      );
    } catch (e) {
      print("❌ Error eliminando de blacklist: $e");
      return -1;
    }
  }

  static Future<void> debugDatabase() async {
    try {
      final db = await database;
      final path = await getDatabasesPath();
      print('📊 DEBUG DATABASE INFO:');
      print('• Ruta: $path');
      print('• Versión: ${await db.getVersion()}');

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      print('• Tablas: ${tables.map((t) => t['name']).toList()}');

      for (var table in tables) {
        if (table['name'] == 'personas') {
          final columns = await db.rawQuery("PRAGMA table_info(personas)");
          print('• Columnas de personas:');
          for (var col in columns) {
            print('  - ${col['name']} (${col['type']})');
          }
        }
        final count = await db.rawQuery(
          'SELECT COUNT(*) as c FROM ${table['name']}',
        );
        print('• ${table['name']}: ${count.first['c']} registros');
      }
    } catch (e) {
      print('❌ Error en debug: $e');
    }
  }

  // Método para resetear la BD (solo desarrollo)
  static Future<void> resetDatabase() async {
    try {
      final dbPath = join(await getDatabasesPath(), _dbName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Base de datos eliminada, se recreará con el nuevo esquema');
      }
      _database = null;
      await database; // Esto recreará la BD
    } catch (e) {
      print('❌ Error reseteando BD: $e');
    }
  }

  // 🔥 NUEVO MÉTODO: Sincronizar blacklist desde la API
  static Future<bool> syncBlacklistFromApi(List<dynamic> blacklistData) async {
    try {
      final db = await database;

      // Limpiar blacklist existente
      await db.delete(tableBlacklist);

      // Insertar nuevos datos
      for (var item in blacklistData) {
        await db.insert(tableBlacklist, {
          'dni': item['document']?.toString() ?? '',
          'reason': item['reason']?.toString() ?? 'Sin motivo',
          'created_at':
              item['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      print("✅ Blacklist sincronizada: ${blacklistData.length} registros");
      return true;
    } catch (e) {
      print("❌ Error sincronizando blacklist: $e");
      return false;
    }
  }

  // 🔥 MEJORAR método de verificación de DNI
  static Future<Map<String, dynamic>> checkDniInBlacklist(String dni) async {
    try {
      final db = await database;
      final result = await db.query(
        tableBlacklist,
        where: 'dni = ?',
        whereArgs: [dni],
      );

      return {
        'isBlacklisted': result.isNotEmpty,
        'data': result.isNotEmpty ? result.first : null,
      };
    } catch (e) {
      print("❌ Error verificando blacklist: $e");
      return {'isBlacklisted': false, 'data': null};
    }
  }

  // Marcar registro como enviado
  static Future<void> marcarEnviado(int id) async {
    final db = await database;
    await db.update(
      tablePersonas,
      {'enviadaNube': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
