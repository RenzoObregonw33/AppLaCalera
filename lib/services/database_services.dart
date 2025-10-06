import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart';

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
    print(
      '✅ Blacklist actualizada para org $targetOrganiId (${blacklist.length} registros)',
    );
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
    print(
      "🔍 Verificando DNI $dni en org $targetOrganiId: ${result.isNotEmpty ? 'EXISTE' : 'NO EXISTE'}",
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

    print("📦 Inicializando BD para organización $organiId: $dbPath");

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        print("📦 Creando base de datos para org $organiId en $dbPath");
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print("⚡ Migrando BD org $organiId de v$oldVersion → v$newVersion");
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

    // NO insertar datos de ejemplo, solo crear estructura
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
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
  }

  static Future<void> _migrateToV2(Database db) async {
    // Migración para versión 2 (si existiera)
    print("🔄 Migrando a v2");
  }

  static Future<void> _migrateToV3(Database db) async {
    print("🔄 Migrando a v3");

    // Asegurar tabla blacklist (sin organi_id aún)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBlacklist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT UNIQUE,
        reason TEXT,
        created_at TEXT
      )
    ''');
    // NO insertar ejemplos, esperar sincronización con API
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

  static Future<void> _migrateToV5(Database db) async {
    print("🔄 Migrando a v5 - Blacklist por organización");

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
        print("✅ Columna 'organi_id' agregada a blacklist");

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
    print("🔄 Recreando tablas...");

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

      print("💾 Insertando persona en BD org $targetOrganiId");

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
  static Future<List<Map<String, dynamic>>> getPeople({int? organiId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
      final db = await getDatabaseForOrganization(targetOrganiId);
      final result = await db.query(tablePersonas);
      print(
        "📂 Se encontraron ${result.length} personas en BD org $targetOrganiId",
      );
      return result;
    } catch (e) {
      print("❌ Error obteniendo personas: $e");
      return [];
    }
  }

  // Métodos Blacklist
  static Future<bool> isDniBlacklisted(String dni, int organiId) async {
    try {
      print('🔍 ===== VERIFICANDO DNI EN BLACKLIST =====');
      print('📋 DNI a verificar: "$dni"');
      print('🏢 Organización ID: $organiId');

      final db = await getDatabaseForOrganization(organiId);

      // Primero verificar que hay datos en la blacklist para esta organización
      final allRecords = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );
      print(
        '📊 Total de registros en blacklist para org $organiId: ${allRecords.length}',
      );

      if (allRecords.isNotEmpty) {
        print('📄 Registros existentes en blacklist:');
        for (var record in allRecords) {
          print(
            '   - DNI: "${record['dni']}" | Razón: "${record['reason']}" | Org: ${record['organi_id']}',
          );
        }
      }

      // Ahora hacer la búsqueda específica
      final result = await db.query(
        tableBlacklist,
        where: 'dni = ? AND organi_id = ?',
        whereArgs: [dni, organiId],
      );

      final isBlacklisted = result.isNotEmpty;
      print('❌ ¿Está en blacklist?: ${isBlacklisted ? 'SÍ' : 'NO'}');

      if (isBlacklisted) {
        final blacklistData = result.first;
        print('📄 Datos del registro encontrado:');
        print('   - DNI: "${blacklistData['dni']}"');
        print('   - Organización: ${blacklistData['organi_id']}');
        print('   - Razón: "${blacklistData['reason']}"');
        print('   - Fecha creación: ${blacklistData['created_at']}');
      } else {
        print('✅ DNI no encontrado en blacklist');
        // Verificar si hay coincidencia exacta de caracteres
        final similarRecords = await db.query(
          tableBlacklist,
          where: 'organi_id = ?',
          whereArgs: [organiId],
        );
        for (var record in similarRecords) {
          if (record['dni'].toString().trim() == dni.trim()) {
            print('⚠️ ENCONTRADO COINCIDENCIA EXACTA PERO QUERY FALLÓ');
            print(
              '   Record DNI: "${record['dni']}" (length: ${record['dni'].toString().length})',
            );
            print('   Search DNI: "$dni" (length: ${dni.length})');
          }
        }
      }
      print('🔍 =======================================');

      return isBlacklisted;
    } catch (e) {
      print("❌ Error verificando blacklist: $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBlacklist(int organiId) async {
    try {
      print('📋 ===== OBTENIENDO BLACKLIST =====');
      print('🏢 Organización ID: $organiId');

      final db = await getDatabaseForOrganization(organiId);
      final result = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
        orderBy: 'created_at DESC',
      );

      print('📊 Total de registros en blacklist: ${result.length}');

      if (result.isNotEmpty) {
        print('📄 Datos de la blacklist:');
        for (int i = 0; i < result.length; i++) {
          final item = result[i];
          print('   ${i + 1}. DNI: ${item['dni']}');
          print('      - Organización: ${item['organi_id']}');
          print('      - Razón: ${item['reason']}');
          print('      - Fecha: ${item['created_at']}');
          print('      ________________');
        }
      } else {
        print('📝 No hay registros en la blacklist para esta organización');
      }
      print('📋 ===============================');

      return result;
    } catch (e) {
      print("❌ Error obteniendo blacklist: $e");
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
  static Future<void> resetDatabase({int? organiId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetOrganiId = organiId ?? prefs.getInt('organi_id') ?? 0;
      final dbName = '${_dbNamePrefix}${targetOrganiId}.db';
      final dbPath = join(await getDatabasesPath(), dbName);
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
        print(
          '🗑️ Base de datos org $targetOrganiId eliminada, se recreará con el nuevo esquema',
        );
      }
      _databases.remove(targetOrganiId);
      await getDatabaseForOrganization(targetOrganiId); // Esto recreará la BD
    } catch (e) {
      print('❌ Error reseteando BD: $e');
    }
  }

  // 🔥 NUEVO MÉTODO: Sincronizar blacklist desde la API
  static Future<bool> syncBlacklistFromApi(
    List<dynamic> blacklistData,
    int organiId,
  ) async {
    try {
      print('🔄 ===== SINCRONIZANDO BLACKLIST DESDE API =====');
      print('🏢 Organización ID: $organiId');
      print('📊 Total de registros recibidos de API: ${blacklistData.length}');

      final db = await database;

      // Mostrar blacklist existente antes de limpiar
      final existingData = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );
      print(
        '📋 Registros existentes en blacklist (antes): ${existingData.length}',
      );

      if (existingData.isNotEmpty) {
        print('📄 Blacklist existente:');
        for (var item in existingData) {
          print('   - DNI: ${item['dni']} | Razón: ${item['reason']}');
        }
      }

      // Limpiar blacklist existente solo para esta organización
      final deletedRows = await db.delete(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );
      print('🗑️ Registros eliminados: $deletedRows');

      // Mostrar datos que se van a insertar
      print('📥 Datos nuevos de la API:');
      for (int i = 0; i < blacklistData.length; i++) {
        final item = blacklistData[i];
        print('   ${i + 1}. DNI: ${item['document']?.toString() ?? 'Sin DNI'}');
        print('      - ID: ${item['id']}');
        print('      - Name: ${item['name']}');
        print('      - First Name: ${item['first_name']}');
        print('      - Last Name: ${item['last_name']}');
        print(
          '      - Razón: ${item['reason']?.toString() ?? 'Sin motivo (NULL)'}',
        );
        print('      - OrganiId de la API: ${item['organi_id']}');
        print(
          '      - Fecha: ${item['created_at']?.toString() ?? 'Sin fecha'}',
        );
        print('      - Para organización local: $organiId');
        print('      ________________');
      }

      // Insertar nuevos datos
      int insertedCount = 0;
      for (var item in blacklistData) {
        try {
          final dni = item['document']?.toString() ?? '';
          final reason = item['reason']?.toString() ?? 'DNI en lista negra';

          print('💾 Insertando: DNI=$dni, Reason=$reason, OrganiId=$organiId');

          await db.insert(tableBlacklist, {
            'dni': dni,
            'organi_id': organiId,
            'reason': reason,
            'created_at':
                item['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          insertedCount++;
          print('✅ Insertado exitosamente: $dni');
        } catch (e) {
          print('❌ Error insertando DNI ${item['document']}: $e');
        }
      }

      // Verificar que se guardó correctamente
      final finalData = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );

      print('✅ ===== SINCRONIZACIÓN COMPLETADA =====');
      print('📊 Registros insertados exitosamente: $insertedCount');
      print(
        '📊 Total de registros en blacklist (después): ${finalData.length}',
      );
      print('🏢 Organización: $organiId');

      if (finalData.isNotEmpty) {
        print('📄 Blacklist final:');
        for (var item in finalData) {
          print(
            '   - DNI: ${item['dni']} | Razón: ${item['reason']} | Org: ${item['organi_id']}',
          );
        }
      }
      print('✅ ====================================');

      return true;
    } catch (e) {
      print("❌ Error sincronizando blacklist: $e");
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

  // 🔧 FUNCIÓN DE DEBUG MANUAL: Forzar sincronización de blacklist
  static Future<void> debugSyncBlacklist() async {
    print('\n🔧 ===== DEBUG: FORZANDO SINCRONIZACIÓN MANUAL =====');

    try {
      // Verificar que la tabla blacklist existe
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='blacklist'",
      );
      print('🗄️ Tabla blacklist existe: ${tables.isNotEmpty}');

      if (tables.isNotEmpty) {
        final columns = await db.rawQuery("PRAGMA table_info(blacklist)");
        print('📋 Columnas de la tabla blacklist:');
        for (var col in columns) {
          print('   - ${col['name']} (${col['type']})');
        }
      } else {
        print('❌ ¡TABLA BLACKLIST NO EXISTE! Necesita ejecutar migración.');
        return; // Salir si no existe la tabla
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final organiId = 749; // Forzar organización 749 para debug

      print(
        '🔑 Token: ${token.isNotEmpty ? 'SÍ tiene token' : 'NO tiene token'}',
      );
      print('🏢 OrganiId: $organiId');

      // Llamar directamente a la API
      print('📡 Llamando a la API...');
      final blacklistResponse = await ApiService.fetchBlacklistFromApi(
        organiId,
        token: token,
      );

      print('📊 Datos recibidos: ${blacklistResponse.length} registros');

      if (blacklistResponse.isNotEmpty) {
        print('💾 Sincronizando con base de datos...');
        await syncBlacklistFromApi(blacklistResponse, organiId);

        // Verificar que se guardó
        final savedData = await getBlacklist(organiId);
        print('✅ Verificación: ${savedData.length} registros guardados');

        // Probar DNI específico
        await testDniBlacklist('44781567', organiId);
      } else {
        print('❌ No se recibieron datos de la API');
      }
    } catch (e) {
      print('❌ Error en debug sync: $e');
    }

    print('🔧 ===============================================\n');
  }

  // 🧪 FUNCIÓN DE TESTING: Probar DNI específico
  static Future<void> testDniBlacklist(String dni, int organiId) async {
    print('\n🧪 ===== TEST DNI BLACKLIST =====');
    print('📋 DNI de prueba: "$dni"');
    print('🏢 Organización: $organiId');

    try {
      final db = await database;

      // Ver todos los registros de la organización
      final allRecords = await db.query(
        tableBlacklist,
        where: 'organi_id = ?',
        whereArgs: [organiId],
      );

      print(
        '📊 Total registros en blacklist org $organiId: ${allRecords.length}',
      );
      print('📄 Registros disponibles:');
      for (var record in allRecords) {
        print(
          '   - "${record['dni']}" (${record['dni'].toString().length} chars)',
        );
      }

      // Probar búsqueda exacta
      final exactMatch = await db.query(
        tableBlacklist,
        where: 'dni = ? AND organi_id = ?',
        whereArgs: [dni, organiId],
      );

      print('🔍 Búsqueda exacta encontró: ${exactMatch.length} registros');

      // Probar la función oficial
      final result = await isDniBlacklisted(dni, organiId);
      print('✅ Resultado final: ${result ? 'BLOQUEADO' : 'PERMITIDO'}');
    } catch (e) {
      print('❌ Error en test: $e');
    }

    print('🧪 ===========================\n');
  }

  // 🔍 FUNCIÓN DE DEBUG: Mostrar todas las blacklists por organización
  static Future<void> showAllBlacklists() async {
    try {
      print('🔍 ===== MOSTRANDO TODAS LAS BLACKLISTS =====');

      final db = await database;

      // Obtener todas las organizaciones únicas
      final organizations = await db.rawQuery(
        'SELECT DISTINCT organi_id FROM $tableBlacklist ORDER BY organi_id',
      );

      print('🏢 Organizaciones con blacklist: ${organizations.length}');

      for (var org in organizations) {
        final organiId = org['organi_id'];
        print('\n🏢 ===== ORGANIZACIÓN $organiId =====');

        final blacklistData = await db.query(
          tableBlacklist,
          where: 'organi_id = ?',
          whereArgs: [organiId],
          orderBy: 'created_at DESC',
        );

        print('📊 Total de registros: ${blacklistData.length}');

        if (blacklistData.isNotEmpty) {
          for (int i = 0; i < blacklistData.length; i++) {
            final item = blacklistData[i];
            print('   ${i + 1}. DNI: ${item['dni']}');
            print('      - Razón: ${item['reason']}');
            print('      - Fecha: ${item['created_at']}');
            print('      ________________');
          }
        } else {
          print('📝 Sin registros en blacklist');
        }
      }

      // Mostrar estadísticas generales
      final totalRecords = await db.rawQuery(
        'SELECT COUNT(*) as total FROM $tableBlacklist',
      );
      print('\n📊 ===== ESTADÍSTICAS GENERALES =====');
      print(
        '🔢 Total de registros en blacklist: ${totalRecords.first['total']}',
      );
      print('🏢 Total de organizaciones: ${organizations.length}');
      print('🔍 ===================================');
    } catch (e) {
      print("❌ Error mostrando blacklists: $e");
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
    print('✅ Registro $id marcado como enviado en org $targetOrganiId');
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

      print("📊 Organizaciones con BD local: $orgIds");
      return orgIds;
    } catch (e) {
      print("❌ Error obteniendo organizaciones: $e");
      return [];
    }
  }

  // Cambiar a una organización específica
  static Future<void> switchToOrganization(int organiId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('organi_id', organiId);
    print("🔄 Cambiado a organización $organiId");
  }
}
