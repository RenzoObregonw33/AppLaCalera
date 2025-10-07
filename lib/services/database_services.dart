import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  /// Reemplaza la blacklist local con la lista recibida de la API
  static Future<void> updateBlacklist(
    List<dynamic> blacklist, {
    int? organiId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
    final db = await getDatabaseForOrganization(targetOrganiId);

    // Borra la tabla blacklist solo para esta organización
    await db.delete(
      tableBlacklist,
      where: 'organi_id = ?',
      whereArgs: [targetOrganiId],
    );

    // Inserta los nuevos datos
    for (final item in blacklist) {
      await db.insert(tableBlacklist, {
        'dni': item['document'],
        'organi_id': targetOrganiId,
        'reason': item['reason'] ?? 'Sin motivo',
        'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // Verifica si el DNI ya existe en la tabla personas
  static Future<bool> dniExiste(String dni, {int? organiId}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
    final db = await getDatabaseForOrganization(targetOrganiId);
    final result = await db.query(
      tablePersonas,
      where: 'dni = ?',
      whereArgs: [dni],
    );
    return result.isNotEmpty;
  }

  /// Verifica si un DNI está en la blacklist local
  /// Borra la tabla local de blacklist y la reemplaza con los datos recibidos de la API
  static final Map<int, Database> _databases = {};
  static const String _dbNamePrefix = 'personas_org_';
  static const int _dbVersion =
      5; // ✅ INCREMENTA a 5 para blacklist por organización

  // Tablas
  static const String tablePersonas = 'personas';
  static const String tableBlacklist = 'blacklist';

  // Getter de la base para organización específica
  static Future<Database> getDatabaseForOrganization(int organiId) async {
    if (_databases.containsKey(organiId)) {
      return _databases[organiId]!;
    }
    _databases[organiId] = await initializeDatabase(organiId);
    return _databases[organiId]!;
  }

  // Getter de la base (usa organización por defecto desde SharedPreferences)
  static Future<Database> get database async {
    final prefs = await SharedPreferences.getInstance();
    final organiId = prefs.getInt('organi_id') ?? 0;
    return await getDatabaseForOrganization(organiId);
  }

  static Future<Database> initializeDatabase(int organiId) async {
    final dbName = '${_dbNamePrefix}${organiId}.db';
    final dbPath = join(await getDatabasesPath(), dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
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
        dni TEXT,
        reason TEXT,
        created_at TEXT,
        organi_id INTEGER,
        UNIQUE(dni, organi_id)
      )
    ''');
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
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
  }

  static Future<void> _migrateToV2(Database db) async {
    // Migración para versión 2 (si existiera)
  }

  static Future<void> _migrateToV3(Database db) async {
    // Asegurar tabla blacklist (sin organi_id aún)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBlacklist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT UNIQUE,
        reason TEXT,
        created_at TEXT
      )
    ''');
  }

  static Future<void> _migrateToV4(Database db) async {
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

        // Actualizar registros existentes con un valor por defecto
        await db.update(tablePersonas, {
          'modeloContrato': 'operario',
        }, where: 'modeloContrato IS NULL');
      }
    } catch (e) {
      // Si falla, recrear la tabla
      await _recreateTables(db);
    }
  }

  static Future<void> _migrateToV5(Database db) async {
    try {
      // Verificar si la columna organi_id ya existe en blacklist
      final columns = await db.rawQuery("PRAGMA table_info($tableBlacklist)");
      final hasOrganiId = columns.any(
        (column) => column['name'] == 'organi_id',
      );

      if (!hasOrganiId) {
        // Agregar la columna organi_id
        await db.execute(
          'ALTER TABLE $tableBlacklist ADD COLUMN organi_id INTEGER DEFAULT 0',
        );

        // Quitar la restricción UNIQUE de dni solo, ahora será UNIQUE(dni, organi_id)
        // Recrear la tabla con la nueva estructura
        await db.execute(
          'ALTER TABLE $tableBlacklist RENAME TO ${tableBlacklist}_old',
        );

        await db.execute('''
          CREATE TABLE $tableBlacklist(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dni TEXT,
            reason TEXT,
            created_at TEXT,
            organi_id INTEGER,
            UNIQUE(dni, organi_id)
          )
        ''');

        // Migrar datos existentes
        await db.execute('''
          INSERT INTO $tableBlacklist (dni, reason, created_at, organi_id)
          SELECT dni, reason, created_at, 0 FROM ${tableBlacklist}_old
        ''');

        // Eliminar tabla antigua
        await db.execute('DROP TABLE ${tableBlacklist}_old');
        print("✅ Tabla blacklist reestructurada para soportar organizaciones");
      }
    } catch (e) {
      print("❌ Error en migración v5: $e");
    }
  }

  static Future<void> _recreateTables(Database db) async {
    // Eliminar tablas existentes
    await db.execute('DROP TABLE IF EXISTS $tablePersonas');
    await db.execute('DROP TABLE IF EXISTS $tableBlacklist');

    // Crear tablas nuevamente
    await _createTables(db);
  }

  // Insertar persona con manejo de errores mejorado
  static Future<int> insertPerson(
    Map<String, dynamic> person,
    BuildContext context, {
    int? organiId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
      final db = await getDatabaseForOrganization(targetOrganiId);

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
        // Registro insertado exitosamente
      }
      return id;
    } catch (e) {
      rethrow;
    }
  }

  // Obtener personas
  static Future<List<Map<String, dynamic>>> getPeople({int? organiId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
      final db = await getDatabaseForOrganization(targetOrganiId);
      final result = await db.query(tablePersonas);
      return result;
    } catch (e) {
      return [];
    }
  }

  // Métodos Blacklist
  static Future<bool> isDniBlacklisted(String dni, int organiId) async {
    try {
      final db = await getDatabaseForOrganization(organiId);

      final result = await db.query(
        tableBlacklist,
        where: 'dni = ? AND organi_id = ?',
        whereArgs: [dni, organiId],
      );

      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBlacklist(int organiId) async {
    try {
      final db = await getDatabaseForOrganization(organiId);
      final result = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
        orderBy: 'created_at DESC',
      );
      return result;
    } catch (e) {
      return [];
    }
  }

  static Future<int> addToBlacklist(
    String dni,
    int organiId, {
    String? reason,
  }) async {
    try {
      final db = await getDatabaseForOrganization(organiId);
      return await db.insert(tableBlacklist, {
        'dni': dni,
        'organi_id': organiId,
        'reason': reason ?? 'Añadido manualmente',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print("❌ Error añadiendo a blacklist: $e");
      return -1;
    }
  }

  static Future<int> removeFromBlacklist(String dni, int organiId) async {
    try {
      final db = await getDatabaseForOrganization(organiId);
      return await db.delete(
        tableBlacklist,
        where: 'dni = ? AND organi_id = ?',
        whereArgs: [dni, organiId],
      );
    } catch (e) {
      print("❌ Error eliminando de blacklist: $e");
      return -1;
    }
  }

  // Método para resetear la BD (solo desarrollo)
  static Future<void> resetDatabase({int? organiId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
      final dbName = '${_dbNamePrefix}${targetOrganiId}.db';
      final dbPath = join(await getDatabasesPath(), dbName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
      _databases.remove(targetOrganiId);
      await getDatabaseForOrganization(targetOrganiId);
    } catch (e) {
      // Error reseteando BD
    }
  }

  static Future<bool> syncBlacklistFromApi(
    List<dynamic> blacklistData,
    int organiId,
  ) async {
    try {
      final db = await getDatabaseForOrganization(organiId);

      // Limpiar blacklist existente solo para esta organización
      await db.delete(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );

      // Insertar nuevos datos
      for (var item in blacklistData) {
        try {
          final dni = item['document']?.toString() ?? '';
          final reason = item['reason']?.toString() ?? 'DNI en lista negra';

          if (dni.isNotEmpty) {
            await db.insert(tableBlacklist, {
              'dni': dni,
              'organi_id': organiId,
              'reason': reason,
              'created_at':
                  item['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } catch (e) {
          // Error insertando DNI individual
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 🔥 MEJORAR método de verificación de DNI
  static Future<Map<String, dynamic>> checkDniInBlacklist(
    String dni,
    int organiId,
  ) async {
    try {
      final db = await getDatabaseForOrganization(organiId);
      final result = await db.query(
        tableBlacklist,
        where: 'dni = ? AND organi_id = ?',
        whereArgs: [dni, organiId],
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
  static Future<void> marcarEnviado(int id, {int? organiId}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
    final db = await getDatabaseForOrganization(targetOrganiId);
    await db.update(
      tablePersonas,
      {'enviadaNube': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtener lista de todas las organizaciones con bases de datos
  static Future<List<int>> getAvailableOrganizations() async {
    try {
      final dbPath = await getDatabasesPath();
      final directory = Directory(dbPath);
      final files = await directory.list().toList();

      final orgIds = <int>[];
      for (var file in files) {
        if (file is File && file.path.contains(_dbNamePrefix)) {
          final fileName = file.path.split('/').last;
          final orgIdStr = fileName
              .replaceAll(_dbNamePrefix, '')
              .replaceAll('.db', '');
          final orgId = int.tryParse(orgIdStr);
          if (orgId != null) {
            orgIds.add(orgId);
          }
        }
      }

      return orgIds;
    } catch (e) {
      return [];
    }
  }

  // Cambiar a una organización específica
  static Future<void> switchToOrganization(int organiId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('organi_id', organiId);
  }
}
