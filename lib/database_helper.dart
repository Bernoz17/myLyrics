import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('frasi.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Cambiamo la versione a 2 e aggiungiamo onUpgrade
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE frasi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        testo TEXT,
        titolo TEXT,
        artista TEXT,
        preferito INTEGER DEFAULT 0
      )
    ''');
  }

  // Se l'app ha già la tabella vecchia (versione 1), aggiunge la nuova colonna
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE frasi ADD COLUMN preferito INTEGER DEFAULT 0');
    }
  }

  Future<void> popolaDatabaseIniziale() async {
    try {
      final db = await instance.database;
      int? count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM frasi'));
      
      if (count == null || count == 0) {
        final String jsonString = await rootBundle.loadString('assets/frasi.json');
        final dynamic jsonData = jsonDecode(jsonString);

        List<dynamic> jsonList;
        if (jsonData is List) {
          jsonList = jsonData;
        } else if (jsonData is Map && jsonData.containsKey('frasi')) {
          jsonList = jsonData['frasi'];
        } else {
          throw Exception("Struttura JSON non riconosciuta.");
        }

        Batch batch = db.batch();
        for (var item in jsonList) {
          batch.insert('frasi', {
            'testo': item['testo']?.toString() ?? '',
            'titolo': item['titolo']?.toString() ?? '',
            'artista': item['artista']?.toString() ?? '',
            'preferito': item['preferito'] ?? 0
          });
        }
        await batch.commit();
      }
    } catch (e) {
      print("Errore importazione: $e");
    }
  }

  Future<Map<String, dynamic>?> getFraseDelGiorno() async {
    final String jsonString = await rootBundle.loadString('assets/frasi.json');
    final dynamic jsonData = jsonDecode(jsonString);

    List<dynamic> jsonList;
    if (jsonData is List) {
      jsonList = jsonData;
    } else if (jsonData is Map && jsonData.containsKey('frasi')) {
      jsonList = jsonData['frasi'];
    } else {
      throw Exception("Struttura JSON non riconosciuta.");
    }

    if (jsonList.isEmpty) return null;

    final now = DateTime.now();
    // Keep the device-local calendar date, then calculate day number using
    // UTC civil dates so daylight-saving transitions cannot change the index.
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final epochUtc = DateTime.utc(1970, 1, 1);
    final days = todayUtc.difference(epochUtc).inDays;
    final index = ((days % jsonList.length) + jsonList.length) % jsonList.length;
    final item = Map<String, dynamic>.from(jsonList[index] as Map);

    return {
      'id': index + 1,
      'testo': item['testo']?.toString() ?? '',
      'titolo': item['titolo']?.toString() ?? '',
      'artista': item['artista']?.toString() ?? '',
      'preferito': item['preferito'] ?? 0,
    };
  }

  Future<int> contaFrasi() async {
    final db = await instance.database;
    int? count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM frasi'));
    return count ?? 0;
  }

  Future<Map<String, dynamic>?> getRandomFrase() async {
    final db = await instance.database;
    final result = await db.query('frasi', orderBy: 'RANDOM()', limit: 1);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  String _rimuoviAccenti(String testo) {
    return testo.toLowerCase()
        .replaceAll('à', 'a').replaceAll('á', 'a')
        .replaceAll('è', 'e').replaceAll('é', 'e')
        .replaceAll('ì', 'i').replaceAll('í', 'i')
        .replaceAll('ò', 'o').replaceAll('ó', 'o')
        .replaceAll('ù', 'u').replaceAll('ú', 'u');
  }

  Future<List<Map<String, dynamic>>> getTutteLeFrasi({bool ascending = true, String query = ''}) async {
    final db = await instance.database;
    List<Map<String, dynamic>> risultati;
    
    if (query.isEmpty) {
      risultati = await db.query('frasi');
    } else {
      risultati = await db.query(
        'frasi',
        where: 'testo LIKE ? OR artista LIKE ? OR titolo LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
    }

    List<Map<String, dynamic>> frasiModificabili = List.from(risultati);
    frasiModificabili.sort((a, b) {
      String testoA = _rimuoviAccenti(a['testo'].toString());
      String testoB = _rimuoviAccenti(b['testo'].toString());
      return ascending ? testoA.compareTo(testoB) : testoB.compareTo(testoA);
    });

    return frasiModificabili;
  }
  
  // NUOVA QUERY: Estrae solo le frasi salvate come preferite
  Future<List<Map<String, dynamic>>> getFrasiPreferite() async {
    final db = await instance.database;
    final risultati = await db.query('frasi', where: 'preferito = 1');
    
    List<Map<String, dynamic>> frasiModificabili = List.from(risultati);
    frasiModificabili.sort((a, b) {
      String testoA = _rimuoviAccenti(a['testo'].toString());
      String testoB = _rimuoviAccenti(b['testo'].toString());
      return testoA.compareTo(testoB);
    });
    return frasiModificabili;
  }

  Future<List<String>> getArtisti() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT artista FROM frasi');
    
    Set<String> artistiSet = {};
    for (var row in result) {
      String stringaArtisti = row['artista'].toString();
      List<String> artistiSeparati = stringaArtisti.split(',');
      for (var a in artistiSeparati) {
        String artistaPulito = a.trim();
        if (artistaPulito.isNotEmpty) {
          artistiSet.add(artistaPulito);
        }
      }
    }
    List<String> artisti = artistiSet.toList();
    artisti.sort((a, b) => _rimuoviAccenti(a).compareTo(_rimuoviAccenti(b)));
    return artisti;
  }

  Future<List<Map<String, dynamic>>> getFrasiByArtista(String artista) async {
    final db = await instance.database;
    final risultati = await db.query('frasi', where: 'artista LIKE ?', whereArgs: ['%$artista%']);
    
    List<Map<String, dynamic>> frasiFiltrate = [];
    for (var r in risultati) {
      String stringaArtistiDb = r['artista'].toString();
      List<String> listaArtistiDb = stringaArtistiDb.split(',').map((e) => e.trim()).toList();
      
      if (listaArtistiDb.contains(artista)) {
        frasiFiltrate.add(Map<String, dynamic>.from(r));
      }
    }
    
    frasiFiltrate.sort((a, b) {
      String testoA = _rimuoviAccenti(a['testo'].toString());
      String testoB = _rimuoviAccenti(b['testo'].toString());
      return testoA.compareTo(testoB);
    });
    return frasiFiltrate;
  }

  Future<int> insertFrase(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Se non è specificato, di default non è preferito
    if (!row.containsKey('preferito')) row['preferito'] = 0;
    return await db.insert('frasi', row);
  }

  Future<int> updateFrase(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('frasi', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFrase(int id) async {
    final db = await instance.database;
    return await db.delete('frasi', where: 'id = ?', whereArgs: [id]);
  }

  // NUOVA QUERY: Cambia al volo lo stato "preferito" di una frase
  Future<void> togglePreferito(int id, int nuovoStato) async {
    final db = await instance.database;
    await db.update('frasi', {'preferito': nuovoStato}, where: 'id = ?', whereArgs: [id]);
  }
}