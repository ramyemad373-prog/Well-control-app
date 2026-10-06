import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WellControlApp());
}

class WellControlApp extends StatelessWidget {
  const WellControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Well Control Assets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('well_control.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE equipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rigNumber TEXT NOT NULL,
        equipmentName TEXT NOT NULL,
        serialNumber TEXT NOT NULL UNIQUE,
        assetNumber TEXT NOT NULL,
        lastOverhaulDate TEXT NOT NULL,
        overhaulDueDate TEXT NOT NULL,
        history TEXT
      )
    ''');
  }

  Future<int> insertEquipment(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('equipment', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateEquipment(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('equipment', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> searchByRig(String rigNumber) async {
    final db = await instance.database;
    return await db.query('equipment', where: 'rigNumber LIKE ?', whereArgs: ['%$rigNumber%']);
  }

  Future<Map<String, dynamic>?> getBySerial(String serialNumber) async {
    final db = await instance.database;
    final results = await db.query('equipment', where: 'serialNumber = ?', whereArgs: [serialNumber]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllEquipment() async {
    final db = await instance.database;
    return await db.query('equipment');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searched = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final rigResults = await DatabaseHelper.instance.searchByRig(query.trim());
    if (rigResults.isNotEmpty) {
      setState(() {
        _searchResults = rigResults;
        _searched = true;
      });
    } else {
      final serialResult = await DatabaseHelper.instance.getBySerial(query.trim());
      setState(() {
        _searchResults = serialResult != null ? [serialResult] : [];
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Well Control Asset Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة معدة جديدة',
            onPressed: () => _openEquipmentForm(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'ابحث برقم البريمة (Rig) أو السريال (Serial)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _performSearch(_searchController.text),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: const Text('بحث'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_searchResults.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير التقرير PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => _generateAndPrintPDF(_searchResults, _searchController.text),
              ),

            const SizedBox(height: 16),

            Expanded(
              child: _searchResults.isEmpty
                  ? Center(child: Text(_searched ? 'لا توجد نتائج بحث' : 'قم بالبحث أو اضغط + لإضافة معدة جديدة'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text('${item['equipmentName']} (Rig: ${item['rigNumber']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('S/N: ${item['serialNumber']} | Asset: ${item['assetNumber']}\nDue: ${item['overhaulDueDate']}'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openEquipmentForm(context, item: item),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEquipmentForm(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة معدة'),
      ),
    );
  }

  void _openEquipmentForm(BuildContext context, {Map<String, dynamic>? item}) {
    final rigController = TextEditingController(text: item?['rigNumber']);
    final nameController = TextEditingController(text: item?['equipmentName']);
    final serialController = TextEditingController(text: item?['serialNumber']);
    final assetController = TextEditingController(text: item?['assetNumber']);
    final lastOverhaulController = TextEditingController(text: item?['lastOverhaulDate']);
    final dueOverhaulController = TextEditingController(text: item?['overhaulDueDate']);
    final historyController = TextEditingController(text: item?['history']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة معدة جديدة' : 'تعديل بيانات المعدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: min,
            children: [
              TextField(controller: rigController, decoration: const InputDecoration(labelText: 'Rig Number')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Equipment Name')),
              TextField(controller: serialController, decoration: const InputDecoration(labelText: 'Serial Number')),
              TextField(controller: assetController, decoration: const InputDecoration(labelText: 'Asset Number')),
              TextField(
                controller: lastOverhaulController, 
                decoration: const InputDecoration(labelText: 'Last Overhaul Date (YYYY-MM-DD)'),
              ),
              TextField(
                controller: dueOverhaulController, 
                decoration: const InputDecoration(labelText: 'Overhaul Due Date (YYYY-MM-DD)'),
              ),
              TextField(
                controller: historyController, 
                maxLines: 3, 
                decoration: const InputDecoration(labelText: 'History / Maintenance Log'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'rigNumber': rigController.text,
                'equipmentName': nameController.text,
                'serialNumber': serialController.text,
                'assetNumber': assetController.text,
                'lastOverhaulDate': lastOverhaulController.text,
                'overhaulDueDate': dueOverhaulController.text,
                'history': historyController.text,
              };

              if (item == null) {
                await DatabaseHelper.instance.insertEquipment(data);
              } else {
                await DatabaseHelper.instance.updateEquipment(item['id'], data);
              }

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح!')));
                if (_searchController.text.isNotEmpty) {
                  _performSearch(_searchController.text);
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPDF(List<Map<String, dynamic>> data, String searchQuery) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            cross: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  main: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('WELL CONTROL EQUIPMENT REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Search Query / Reference: $searchQuery', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20),

              pw.Table.fromTextArray(
                headers: ['Rig', 'Equipment Name', 'Serial No.', 'Asset No.', 'Last Overhaul', 'Due Date'],
                data: data.map((e) => [
                  e['rigNumber'],
                  e['equipmentName'],
                  e['serialNumber'],
                  e['assetNumber'],
                  e['lastOverhaulDate'],
                  e['overhaulDueDate'],
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
                cellAlignment: pw.Alignment.centerLeft,
              ),

              pw.SizedBox(height: 20),
              if (data.length == 1) ...[
                pw.Text('Detailed Equipment History:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Text(data.first['history'] ?? 'No history recorded.'),
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
