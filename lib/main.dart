import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          brightness: Brightness.dark,
        ),
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
  final String rigNumber;
  final String status;
  final String lastOverhaulDate;
  final String overhaulDueDate;
  final String historyNotes;
  final String? imagePath;

  Asset({
    this.id,
    required this.name,
    required this.serialNumber,
    required this.category,
    required this.rigNumber,
    required this.status,
    required this.lastOverhaulDate,
    required this.overhaulDueDate,
    required this.historyNotes,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'serialNumber': serialNumber,
      'category': category,
      'rigNumber': rigNumber,
      'status': status,
      'lastOverhaulDate': lastOverhaulDate,
      'overhaulDueDate': overhaulDueDate,
      'historyNotes': historyNotes,
      'imagePath': imagePath,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'],
      name: map['name'],
      serialNumber: map['serialNumber'],
      category: map['category'],
      rigNumber: map['rigNumber'] ?? 'N/A',
      status: map['status'],
      lastOverhaulDate: map['lastOverhaulDate'],
      overhaulDueDate: map['overhaulDueDate'],
      historyNotes: map['historyNotes'] ?? '',
      imagePath: map['imagePath'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('well_control_v4.db');
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
        rigNumber TEXT NOT NULL,
        status TEXT NOT NULL,
        lastOverhaulDate TEXT NOT NULL,
        overhaulDueDate TEXT NOT NULL,
        historyNotes TEXT,
        imagePath TEXT
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
              asset.rigNumber.toLowerCase().contains(query.toLowerCase()) ||
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
    final rigController = TextEditingController(text: asset?.rigNumber ?? '');
    final statusController = TextEditingController(text: asset?.status ?? 'Active');
    final lastOverhaulController = TextEditingController(
      text: asset?.lastOverhaulDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final historyController = TextEditingController(text: asset?.historyNotes ?? '');
    String? selectedImagePath = asset?.imagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            asset == null ? 'Add New Asset' : 'Edit Asset',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Equipment Name')),
                TextField(controller: serialController, decoration: const InputDecoration(labelText: 'Serial Number')),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (BOP, Valve, etc.)')),
                TextField(controller: rigController, decoration: const InputDecoration(labelText: 'Rig Number (e.g., MDC#4)')),
                TextField(controller: statusController, decoration: const InputDecoration(labelText: 'Status')),
                TextField(
                  controller: lastOverhaulController,
                  decoration: const InputDecoration(labelText: 'Last Overhaul Date (YYYY-MM-DD)'),
                ),
                TextField(
                  controller: historyController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Maintenance History & Notes'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                  icon: const Icon(Icons.verified, color: Colors.white),
                  label: Text(
                    selectedImagePath == null ? 'Attach Certificate' : 'Change Certificate',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setDialogState(() {
                        selectedImagePath = image.path;
                      });
                    }
                  },
                ),
                if (selectedImagePath != null) ...[
                  const SizedBox(height: 6),
                  const Text('Certificate Attached ✔️', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                final calculatedDueDate = _calculateDueDate(lastOverhaulController.text);
                final newAsset = Asset(
                  id: asset?.id,
                  name: nameController.text,
                  serialNumber: serialController.text,
                  category: categoryController.text,
                  rigNumber: rigController.text,
                  status: statusController.text,
                  lastOverhaulDate: lastOverhaulController.text,
                  overhaulDueDate: calculatedDueDate,
                  historyNotes: historyController.text,
                  imagePath: selectedImagePath,
                );

                if (asset == null) {
                  await DatabaseHelper.instance.create(newAsset);
                } else {
                  await DatabaseHelper.instance.update(newAsset);
                }

                if (mounted) Navigator.pop(context);
                _refreshAssets();
              },
              child: const Text('Save Asset', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
                child: pw.Text('Well Control Asset Status Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Name', 'Serial No', 'Rig No', 'Category', 'Status', 'Last Overhaul', 'Due Date'],
                data: _filteredAssets.map((a) => [
                  a.name,
                  a.serialNumber,
                  a.rigNumber,
                  a.category,
                  a.status,
                  a.lastOverhaulDate,
                  a.overhaulDueDate,
                ]).toList(),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.4),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: const Icon(Icons.precision_manufacturing, color: Colors.cyanAccent, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BOP WELL CONTROL',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.cyanAccent),
                          ),
                          Text(
                            'Asset & Recertification Manager',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.amberAccent, size: 28),
                      onPressed: _generatePdfReport,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search Equipment, Serial No, or Rig No...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
                    ),
                  ),
                  onChanged: _filterAssets,
                ),
              ),
              // Asset List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : ListView.builder(
                        itemCount: _filteredAssets.length,
                        itemBuilder: (context, index) {
                          final asset = _filteredAssets[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Equipment Name & Action Buttons
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        asset.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 22),
                                      onPressed: () => _showAssetDialog(asset: asset),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                                      onPressed: () async {
                                        await DatabaseHelper.instance.delete(asset.id!);
                                        _refreshAssets();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Rig Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'Rig: ${asset.rigNumber}',
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text('SN: ${asset.serialNumber} | Cat: ${asset.category}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.event_repeat, color: Colors.amberAccent, size: 16),
                                    const SizedBox(width: 4),
                                    Text('Due: ${asset.overhaulDueDate}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                if (asset.historyNotes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('History: ${asset.historyNotes}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0EA5E9),
        onPressed: () => _showAssetDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Asset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
