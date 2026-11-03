// =====================================================================

// PART 1 OF 3: MODELS, STORAGE, SYNC & FOLDER PICKER

// =====================================================================


import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:uuid/uuid.dart';


void main() {

  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SaariStoreApp());

}


class SaariStoreApp extends StatelessWidget {

  const SaariStoreApp({super.key});


  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'SAARI STORE',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(

          seedColor: const Color(0xFF0B2545),

          primary: const Color(0xFF0B2545),

          secondary: const Color(0xFFF25F22),

          surface: const Color(0xFFF8FAFC),

        ),

        inputDecorationTheme: const InputDecorationTheme(

          filled: true,

          fillColor: Colors.white,

          border: OutlineInputBorder(),

          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),

        ),

      ),

      home: const MainStoreScreen(),

    );

  }

}


class CatalogItem {

  String id, name, category, uom, updatedAt;

  bool isReturnableDefault;

  CatalogItem({required this.id, required this.name, required this.category, required this.uom, this.isReturnableDefault = false, required this.updatedAt});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'category': category, 'uom': uom, 'isReturnableDefault': isReturnableDefault, 'updatedAt': updatedAt};

  factory CatalogItem.fromMap(Map<String, dynamic> m) => CatalogItem(id: m['id'] ?? '', name: m['name'] ?? '', category: m['category'] ?? 'General', uom: m['uom'] ?? 'Pcs', isReturnableDefault: m['isReturnableDefault'] ?? false, updatedAt: m['updatedAt'] ?? '');

}


class RequisitionLine {

  String itemId, itemName, uom;

  double prevStock, reqQty, receivedQty;

  RequisitionLine({required this.itemId, required this.itemName, required this.uom, required this.prevStock, required this.reqQty, this.receivedQty = 0.0});

  Map<String, dynamic> toMap() => {'itemId': itemId, 'itemName': itemName, 'uom': uom, 'prevStock': prevStock, 'reqQty': reqQty, 'receivedQty': receivedQty};

  factory RequisitionLine.fromMap(Map<String, dynamic> m) => RequisitionLine(itemId: m['itemId'] ?? '', itemName: m['itemName'] ?? '', uom: m['uom'] ?? 'Pcs', prevStock: (m['prevStock'] as num?)?.toDouble() ?? 0.0, reqQty: (m['reqQty'] as num?)?.toDouble() ?? 0.0, receivedQty: (m['receivedQty'] as num?)?.toDouble() ?? 0.0);

}


class MaterialRequisition {

  String id, reqNo, date, targetStore, status, remarks, updatedAt;

  List<RequisitionLine> items;

  MaterialRequisition({required this.id, required this.reqNo, required this.date, required this.targetStore, this.status = 'Sent', this.remarks = '', required this.items, required this.updatedAt});

  Map<String, dynamic> toMap() => {'id': id, 'reqNo': reqNo, 'date': date, 'targetStore': targetStore, 'status': status, 'remarks': remarks, 'items': items.map((i) => i.toMap()).toList(), 'updatedAt': updatedAt};

  factory MaterialRequisition.fromMap(Map<String, dynamic> m) => MaterialRequisition(id: m['id'] ?? '', reqNo: m['reqNo'] ?? '', date: m['date'] ?? '', targetStore: m['targetStore'] ?? '', status: m['status'] ?? 'Sent', remarks: m['remarks'] ?? '', items: (m['items'] as List? ?? []).map((i) => RequisitionLine.fromMap(i)).toList(), updatedAt: m['updatedAt'] ?? '');

}


class StoreTx {

  String id, type, itemId, itemName, category, uom, date, jpName, sourceOrPerson, returnDueDate, remarks, requisitionId, serialNo, updatedAt;

  double qty;

  bool isReturnable, isReturned, hasAlarm;

  StoreTx({required this.id, required this.type, required this.itemId, required this.itemName, required this.category, required this.uom, required this.qty, required this.date, this.jpName = '', this.sourceOrPerson = '', this.isReturnable = false, this.returnDueDate = '', this.isReturned = false, this.hasAlarm = false, this.remarks = '', this.requisitionId = '', this.serialNo = '', required this.updatedAt});

  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'itemId': itemId, 'itemName': itemName, 'category': category, 'uom': uom, 'qty': qty, 'date': date, 'jpName': jpName, 'sourceOrPerson': sourceOrPerson, 'isReturnable': isReturnable, 'returnDueDate': returnDueDate, 'isReturned': isReturned, 'hasAlarm': hasAlarm, 'remarks': remarks, 'requisitionId': requisitionId, 'serialNo': serialNo, 'updatedAt': updatedAt};

  factory StoreTx.fromMap(Map<String, dynamic> m) => StoreTx(id: m['id'] ?? '', type: m['type'] ?? 'RECEIVE', itemId: m['itemId'] ?? '', itemName: m['itemName'] ?? '', category: m['category'] ?? '', uom: m['uom'] ?? 'Pcs', qty: (m['qty'] as num?)?.toDouble() ?? 0.0, date: m['date'] ?? '', jpName: m['jpName'] ?? '', sourceOrPerson: m['sourceOrPerson'] ?? '', isReturnable: m['isReturnable'] ?? false, returnDueDate: m['returnDueDate'] ?? '', isReturned: m['isReturned'] ?? false, hasAlarm: m['hasAlarm'] ?? false, remarks: m['remarks'] ?? '', requisitionId: m['requisitionId'] ?? '', serialNo: m['serialNo'] ?? '', updatedAt: m['updatedAt'] ?? '');

}


class JpProfile {

  String id, name, location, updatedAt;

  JpProfile({required this.id, required this.name, this.location = '', required this.updatedAt});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'location': location, 'updatedAt': updatedAt};

  factory JpProfile.fromMap(Map<String, dynamic> m) => JpProfile(id: m['id'] ?? '', name: m['name'] ?? '', location: m['location'] ?? '', updatedAt: m['updatedAt'] ?? '');

}


class TrashItem {

  String id, type, title, subtitle, deletedAt;

  Map<String, dynamic> rawData;

  TrashItem({required this.id, required this.type, required this.title, required this.subtitle, required this.deletedAt, required this.rawData});

  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'title': title, 'subtitle': subtitle, 'deletedAt': deletedAt, 'rawData': rawData};

  factory TrashItem.fromMap(Map<String, dynamic> m) => TrashItem(id: m['id'] ?? '', type: m['type'] ?? '', title: m['title'] ?? '', subtitle: m['subtitle'] ?? '', deletedAt: m['deletedAt'] ?? '', rawData: m['rawData'] ?? {});

}


class MainStoreScreen extends StatefulWidget {

  const MainStoreScreen({super.key});

  @override

  State<MainStoreScreen> createState() => _MainStoreScreenState();

}


class _MainStoreScreenState extends State<MainStoreScreen> {

  int _navIndex = 0;

  List<CatalogItem> catalog = [];

  List<JpProfile> jpList = [];

  List<StoreTx> transactions = [];

  List<MaterialRequisition> requisitions = [];

  List<TrashItem> recycleBin = [];


  List<String> deletedItemIds = [], deletedJpIds = [], deletedTxIds = [], deletedReqIds = [];

  String? touchedId;


  final List<String> commonUoms = ['Pcs', 'Mtr', 'Kg', 'Ltr', 'Box', 'Roll', 'Set', 'Pair', 'Drum', 'Can', 'Pkt', 'Bundle', 'Bag', 'Sheet'];

  final List<String> commonCategories = ['General', 'Tools & Tackles', 'Safety & PPE', 'Electrical', 'Mechanical Spares', 'Welding Consumables', 'Chemical & Paint', 'Civil Material'];


  final List<Color> dateBgPalette = const [Color(0xFFEBF5FF), Color(0xFFFEF3C7), Color(0xFFE8F5E9), Color(0xFFF3E8FF), Color(0xFFFFEDD5), Color(0xFFFCE7F3)];

  final List<Color> dateBorderPalette = const [Color(0xFF3B82F6), Color(0xFFD97706), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF97316), Color(0xFFEC4899)];


  String _securityPin = '1234', _firebaseUrl = '', _cloudStoreId = 'saari_general_store', _lastSyncStatus = 'Not Synced';

  bool _isSyncing = false, _isSettingsUnlocked = false;


  @override

  void initState() {

    super.initState();

    _loadData().then((_) {

      if (_firebaseUrl.isNotEmpty) _syncWithCloud(silent: true);

    });

  }


  void _toggleTouch(String id) {

    setState(() { touchedId = (touchedId == id) ? null : id; });

  }


  BoxDecoration _cardTouchStyle(String id, {Color? defaultBg, Color? defaultBorder}) {

    final isT = (touchedId == id);

    return BoxDecoration(

      color: isT ? const Color(0xFFFEF3C7) : (defaultBg ?? Colors.white),

      borderRadius: BorderRadius.circular(8),

      border: Border.all(color: isT ? const Color(0xFFF25F22) : (defaultBorder ?? Colors.black12), width: isT ? 2.2 : 1.0),

    );

  }


  Future<File> _getFile() async {

    final dir = await getApplicationDocumentsDirectory();

    return File('${dir.path}/saari_store_data.json');

  }


  Future<void> _loadData() async {

    try {

      final file = await _getFile();

      if (await file.exists()) {

        final data = jsonDecode(await file.readAsString());

        if (!mounted) return;

        setState(() {

          catalog = (data['catalog'] as List? ?? []).map((x) => CatalogItem.fromMap(x)).toList();

          jpList = (data['jpList'] as List? ?? []).map((x) => JpProfile.fromMap(x)).toList();

          transactions = (data['transactions'] as List? ?? []).map((x) => StoreTx.fromMap(x)).toList();

          requisitions = (data['requisitions'] as List? ?? []).map((x) => MaterialRequisition.fromMap(x)).toList();

          recycleBin = (data['recycleBin'] as List? ?? []).map((x) => TrashItem.fromMap(x)).toList();

          if (data['deletedItemIds'] != null) deletedItemIds = List<String>.from(data['deletedItemIds']);

          if (data['deletedJpIds'] != null) deletedJpIds = List<String>.from(data['deletedJpIds']);

          if (data['deletedTxIds'] != null) deletedTxIds = List<String>.from(data['deletedTxIds']);

          if (data['deletedReqIds'] != null) deletedReqIds = List<String>.from(data['deletedReqIds']);

          if (data['securityPin'] != null) _securityPin = data['securityPin'].toString();

          if (data['firebaseUrl'] != null) _firebaseUrl = data['firebaseUrl'].toString();

          if (data['cloudStoreId'] != null) _cloudStoreId = data['cloudStoreId'].toString();

          catalog.removeWhere((i) => deletedItemIds.contains(i.id));

          jpList.removeWhere((j) => deletedJpIds.contains(j.id));

          transactions.removeWhere((t) => deletedTxIds.contains(t.id));

          requisitions.removeWhere((r) => deletedReqIds.contains(r.id));

        });

      } else {

        _loadDefaultSeed();

      }

    } catch (_) {

      _loadDefaultSeed();

    }

  }


  void _loadDefaultSeed() {

    jpList = [

      JpProfile(id: const Uuid().v4(), name: 'JP-Alpha (Site 1)', location: 'Yard 1', updatedAt: DateTime.now().toIso8601String()),

      JpProfile(id: const Uuid().v4(), name: 'JP-Beta (Workshop)', location: 'Bay 2', updatedAt: DateTime.now().toIso8601String()),

    ];

    catalog = [

      CatalogItem(id: const Uuid().v4(), name: 'Welding Machine 400A', category: 'Tools & Tackles', uom: 'Set', isReturnableDefault: true, updatedAt: DateTime.now().toIso8601String()),

      CatalogItem(id: const Uuid().v4(), name: 'Grinding Wheel 4"', category: 'Tools & Tackles', uom: 'Pcs', updatedAt: DateTime.now().toIso8601String()),

      CatalogItem(id: const Uuid().v4(), name: 'Welding Electrode E7018', category: 'Welding Consumables', uom: 'Pkt', updatedAt: DateTime.now().toIso8601String()),

      CatalogItem(id: const Uuid().v4(), name: 'Safety Helmet', category: 'Safety & PPE', uom: 'Pcs', isReturnableDefault: true, updatedAt: DateTime.now().toIso8601String()),

    ];

    _saveData();

  }


  Future<void> _saveData() async {

    try {

      final file = await _getFile();

      await file.writeAsString(jsonEncode({

        'catalog': catalog.map((x) => x.toMap()).toList(),

        'jpList': jpList.map((x) => x.toMap()).toList(),

        'transactions': transactions.map((x) => x.toMap()).toList(),

        'requisitions': requisitions.map((x) => x.toMap()).toList(),

        'recycleBin': recycleBin.map((x) => x.toMap()).toList(),

        'deletedItemIds': deletedItemIds,

        'deletedJpIds': deletedJpIds,

        'deletedTxIds': deletedTxIds,

        'deletedReqIds': deletedReqIds,

        'securityPin': _securityPin,

        'firebaseUrl': _firebaseUrl,

        'cloudStoreId': _cloudStoreId,

      }));

    } catch (_) {}

  }


  double _getItemCurrentStock(String itemId) {

    double stock = 0.0;

    for (var t in transactions) {

      if (t.itemId == itemId) {

        if (t.type == 'RECEIVE' || t.type == 'RETURN' || t.type == 'ADJUST') stock += t.qty;

        if (t.type == 'ISSUE') stock -= t.qty;

      }

    }

    return stock;

  }


  Future<Directory?> _promptFolderSelection() async {

    final docsDir = await getApplicationDocumentsDirectory();

    Directory? dlDir;

    try { dlDir = await getDownloadsDirectory(); } catch (_) {}

    if (dlDir == null && Platform.isAndroid) {

      final androidDl = Directory('/storage/emulated/0/Download');

      if (await androidDl.exists()) dlDir = androidDl;

    }


    String selectedPath = (dlDir ?? docsDir).path;

    final pathCtrl = TextEditingController(text: selectedPath);


    if (!mounted) return dlDir ?? docsDir;

    final chosen = await showDialog<String>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Save File Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            if (dlDir != null)

              ListTile(

                leading: const Icon(Icons.download, color: Colors.blue),

                title: const Text('Downloads Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

                subtitle: Text(dlDir.path, style: const TextStyle(fontSize: 10)),

                onTap: () => Navigator.pop(ctx, dlDir!.path),

              ),

            ListTile(

              leading: const Icon(Icons.folder, color: Colors.amber),

              title: const Text('Documents Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

              subtitle: Text(docsDir.path, style: const TextStyle(fontSize: 10)),

              onTap: () => Navigator.pop(ctx, docsDir.path),

            ),

            const Divider(),

            TextField(controller: pathCtrl, style: const TextStyle(fontSize: 11), decoration: const InputDecoration(labelText: 'Custom Folder Path')),

          ],

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),

          ElevatedButton(onPressed: () => Navigator.pop(ctx, pathCtrl.text.trim()), child: const Text('Save Here')),

        ],

      ),

    );


    if (chosen != null && chosen.isNotEmpty) {

      final d = Directory(chosen);

      if (!await d.exists()) await d.create(recursive: true);

      return d;

    }

    return null;

  }


  Future<void> _syncWithCloud({bool silent = false}) async {

    if (_isSyncing || _firebaseUrl.trim().isEmpty) return;

    setState(() => _isSyncing = true);

    try {

      String baseUrl = _firebaseUrl.trim();

      if (!baseUrl.startsWith('http')) baseUrl = 'https://$baseUrl';

      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

      final syncUri = Uri.parse('$baseUrl/$_cloudStoreId.json');

      final res = await http.get(syncUri).timeout(const Duration(seconds: 10));


      if (res.statusCode == 200 && res.body != 'null' && res.body.isNotEmpty) {

        final remote = jsonDecode(res.body);

        if (remote is Map) {

          deletedItemIds = {...deletedItemIds, ...List<String>.from(remote['deletedItemIds'] ?? [])}.toList();

          deletedJpIds = {...deletedJpIds, ...List<String>.from(remote['deletedJpIds'] ?? [])}.toList();

          deletedTxIds = {...deletedTxIds, ...List<String>.from(remote['deletedTxIds'] ?? [])}.toList();

          deletedReqIds = {...deletedReqIds, ...List<String>.from(remote['deletedReqIds'] ?? [])}.toList();


          final localCat = {for (var i in catalog) i.id: i}..removeWhere((id, _) => deletedItemIds.contains(id));

          for (var r in (remote['catalog'] as List? ?? [])) {

            final item = CatalogItem.fromMap(r);

            if (!deletedItemIds.contains(item.id)) localCat[item.id] = item;

          }

          final localJp = {for (var j in jpList) j.id: j}..removeWhere((id, _) => deletedJpIds.contains(id));

          for (var r in (remote['jpList'] as List? ?? [])) {

            final jp = JpProfile.fromMap(r);

            if (!deletedJpIds.contains(jp.id)) localJp[jp.id] = jp;

          }

          final localTx = {for (var t in transactions) t.id: t}..removeWhere((id, _) => deletedTxIds.contains(id));

          for (var r in (remote['transactions'] as List? ?? [])) {

            final tx = StoreTx.fromMap(r);

            if (!deletedTxIds.contains(tx.id)) localTx[tx.id] = tx;

          }

          final localReq = {for (var q in requisitions) q.id: q}..removeWhere((id, _) => deletedReqIds.contains(id));

          for (var r in (remote['requisitions'] as List? ?? [])) {

            final req = MaterialRequisition.fromMap(r);

            if (!deletedReqIds.contains(req.id)) localReq[req.id] = req;

          }


          if (mounted) {

            setState(() {

              catalog = localCat.values.toList();

              jpList = localJp.values.toList();

              transactions = localTx.values.toList();

              requisitions = localReq.values.toList();

            });

          }

        }

      }


      await http.put(syncUri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({

        'updatedAt': DateTime.now().toIso8601String(),

        'catalog': catalog.map((x) => x.toMap()).toList(),

        'jpList': jpList.map((x) => x.toMap()).toList(),

        'transactions': transactions.map((x) => x.toMap()).toList(),

        'requisitions': requisitions.map((x) => x.toMap()).toList(),

        'deletedItemIds': deletedItemIds,

        'deletedJpIds': deletedJpIds,

        'deletedTxIds': deletedTxIds,

        'deletedReqIds': deletedReqIds,

      })).timeout(const Duration(seconds: 10));


      await _saveData();

      if (mounted) setState(() => _lastSyncStatus = 'Synced at ${DateFormat('hh:mm a').format(DateTime.now())}');

    } catch (_) {

      if (mounted) setState(() => _lastSyncStatus = 'Sync Error');

    } finally {

      if (mounted) setState(() => _isSyncing = false);

    }

  }


  Future<bool> _authenticateAction(String title) async {

    final pinResult = await showDialog<bool>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) {

        final pinCtrl = TextEditingController();

        String err = '';

        return StatefulBuilder(

          builder: (context, setDState) => AlertDialog(

            title: Text('PIN - $title', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),

            content: TextField(

              controller: pinCtrl,

              obscureText: true,

              keyboardType: TextInputType.number,

              decoration: InputDecoration(labelText: 'Master PIN', errorText: err.isNotEmpty ? err : null),

            ),

            actions: [

              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),

              ElevatedButton(

                onPressed: () {

                  if (pinCtrl.text.trim() == _securityPin.trim()) Navigator.pop(ctx, true);

                  else setDState(() => err = 'Incorrect PIN!');

                },

                child: const Text('Confirm'),

              ),

            ],

          ),

        );

      },

    );

    return pinResult ?? false;

  }// =====================================================================

// PART 2 OF 3: REQUISITIONS & JP PROFILES (WITH DATE PICKER & MONTHLY SUMMARY)

// =====================================================================


  Widget _buildRequisitionsScreen() {

    return Scaffold(

      floatingActionButton: FloatingActionButton.extended(

        backgroundColor: const Color(0xFFF25F22),

        icon: const Icon(Icons.add, color: Colors.white),

        label: const Text('New Requisition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

        onPressed: () => _openRequisitionDialog(),

      ),

      body: requisitions.isEmpty

          ? const Center(child: Text('No Requisition Found.'))

          : ListView.builder(

              padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),

              itemCount: requisitions.length,

              itemBuilder: (ctx, idx) {

                final req = requisitions[requisitions.length - 1 - idx];

                double totalReq = req.items.fold(0.0, (sum, i) => sum + i.reqQty);

                double totalRec = req.items.fold(0.0, (sum, i) => sum + i.receivedQty);

                Color stColor = req.status == 'Received' ? Colors.green : (req.status == 'Partial' ? Colors.blue : Colors.orange);


                return Container(

                  margin: const EdgeInsets.only(bottom: 8),

                  decoration: _cardTouchStyle(req.id),

                  child: ExpansionTile(

                    onExpansionChanged: (_) => _toggleTouch(req.id),

                    title: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        Text('Req #: ${req.reqNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

                        Chip(label: Text(req.status, style: TextStyle(color: stColor, fontSize: 10, fontWeight: FontWeight.bold)), backgroundColor: stColor.withOpacity(0.12)),

                      ],

                    ),

                    subtitle: Text('Date: ${req.date} | Target: ${req.targetStore}\nItems: ${req.items.length} | Req: $totalReq | Rec: $totalRec', style: const TextStyle(fontSize: 11)),

                    children: [

                      const Divider(height: 1),

                      ...req.items.map((line) => Padding(

                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),

                            child: Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [

                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                                  Text(line.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),

                                  Text('Prev Balance: ${line.prevStock} ${line.uom}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),

                                ])),

                                Text('Req: ${line.reqQty} ${line.uom}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0B2545))),

                                const SizedBox(width: 8),

                                Text('Rec: ${line.receivedQty} ${line.uom}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: line.receivedQty >= line.reqQty ? Colors.green : Colors.orange.shade800)),

                              ],

                            ),

                          )),

                      Padding(

                        padding: const EdgeInsets.all(8.0),

                        child: Wrap(

                          spacing: 6,

                          alignment: WrapAlignment.end,

                          children: [

                            OutlinedButton.icon(icon: const Icon(Icons.table_chart, size: 14, color: Colors.green), label: const Text('Excel', style: TextStyle(fontSize: 11, color: Colors.green)), onPressed: () => _exportRequisitionDoc(req, isPdf: false)),

                            OutlinedButton.icon(icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.red), label: const Text('PDF', style: TextStyle(fontSize: 11, color: Colors.red)), onPressed: () => _exportRequisitionDoc(req, isPdf: true)),

                            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2545)), icon: const Icon(Icons.check, size: 14, color: Colors.white), label: const Text('Receive Goods', style: TextStyle(fontSize: 11, color: Colors.white)), onPressed: () => _openRequisitionReceiveDialog(req)),

                            IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _openRequisitionDialog(existingReq: req)),

                            IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteRequisition(req)),

                          ],

                        ),

                      ),

                    ],

                  ),

                );

              },

            ),

    );

  }


  void _openRequisitionDialog({MaterialRequisition? existingReq}) async {

    final bool isEdit = existingReq != null;

    if (isEdit && !await _authenticateAction('Edit Requisition')) return;


    final targetCtrl = TextEditingController(text: isEdit ? existingReq.targetStore : 'Main Warehouse / Store 1');

    final remarksCtrl = TextEditingController(text: isEdit ? existingReq.remarks : '');

    String reqDate = isEdit ? existingReq.date : DateFormat('yyyy-MM-dd').format(DateTime.now());


    final Map<String, bool> checkedMap = {};

    final Map<String, TextEditingController> reqQtyCtrls = {};

    final Map<String, TextEditingController> prevStockCtrls = {};


    for (var catItem in catalog) {

      checkedMap[catItem.id] = false;

      reqQtyCtrls[catItem.id] = TextEditingController(text: '1');

      prevStockCtrls[catItem.id] = TextEditingController(text: _getItemCurrentStock(catItem.id).toString());

    }


    if (isEdit) {

      for (var line in existingReq.items) {

        checkedMap[line.itemId] = true;

        reqQtyCtrls.putIfAbsent(line.itemId, () => TextEditingController()).text = line.reqQty.toString();

        prevStockCtrls.putIfAbsent(line.itemId, () => TextEditingController()).text = line.prevStock.toString();

      }

    }


    String qSearch = '';

    if (!mounted) return;

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => StatefulBuilder(

        builder: (context, setDState) {

          final displayList = catalog.where((i) => i.name.toLowerCase().contains(qSearch.toLowerCase())).toList();

          return AlertDialog(

            title: Text(isEdit ? 'Edit Requisition' : 'New Requisition', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

            content: SizedBox(

              width: 550,

              height: 480,

              child: Column(

                children: [

                  TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Target Store *')),

                  const SizedBox(height: 6),

                  TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 16), hintText: 'Search items...'), onChanged: (v) => setDState(() => qSearch = v.trim())),

                  const SizedBox(height: 6),

                  Expanded(

                    child: ListView.separated(

                      itemCount: displayList.length,

                      separatorBuilder: (_, __) => const Divider(height: 1),

                      itemBuilder: (ctx, idx) {

                        final item = displayList[idx];

                        final isChecked = checkedMap[item.id] ?? false;

                        final reqCtrl = reqQtyCtrls[item.id]!;

                        final prevCtrl = prevStockCtrls[item.id]!;


                        return Container(

                          color: isChecked ? const Color(0xFFFFF7ED) : Colors.transparent,

                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),

                          child: Column(

                            children: [

                              Row(

                                children: [

                                  Checkbox(value: isChecked, onChanged: (v) => setDState(() => checkedMap[item.id] = v ?? false)),

                                  Expanded(child: Text(item.name, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, fontSize: 12))),

                                  if (isChecked) ...[

                                    IconButton(icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red), onPressed: () {

                                      double q = double.tryParse(reqCtrl.text) ?? 1;

                                      if (q > 1) { reqCtrl.text = (q - 1).toStringAsFixed(0); setDState(() {}); }

                                    }),

                                    SizedBox(width: 45, child: TextField(controller: reqCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),

                                    IconButton(icon: const Icon(Icons.add_circle, size: 18, color: Colors.green), onPressed: () {

                                      double q = double.tryParse(reqCtrl.text) ?? 0;

                                      reqCtrl.text = (q + 1).toStringAsFixed(0); setDState(() {});

                                    }),

                                    Text(item.uom, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),

                                  ],

                                ],

                              ),

                              if (isChecked)

                                Padding(

                                  padding: const EdgeInsets.only(left: 45, bottom: 4),

                                  child: Row(

                                    children: [

                                      const Text('Previous Balance: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),

                                      SizedBox(width: 55, child: TextField(controller: prevCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.blue))),

                                      const SizedBox(width: 4),

                                      Text(item.uom, style: const TextStyle(fontSize: 10)),

                                    ],

                                  ),

                                ),

                            ],

                          ),

                        );

                      },

                    ),

                  ),

                  TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),

                ],

              ),

            ),

            actions: [

              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),

              ElevatedButton(

                onPressed: () {

                  final List<RequisitionLine> lines = [];

                  for (var item in catalog) {

                    if (checkedMap[item.id] == true) {

                      double q = double.tryParse(reqQtyCtrls[item.id]?.text ?? '0') ?? 0;

                      double pStock = double.tryParse(prevStockCtrls[item.id]?.text ?? '0') ?? 0;

                      if (q > 0) {

                        double existingRec = isEdit ? (existingReq.items.where((x) => x.itemId == item.id).firstOrNull?.receivedQty ?? 0.0) : 0.0;

                        lines.add(RequisitionLine(itemId: item.id, itemName: item.name, uom: item.uom, prevStock: pStock, reqQty: q, receivedQty: existingRec));

                      }

                    }

                  }

                  if (lines.isEmpty) return;

                  setState(() {

                    if (isEdit) {

                      existingReq.targetStore = targetCtrl.text.trim();

                      existingReq.remarks = remarksCtrl.text.trim();

                      existingReq.items = lines;

                      existingReq.updatedAt = DateTime.now().toIso8601String();

                    } else {

                      requisitions.add(MaterialRequisition(

                        id: const Uuid().v4(),

                        reqNo: 'REQ-${DateFormat('yyMMdd').format(DateTime.now())}-${requisitions.length + 1}',

                        date: reqDate,

                        targetStore: targetCtrl.text.trim(),

                        remarks: remarksCtrl.text.trim(),

                        items: lines,

                        updatedAt: DateTime.now().toIso8601String(),

                      ));

                    }

                  });

                  _saveData();

                  _syncWithCloud(silent: true);

                  Navigator.pop(ctx);

                },

                child: Text(isEdit ? 'Update' : 'Submit'),

              ),

            ],

          );

        },

      ),

    );

  }


  void _openRequisitionReceiveDialog(MaterialRequisition req) {

    final Map<String, TextEditingController> recCtrls = {for (var l in req.items) l.itemId: TextEditingController(text: l.receivedQty > 0 ? l.receivedQty.toString() : l.reqQty.toString())};

    showDialog(

      context: context,

      builder: (ctx) => StatefulBuilder(

        builder: (context, setDState) => AlertDialog(

          title: Text('Receive Goods - ${req.reqNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

          content: SizedBox(

            width: 480,

            child: ListView.builder(

              shrinkWrap: true,

              itemCount: req.items.length,

              itemBuilder: (ctx, idx) {

                final line = req.items[idx];

                final ctrl = recCtrls[line.itemId]!;

                return Row(

                  children: [

                    Expanded(child: Text('${line.itemName} (Req: ${line.reqQty})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),

                    IconButton(icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red), onPressed: () {

                      double cur = double.tryParse(ctrl.text) ?? 0;

                      if (cur > 0) { ctrl.text = (cur - 1).toStringAsFixed(0); setDState(() {}); }

                    }),

                    SizedBox(width: 45, child: TextField(controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),

                    IconButton(icon: const Icon(Icons.add_circle, size: 18, color: Colors.green), onPressed: () {

                      double cur = double.tryParse(ctrl.text) ?? 0;

                      ctrl.text = (cur + 1).toStringAsFixed(0); setDState(() {});

                    }),

                    Text(line.uom, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),

                  ],

                );

              },

            ),

          ),

          actions: [

            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),

            ElevatedButton(

              onPressed: () {

                bool allFull = true, anyRec = false;

                setState(() {

                  for (var line in req.items) {

                    double rec = double.tryParse(recCtrls[line.itemId]?.text ?? '0') ?? 0.0;

                    double delta = rec - line.receivedQty;

                    if (delta > 0) {

                      transactions.add(StoreTx(id: const Uuid().v4(), type: 'RECEIVE', itemId: line.itemId, itemName: line.itemName, category: '', uom: line.uom, qty: delta, date: DateFormat('yyyy-MM-dd').format(DateTime.now()), sourceOrPerson: req.targetStore, remarks: 'Received ${req.reqNo}', requisitionId: req.id, updatedAt: DateTime.now().toIso8601String()));

                    }

                    line.receivedQty = rec;

                    if (rec < line.reqQty) allFull = false;

                    if (rec > 0) anyRec = true;

                  }

                  req.status = allFull ? 'Received' : (anyRec ? 'Partial' : 'Sent');

                  req.updatedAt = DateTime.now().toIso8601String();

                });

                _saveData();

                _syncWithCloud(silent: true);

                Navigator.pop(ctx);

              },

              child: const Text('Confirm Receipt'),

            ),

          ],

        ),

      ),

    );

  }


  void _deleteRequisition(MaterialRequisition req) async {

    if (!await _authenticateAction('Delete Requisition')) return;

    setState(() {

      requisitions.removeWhere((r) => r.id == req.id);

      deletedReqIds.add(req.id);

      recycleBin.insert(0, TrashItem(id: req.id, type: 'REQUISITION', title: 'Requisition: ${req.reqNo}', subtitle: 'Target: ${req.targetStore} | Date: ${req.date}', deletedAt: DateTime.now().toIso8601String(), rawData: req.toMap()));

    });

    _saveData();

    _syncWithCloud(silent: true);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requisition moved to Recycle Bin!')));

  }


  Future<void> _exportRequisitionDoc(MaterialRequisition req, {required bool isPdf}) async {

    final dir = await _promptFolderSelection();

    if (dir == null) return;

    final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());


    if (!isPdf) {

      final StringBuffer csv = StringBuffer()..writeln('\uFEFFSAARI OIL FIELD SERVICES - REQUISITION ${req.reqNo}')..writeln('Date: ${req.date} | Target: ${req.targetStore}')..writeln('Item,Unit,Previous Balance,Requested,Received');

      for (var l in req.items) { csv.writeln('"${l.itemName}","${l.uom}",${l.prevStock},${l.reqQty},${l.receivedQty}'); }

      final file = File('${dir.path}/Req_${req.reqNo}_$nowStr.csv');

      await file.writeAsString(csv.toString());

      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Excel Saved'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));

    } else {

      final StringBuffer html = StringBuffer()..writeln('<html><head><meta charset="utf-8"></head><body style="font-family:sans-serif;padding:20px;"><h2>SAARI OIL FIELD SERVICES - REQUISITION</h2><p><b>Req No:</b> ${req.reqNo} | <b>Date:</b> ${req.date} | <b>Target:</b> ${req.targetStore}</p><table border="1" cellpadding="6" style="border-collapse:collapse;width:100%;"><tr><th>Item</th><th>Unit</th><th>Previous Balance</th><th>Requested</th><th>Received</th></tr>');

      for (var l in req.items) { html.writeln('<tr><td>${l.itemName}</td><td>${l.uom}</td><td>${l.prevStock}</td><td>${l.reqQty}</td><td>${l.receivedQty}</td></tr>'); }

      html.writeln('</table><br><button onclick="window.print()">Print / Save PDF</button></body></html>');

      final file = File('${dir.path}/Req_${req.reqNo}_$nowStr.html');

      await file.writeAsString(html.toString());

      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('PDF Saved'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));

    }

  }


  Widget _buildJpScreen() {

    return Scaffold(

      floatingActionButton: FloatingActionButton.extended(

        backgroundColor: const Color(0xFF0B2545),

        icon: const Icon(Icons.person_add, color: Colors.white),

        label: const Text('Add New JP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

        onPressed: () => _openJpDialog(),

      ),

      body: jpList.isEmpty

          ? const Center(child: Text('No JPs Found. Tap "Add New JP".'))

          : ListView.builder(

              padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),

              itemCount: jpList.length,

              itemBuilder: (ctx, idx) {

                final jp = jpList[idx];

                final int totalIssues = transactions.where((t) => t.jpName == jp.name && t.type == 'ISSUE').length;

                return Container(

                  margin: const EdgeInsets.only(bottom: 6),

                  decoration: _cardTouchStyle(jp.id),

                  child: ListTile(

     
