import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WellControlApp());
}

class WellControlApp extends StatelessWidget {
  const WellControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Well Control Asset Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Asset {
  final int? id;
  final String name;
  final String serialNumber;
  final String category;
  final String status;
  final String lastOverhaulDate;
  final String overhaulDueDate;

  Asset({
    this.id,
    required this.name,
    required this.serialNumber,
    required this.category,
    required this.status,
    required this.lastOverhaulDate,
    required this.overhaulDueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'serialNumber': serialNumber,
      'category': category,
      'status': status,
      'lastOverhaulDate': lastOverhaulDate,
      'overhaulDueDate': overhaulDueDate,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      name: map['name'],
      serialNumber: map['serialNumber'],
      category: map['category'],
      status: map['status'],
      lastOverhaulDate: map['lastOverhaulDate'],
      overhaulDueDate: map['overhaulDueDate'],
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

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        serialNumber TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL,
        lastOverhaulDate TEXT NOT NULL,
        overhaulDueDate TEXT NOT NULL
      )
    ''');
  }

  Future<int> create(Asset asset) async {
    final db = await instance.database;
    return await db.insert('assets', asset.toMap());
  }

  Future<List<Asset>> readAllAssets() async {
    final db = await instance.database;
    final result = await db.query('assets', orderBy: 'id DESC');
    return result.map((json) => Asset.fromMap(json)).toList();
  }

  Future<int> update(Asset asset) async {
    final db = await instance.database;
    return db.update(
      'assets',
      asset.toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Asset> _assets = [];
  List<Asset> _filteredAssets = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAssets();
  }

  Future<void> _refreshAssets() async {
    setState(() => _isLoading = true);
    _assets = await DatabaseHelper.instance.readAllAssets();
    _filteredAssets = _assets;
    setState(() => _isLoading = false);
  }

  void _filterAssets(String query) {
    setState(() {
      _filteredAssets = _assets
          .where((asset) =>
              asset.name.toLowerCase().contains(query.toLowerCase()) ||
              asset.serialNumber.toLowerCase().contains(query.toLowerCase()) ||
              asset.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  String _calculateDueDate(String startDateStr) {
    try {
      DateTime startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
      DateTime dueDate = DateTime(startDate.year + 5, startDate.month, startDate.day);
      return DateFormat('yyyy-MM-dd').format(dueDate);
    } catch (e) {
      return startDateStr;
    }
  }

  void _showAssetDialog({Asset? asset}) {
    final nameController = TextEditingController(text: asset?.name ?? '');
    final serialController = TextEditingController(text: asset?.serialNumber ?? '');
    final categoryController = TextEditingController(text: asset?.category ?? '');
    final statusController = TextEditingController(text: asset?.status ?? 'Active');
    final lastOverhaulController = TextEditingController(
      text: asset?.lastOverhaulDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asset == null ? 'Add New Asset' : 'Edit Asset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Equipment Name')),
              TextField(controller: serialController, decoration: const InputDecoration(labelText: 'Serial Number')),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (BOP, Valve, etc.)')),
              TextField(controller: statusController, decoration: const InputDecoration(labelText: 'Status')),
              TextField(
                controller: lastOverhaulController,
                decoration: const InputDecoration(labelText: 'Last Overhaul Date (YYYY-MM-DD)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final calculatedDueDate = _calculateDueDate(lastOverhaulController.text);
              final newAsset = Asset(
                id: asset?.id,
                name: nameController.text,
                serialNumber: serialController.text,
                category: categoryController.text,
                status: statusController.text,
                lastOverhaulDate: lastOverhaulController.text,
                overhaulDueDate: calculatedDueDate,
              );

              if (asset == null) {
                await DatabaseHelper.instance.create(newAsset);
              } else {
                await DatabaseHelper.instance.update(newAsset);
              }

              if (mounted) Navigator.pop(context);
              _refreshAssets();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Well Control Asset Status Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Name', 'Serial No', 'Category', 'Status', 'Last Overhaul', 'Due Date'],
                data: _assets.map((a) => [a.name, a.serialNumber, a.category, a.status, a.lastOverhaulDate, a.overhaulDueDate]).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Well Control Assets'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generatePdfReport),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Equipment or Serial No',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterAssets,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _filteredAssets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('SN: ${asset.serialNumber} | Category: ${asset.category}\nDue: ${asset.overhaulDueDate}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAssetDialog(asset: asset)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await DatabaseHelper.instance.delete(asset.id!);
                                  _refreshAssets();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAssetDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
