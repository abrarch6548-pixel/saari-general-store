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
// PART 2 OF 3: REQUISITIONS & JP PROFILES WITH SERIAL NUMBER ISSUANCE
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
                    onTap: () { _toggleTouch(jp.id); _openJpDetailProfileScreen(jp); },
                    leading: const CircleAvatar(backgroundColor: Color(0xFF0B2545), child: Icon(Icons.engineering, color: Colors.white, size: 18)),
                    title: Text(jp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Location: ${jp.location.isEmpty ? "Site" : jp.location} | Total Issues: $totalIssues', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _openJpDialog(existingJp: jp)),
                        IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteJpProfile(jp)),
                        const Icon(Icons.arrow_forward_ios, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openJpDialog({JpProfile? existingJp}) async {
    final bool isEdit = existingJp != null;
    if (isEdit && !await _authenticateAction('Edit JP')) return;
    final nameCtrl = TextEditingController(text: isEdit ? existingJp.name : '');
    final locCtrl = TextEditingController(text: isEdit ? existingJp.location : '');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit JP' : 'Add New JP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'JP Name *')),
            const SizedBox(height: 8),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location / Line')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              setState(() {
                if (isEdit) {
                  final old = existingJp.name;
                  existingJp.name = n;
                  existingJp.location = locCtrl.text.trim();
                  existingJp.updatedAt = DateTime.now().toIso8601String();
                  for (var t in transactions) { if (t.jpName == old) t.jpName = n; }
                } else {
                  jpList.add(JpProfile(id: const Uuid().v4(), name: n, location: locCtrl.text.trim(), updatedAt: DateTime.now().toIso8601String()));
                }
              });
              _saveData();
              _syncWithCloud(silent: true);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteJpProfile(JpProfile jp) async {
    if (!await _authenticateAction('Delete JP Profile')) return;
    setState(() {
      jpList.removeWhere((j) => j.id == jp.id);
      deletedJpIds.add(jp.id);
      recycleBin.insert(0, TrashItem(id: jp.id, type: 'JP', title: 'JP: ${jp.name}', subtitle: 'Location: ${jp.location}', deletedAt: DateTime.now().toIso8601String(), rawData: jp.toMap()));
    });
    _saveData();
    _syncWithCloud(silent: true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JP moved to Recycle Bin!')));
  }

  void _openJpDetailProfileScreen(JpProfile jp) {
    String dateFilter = 'ALL';
    DateTime? cStart, cEnd;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (ctx, setPState) {
            final now = DateTime.now();
            final allTx = transactions.where((t) => t.jpName == jp.name).toList();
            final filteredTx = allTx.where((t) {
              final d = DateTime.tryParse(t.date);
              if (d == null) return true;
              if (dateFilter == 'TODAY') return d.year == now.year && d.month == now.month && d.day == now.day;
              if (dateFilter == 'WEEK') return now.difference(d).inDays <= 7;
              if (dateFilter == 'MONTH') return d.year == now.year && d.month == now.month;
              if (cStart != null && cEnd != null) return !d.isBefore(cStart!) && !d.isAfter(cEnd!);
              return true;
            }).toList();

            final uniqueDates = <String>[];
            for (var t in filteredTx) {
              if (!uniqueDates.contains(t.date)) uniqueDates.add(t.date);
            }

            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF0B2545),
                foregroundColor: Colors.white,
                title: Text(jp.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(icon: const Icon(Icons.table_chart, color: Colors.greenAccent), onPressed: () => _exportJpLedgerDoc(jp, filteredTx, isPdf: false)),
                  IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), onPressed: () => _exportJpLedgerDoc(jp, filteredTx, isPdf: true)),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: const Color(0xFFF25F22),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Issue Material', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async { await _openMaterialIssueToJpDialog(jp); setPState(() {}); },
              ),
              body: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        FilterChip(label: const Text('All Time'), selected: dateFilter == 'ALL', onSelected: (_) => setPState(() { dateFilter = 'ALL'; cStart = null; cEnd = null; })),
                        const SizedBox(width: 4),
                        FilterChip(label: const Text('Today'), selected: dateFilter == 'TODAY', onSelected: (_) => setPState(() => dateFilter = 'TODAY')),
                        const SizedBox(width: 4),
                        FilterChip(label: const Text('7 Days'), selected: dateFilter == 'WEEK', onSelected: (_) => setPState(() => dateFilter = 'WEEK')),
                        const SizedBox(width: 4),
                        FilterChip(label: const Text('This Month'), selected: dateFilter == 'MONTH', onSelected: (_) => setPState(() => dateFilter = 'MONTH')),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text(cStart != null ? '${DateFormat('dd/MM').format(cStart!)} - ${DateFormat('dd/MM').format(cEnd!)}' : 'Range', style: const TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035));
                            if (r != null) setPState(() { dateFilter = 'CUSTOM'; cStart = r.start; cEnd = r.end; });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredTx.isEmpty
                        ? const Center(child: Text('No material records found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                            itemCount: filteredTx.length,
                            itemBuilder: (ctx, idx) {
                              final t = filteredTx[filteredTx.length - 1 - idx];
                              bool isIss = t.type == 'ISSUE';
                              String srInfo = t.serialNo.isNotEmpty ? ' | Sr: ${t.serialNo}' : '';

                              int dateIdx = uniqueDates.indexOf(t.date);
                              Color dateBg = dateBgPalette[dateIdx % dateBgPalette.length];
                              Color dateBorder = dateBorderPalette[dateIdx % dateBorderPalette.length];
                              bool isFirstOfDate = (idx == 0) || (filteredTx[filteredTx.length - idx].date != t.date);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isFirstOfDate)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: dateBorder.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: dateBorder, width: 0.8)),
                                      child: Text('📅 Tarikh: ${t.date}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: dateBorder)),
                                    ),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: _cardTouchStyle(t.id, defaultBg: dateBg, defaultBorder: dateBorder),
                                    child: ListTile(
                                      onTap: () => _toggleTouch(t.id),
                                      leading: Icon(isIss ? Icons.arrow_upward : Icons.assignment_return, color: isIss ? Colors.orange.shade800 : Colors.teal.shade800),
                                      title: Text('${t.itemName} - ${t.qty} ${t.uom}$srInfo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      subtitle: Text('${t.remarks.isEmpty ? "" : "${t.remarks} | "}${t.isReturnable ? (t.isReturned ? "Returned ✅" : "Due: ${t.returnDueDate} ⚠️") : "Consumed"}${t.hasAlarm ? " ⏰" : ""}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (t.isReturnable && !t.isReturned)
                                            ElevatedButton(onPressed: () => _markItemReturned(t, () => setPState(() {})), child: const Text('Return', style: TextStyle(fontSize: 10))),
                                          IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _editStoreTransaction(t, () => setPState(() {}))),
                                          IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteStoreTransaction(t, () => setPState(() {}))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _editStoreTransaction(StoreTx t, VoidCallback onDone) async {
    if (!await _authenticateAction('Edit Issued Record')) return;
    final qCtrl = TextEditingController(text: t.qty.toString());
    final srCtrl = TextEditingController(text: t.serialNo);
    final remCtrl = TextEditingController(text: t.remarks);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Issue: ${t.itemName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity (${t.uom}) *')),
            const SizedBox(height: 6),
            TextField(controller: srCtrl, decoration: const InputDecoration(labelText: 'Serial No (Optional)')),
            const SizedBox(height: 6),
            TextField(controller: remCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              double nq = double.tryParse(qCtrl.text) ?? 0;
              if (nq <= 0) return;
              setState(() {
                t.qty = nq;
                t.serialNo = srCtrl.text.trim();
                t.remarks = remCtrl.text.trim();
                t.updatedAt = DateTime.now().toIso8601String();
              });
              _saveData();
              _syncWithCloud(silent: true);
              Navigator.pop(ctx);
              onDone();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteStoreTransaction(StoreTx t, VoidCallback onDone) async {
    if (!await _authenticateAction('Delete Issued Record')) return;
    setState(() {
      transactions.removeWhere((x) => x.id == t.id);
      deletedTxIds.add(t.id);
      recycleBin.insert(0, TrashItem(
        id: t.id,
        type: 'TX',
        title: 'Issue: ${t.itemName} (${t.qty} ${t.uom})',
        subtitle: 'JP: ${t.jpName} | Date: ${t.date} | Sr: ${t.serialNo}',
        deletedAt: DateTime.now().toIso8601String(),
        rawData: t.toMap(),
      ));
    });
    _saveData();
    _syncWithCloud(silent: true);
    onDone();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issued item deleted & stock returned to store!')));
  }

  Future<void> _openMaterialIssueToJpDialog(JpProfile jp) async {
    final Map<String, int> freq = {};
    for (var t in transactions) { if (t.jpName == jp.name && t.type == 'ISSUE') freq[t.itemId] = (freq[t.itemId] ?? 0) + 1; }
    final sortedCat = List<CatalogItem>.from(catalog)..sort((a, b) => (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0));

    final Map<String, bool> chk = {for (var i in catalog) i.id: false};
    final Map<String, bool> ret = {for (var i in catalog) i.id: i.isReturnableDefault};
    final Map<String, bool> alarmMap = {for (var i in catalog) i.id: false};
    final Map<String, TextEditingController> qCtrls = {for (var i in catalog) i.id: TextEditingController(text: '1')};
    final Map<String, TextEditingController> srCtrls = {for (var i in catalog) i.id: TextEditingController()};
    final Map<String, DateTime> returnDates = {for (var i in catalog) i.id: DateTime.now().add(const Duration(days: 7))};
    DateTime selDate = DateTime.now();
    String searchIssue = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) {
          final displayList = sortedCat.where((i) => i.name.toLowerCase().contains(searchIssue.toLowerCase()) || i.category.toLowerCase().contains(searchIssue.toLowerCase())).toList();

          return AlertDialog(
            title: Text('Issue to ${jp.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 520,
              height: 480,
              child: Column(
                children: [
                  TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 16), hintText: 'Quick Search Material...'), onChanged: (v) => setDState(() => searchIssue = v.trim())),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (ctx, idx) {
                        final item = displayList[idx];
                        final isChecked = chk[item.id] ?? false;
                        final ctrl = qCtrls[item.id]!;
                        final srCtrl = srCtrls[item.id]!;
                        final curStock = _getItemCurrentStock(item.id);

                        return Container(
                          color: isChecked ? const Color(0xFFFFF7ED) : Colors.transparent,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Checkbox(value: isChecked, onChanged: (v) => setDState(() => chk[item.id] = v ?? false)),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(item.name, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                                    Text('Stock: $curStock ${item.uom} | Freq: ${freq[item.id] ?? 0}', style: TextStyle(fontSize: 10, color: curStock > 0 ? Colors.green : Colors.red)),
                                  ])),
                                  if (isChecked) ...[
                                    IconButton(icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red), onPressed: () {
                                      double q = double.tryParse(ctrl.text) ?? 1;
                                      if (q > 1) { ctrl.text = (q - 1).toStringAsFixed(0); setDState(() {}); }
                                    }),
                                    SizedBox(width: 40, child: TextField(controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                                    IconButton(icon: const Icon(Icons.add_circle, size: 18, color: Colors.green), onPressed: () {
                                      double q = double.tryParse(ctrl.text) ?? 0;
                                      ctrl.text = (q + 1).toStringAsFixed(0); setDState(() {});
                                    }),
                                  ],
                                ],
                              ),
                              if (isChecked)
                                Padding(
                                  padding: const EdgeInsets.only(left: 36, bottom: 6, right: 6),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: srCtrl,
                                        style: const TextStyle(fontSize: 11),
                                        decoration: const InputDecoration(labelText: 'Serial No (Optional / Ikhtiyari)', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 4,
                                        children: [
                                          Checkbox(value: ret[item.id] ?? false, onChanged: (v) => setDState(() => ret[item.id] = v ?? false)),
                                          const Text('Returnable', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                                          if (ret[item.id] == true) ...[
                                            TextButton.icon(
                                              icon: const Icon(Icons.calendar_today, size: 13),
                                              label: Text('Due: ${DateFormat('dd/MM').format(returnDates[item.id]!)}', style: const TextStyle(fontSize: 11)),
                                              onPressed: () async {
                                                final d = await showDatePicker(context: context, initialDate: returnDates[item.id]!, firstDate: DateTime.now(), lastDate: DateTime(2035));
                                                if (d != null) setDState(() => returnDates[item.id] = d);
                                              },
                                            ),
                                            Checkbox(value: alarmMap[item.id] ?? false, onChanged: (v) => setDState(() => alarmMap[item.id] = v ?? false)),
                                            const Text('⏰ Set Alarm', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final List<StoreTx> issues = [];
                  for (var item in catalog) {
                    if (chk[item.id] == true) {
                      double q = double.tryParse(qCtrls[item.id]?.text ?? '0') ?? 0;
                      if (q > 0) {
                        issues.add(StoreTx(
                          id: const Uuid().v4(),
                          type: 'ISSUE',
                          itemId: item.id,
                          itemName: item.name,
                          category: item.category,
                          uom: item.uom,
                          qty: q,
                          date: DateFormat('yyyy-MM-dd').format(selDate),
                          jpName: jp.name,
                          serialNo: srCtrls[item.id]?.text.trim() ?? '',
                          isReturnable: ret[item.id] ?? false,
                          hasAlarm: alarmMap[item.id] ?? false,
                          returnDueDate: ret[item.id] == true ? DateFormat('yyyy-MM-dd').format(returnDates[item.id]!) : '',
                          updatedAt: DateTime.now().toIso8601String(),
                        ));
                      }
                    }
                  }
                  if (issues.isEmpty) return;
                  if (!await _authenticateAction('Issue Material')) return;
                  setState(() => transactions.addAll(issues));
                  _saveData();
                  _syncWithCloud(silent: true);
                  Navigator.pop(ctx);
                },
                child: const Text('Confirm Issue'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _markItemReturned(StoreTx tx, VoidCallback onDone) async {
    if (!await _authenticateAction('Receive Return')) return;
    setState(() {
      tx.isReturned = true;
      tx.updatedAt = DateTime.now().toIso8601String();
      transactions.add(StoreTx(id: const Uuid().v4(), type: 'RETURN', itemId: tx.itemId, itemName: tx.itemName, category: tx.category, uom: tx.uom, qty: tx.qty, date: DateFormat('yyyy-MM-dd').format(DateTime.now()), jpName: tx.jpName, serialNo: tx.serialNo, remarks: 'Returned', updatedAt: DateTime.now().toIso8601String()));
    });
    _saveData();
    _syncWithCloud(silent: true);
    onDone();
  }

  Future<void> _exportJpLedgerDoc(JpProfile jp, List<StoreTx> list, {required bool isPdf}) async {
    final dir = await _promptFolderSelection();
    if (dir == null) return;
    final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    if (!isPdf) {
      final StringBuffer csv = StringBuffer()..writeln('\uFEFFSAARI OIL FIELD SERVICES - LEDGER: ${jp.name}')..writeln('Type,Date,Item,Serial No,Category,Qty,UOM,Return Status,Alarm');
      for (var t in list) { csv.writeln('"${t.type}","${t.date}","${t.itemName}","${t.serialNo}","${t.category}",${t.qty},"${t.uom}","${t.isReturnable ? (t.isReturned ? 'Returned' : 'Pending (Due: ${t.returnDueDate})') : 'Consumed'}","${t.hasAlarm ? 'Yes' : 'No'}"'); }
      final file = File('${dir.path}/Ledger_${jp.name}_$nowStr.csv');
      await file.writeAsString(csv.toString());
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Excel Exported'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
    } else {
      final StringBuffer html = StringBuffer()..writeln('<html><body style="font-family:sans-serif;padding:20px;"><h2>SAARI STORE - LEDGER: ${jp.name}</h2><table border="1" cellpadding="5" style="border-collapse:collapse;width:100%;"><tr><th>Type</th><th>Date</th><th>Item</th><th>Serial No</th><th>Qty</th><th>UOM</th><th>Status</th><th>Alarm</th></tr>');
      for (var t in list) { html.writeln('<tr><td>${t.type}</td><td>${t.date}</td><td>${t.itemName}</td><td>${t.serialNo.isEmpty ? "-" : t.serialNo}</td><td>${t.qty}</td><td>${t.uom}</td><td>${t.isReturnable ? (t.isReturned ? "Returned" : "Pending Due: ${t.returnDueDate}") : "Consumed"}</td><td>${t.hasAlarm ? "Active ⏰" : "-"}</td></tr>'); }
      html.writeln('</table><br><button onclick="window.print()">Print PDF</button></body></html>');
      final file = File('${dir.path}/Ledger_${jp.name}_$nowStr.html');
      await file.writeAsString(html.toString());
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('PDF Ready'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
    }
  }// =====================================================================
// PART 3 OF 3: RETURNS SCREEN, STOCK ADJUST, RECYCLE BIN & SETTINGS
// =====================================================================

  Widget _buildReturnsAndAlarmsScreen() {
    String q = '';
    return StatefulBuilder(
      builder: (context, setRetState) {
        final now = DateTime.now();
        final returnList = transactions.where((t) => t.isReturnable && !t.isReturned && t.type == 'ISSUE').toList();

        returnList.sort((a, b) {
          final da = DateTime.tryParse(a.returnDueDate) ?? DateTime(2099);
          final db = DateTime.tryParse(b.returnDueDate) ?? DateTime(2099);
          final aOver = da.isBefore(now);
          final bOver = db.isBefore(now);
          if (aOver && !bOver) return -1;
          if (!aOver && bOver) return 1;
          return da.compareTo(db);
        });

        final filtered = returnList.where((t) {
          final s = q.toLowerCase();
          return t.jpName.toLowerCase().contains(s) || t.itemName.toLowerCase().contains(s) || t.serialNo.toLowerCase().contains(s) || t.returnDueDate.contains(s) || t.date.contains(s);
        }).toList();

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by JP, Item, Serial No, or Date...'),
                  onChanged: (v) => setRetState(() => q = v.trim()),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No Pending Returnable Items!'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final t = filtered[idx];
                          final due = DateTime.tryParse(t.returnDueDate) ?? DateTime(2099);
                          final isOverdue = due.isBefore(now);
                          String srTxt = t.serialNo.isNotEmpty ? ' | Sr: ${t.serialNo}' : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isOverdue ? Colors.red.shade50 : (touchedId == t.id ? const Color(0xFFFEF3C7) : Colors.white),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isOverdue ? Colors.red : (touchedId == t.id ? const Color(0xFFF25F22) : Colors.black12), width: isOverdue || (touchedId == t.id) ? 2.0 : 1.0),
                            ),
                            child: ListTile(
                              onTap: () => _toggleTouch(t.id),
                              leading: Icon(isOverdue ? Icons.warning : (t.hasAlarm ? Icons.alarm : Icons.assignment_return), color: isOverdue ? Colors.red : (t.hasAlarm ? Colors.deepOrange : Colors.teal)),
                              title: Row(
                                children: [
                                  Expanded(child: Text('${t.itemName} (${t.qty} ${t.uom})$srTxt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  if (isOverdue) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              subtitle: Text('JP: ${t.jpName} | Return Due: ${t.returnDueDate}\nIssued: ${t.date} ${t.hasAlarm ? "| ⏰ Alarm Active" : ""}'),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: isOverdue ? Colors.red : Colors.teal),
                                onPressed: () => _markItemReturned(t, () => setRetState(() {})),
                                child: const Text('Return', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogScreen() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0B2545),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openCatalogItemDialog(),
      ),
      body: catalog.isEmpty
          ? const Center(child: Text('Catalog is empty.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
              itemCount: catalog.length,
              itemBuilder: (ctx, idx) {
                final item = catalog[idx];
                final stock = _getItemCurrentStock(item.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: _cardTouchStyle(item.id),
                  child: ListTile(
                    onTap: () => _toggleTouch(item.id),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${item.category} | Stock: $stock ${item.uom}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _openCatalogItemDialog(existingItem: item)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deleteCatalogItem(item)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openCatalogItemDialog({CatalogItem? existingItem}) async {
    final bool isEdit = existingItem != null;
    if (isEdit && !await _authenticateAction('Edit Catalog Item')) return;
    final nameCtrl = TextEditingController(text: isEdit ? existingItem.name : '');
    String cat = isEdit ? existingItem.category : commonCategories.first;
    String uom = isEdit ? existingItem.uom : 'Pcs';
    bool ret = isEdit ? existingItem.isReturnableDefault : false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text(isEdit ? 'Edit Item' : 'New Catalog Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name *')),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: commonCategories.contains(cat) ? cat : commonCategories.first, items: commonCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDState(() => cat = v!)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: commonUoms.contains(uom) ? uom : commonUoms.first, items: commonUoms.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setDState(() => uom = v!)),
              CheckboxListTile(title: const Text('Returnable Default', style: TextStyle(fontSize: 12)), value: ret, onChanged: (v) => setDState(() => ret = v ?? false)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                setState(() {
                  if (isEdit) { existingItem.name = n; existingItem.category = cat; existingItem.uom = uom; existingItem.isReturnableDefault = ret; existingItem.updatedAt = DateTime.now().toIso8601String(); }
                  else { catalog.add(CatalogItem(id: const Uuid().v4(), name: n, category: cat, uom: uom, isReturnableDefault: ret, updatedAt: DateTime.now().toIso8601String())); }
                });
                _saveData();
                _syncWithCloud(silent: true);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCatalogItem(CatalogItem item) async {
    if (!await _authenticateAction('Delete Item')) return;
    setState(() {
      catalog.removeWhere((i) => i.id == item.id);
      deletedItemIds.add(item.id);
      recycleBin.insert(0, TrashItem(id: item.id, type: 'ITEM', title: item.name, subtitle: 'Category: ${item.category} | UOM: ${item.uom}', deletedAt: DateTime.now().toIso8601String(), rawData: item.toMap()));
    });
    _saveData();
    _syncWithCloud(silent: true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item moved to Recycle Bin!')));
  }

  void _openStockAdjustDialog(CatalogItem item) async {
    if (!await _authenticateAction('Adjust Stock')) return;
    double curStock = _getItemCurrentStock(item.id);
    final qtyCtrl = TextEditingController(text: '1');
    bool isAdd = true;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Adjust: ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: $curStock ${item.uom}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                ChoiceChip(label: const Text('+ Add'), selected: isAdd, onSelected: (_) => setDState(() => isAdd = true)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('- Deduct'), selected: !isAdd, onSelected: (_) => setDState(() => isAdd = false)),
              ]),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: 'Qty (${item.uom})')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                double q = double.tryParse(qtyCtrl.text) ?? 0;
                if (q <= 0) return;
                setState(() {
                  transactions.add(StoreTx(id: const Uuid().v4(), type: 'ADJUST', itemId: item.id, itemName: item.name, category: item.category, uom: item.uom, qty: isAdd ? q : -q, date: DateFormat('yyyy-MM-dd').format(DateTime.now()), remarks: 'Manual Adjust', updatedAt: DateTime.now().toIso8601String()));
                });
                _saveData();
                _syncWithCloud(silent: true);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBalanceScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Physical Stock Balance', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                ElevatedButton.icon(icon: const Icon(Icons.table_chart, size: 14), label: const Text('Excel'), onPressed: () => _exportStockDoc(isPdf: false)),
                const SizedBox(width: 6),
                ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf, size: 14), label: const Text('PDF'), onPressed: () => _exportStockDoc(isPdf: true)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: catalog.length,
            itemBuilder: (ctx, idx) {
              final item = catalog[idx];
              final stock = _getItemCurrentStock(item.id);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: _cardTouchStyle(item.id),
                child: ListTile(
                  onTap: () => _toggleTouch(item.id),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(item.category),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$stock ${item.uom}', style: TextStyle(fontWeight: FontWeight.bold, color: stock > 0 ? Colors.green : Colors.red)),
                      IconButton(icon: const Icon(Icons.tune, size: 18), onPressed: () => _openStockAdjustDialog(item)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportStockDoc({required bool isPdf}) async {
    final dir = await _promptFolderSelection();
    if (dir == null) return;
    final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    if (!isPdf) {
      final StringBuffer csv = StringBuffer()..writeln('\uFEFFSAARI STORE - STOCK BALANCE')..writeln('Item,Category,Stock,UOM');
      for (var i in catalog) { csv.writeln('"${i.name}","${i.category}",${_getItemCurrentStock(i.id)},"${i.uom}"'); }
      final file = File('${dir.path}/Stock_$nowStr.csv');
      await file.writeAsString(csv.toString());
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Excel Saved'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
    } else {
      final StringBuffer html = StringBuffer()..writeln('<html><body style="font-family:sans-serif;padding:20px;"><h2>SAARI OIL FIELD SERVICES - STOCK BALANCE</h2><table border="1" cellpadding="6" style="border-collapse:collapse;width:100%;"><tr><th>Item</th><th>Category</th><th>Stock Balance</th><th>UOM</th></tr>');
      for (var i in catalog) { html.writeln('<tr><td>${i.name}</td><td>${i.category}</td><td>${_getItemCurrentStock(i.id)}</td><td>${i.uom}</td></tr>'); }
      html.writeln('</table><br><button onclick="window.print()">Print / Save PDF</button></body></html>');
      final file = File('${dir.path}/Stock_$nowStr.html');
      await file.writeAsString(html.toString());
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('PDF Saved'), content: SelectableText('Saved in:\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
    }
  }

  void _openRecycleBinScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (ctx, setTrashState) => Scaffold(
            appBar: AppBar(title: const Text('Recycle Bin (Restore/Delete)'), backgroundColor: const Color(0xFF0B2545), foregroundColor: Colors.white),
            body: recycleBin.isEmpty
                ? const Center(child: Text('Recycle Bin is Empty.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: recycleBin.length,
                    itemBuilder: (ctx, idx) {
                      final item = recycleBin[idx];
                      return Card(
                        child: ListTile(
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${item.subtitle}\nDeleted: ${item.deletedAt}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () {
                                  setState(() {
                                    recycleBin.removeWhere((t) => t.id == item.id);
                                    if (item.type == 'ITEM') { deletedItemIds.remove(item.id); catalog.add(CatalogItem.fromMap(item.rawData)); }
                                    if (item.type == 'JP') { deletedJpIds.remove(item.id); jpList.add(JpProfile.fromMap(item.rawData)); }
                                    if (item.type == 'REQUISITION') { deletedReqIds.remove(item.id); requisitions.add(MaterialRequisition.fromMap(item.rawData)); }
                                    if (item.type == 'TX') {
                                      deletedTxIds.remove(item.id);
                                      transactions.add(StoreTx.fromMap(item.rawData));
                                    }
                                  });
                                  _saveData();
                                  _syncWithCloud(silent: true);
                                  setTrashState(() {});
                                },
                                child: const Text('Restore', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                onPressed: () {
                                  setState(() => recycleBin.removeWhere((t) => t.id == item.id));
                                  _saveData();
                                  setTrashState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2545),
        foregroundColor: Colors.white,
        title: const Text('SAARI GENERAL STORE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.restore_from_trash), tooltip: 'Recycle Bin', onPressed: _openRecycleBinScreen),
          IconButton(icon: const Icon(Icons.cloud_sync), tooltip: 'Sync Cloud', onPressed: () => _syncWithCloud(silent: false)),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) async {
          if (i == 5 && !_isSettingsUnlocked) {
            if (await _authenticateAction('Open Settings')) {
              setState(() { _isSettingsUnlocked = true; _navIndex = i; });
            }
            return;
          }
          setState(() => _navIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.post_add), label: 'Requisitions'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'JPs'),
          NavigationDestination(icon: Icon(Icons.assignment_return), label: 'Returns/Alarms'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Store Items'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_navIndex == 0) return _buildDashboardScreen();
    if (_navIndex == 1) return _buildRequisitionsScreen();
    if (_navIndex == 2) return _buildJpScreen();
    if (_navIndex == 3) return _buildReturnsAndAlarmsScreen();
    if (_navIndex == 4) return DefaultTabController(length: 2, child: Scaffold(appBar: const TabBar(labelColor: Color(0xFF0B2545), tabs: [Tab(text: 'Catalog'), Tab(text: 'Stock Balance')]), body: TabBarView(children: [_buildCatalogScreen(), _buildStockBalanceScreen()])));
    return _buildSettingsScreen();
  }

  Widget _buildDashboardScreen() {
    final now = DateTime.now();
    final overdue = transactions.where((t) => t.isReturnable && !t.isReturned && t.type == 'ISSUE' && (DateTime.tryParse(t.returnDueDate)?.isBefore(now) ?? false)).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (overdue.isNotEmpty)
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.red, width: 1.5)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('⚠️ ${overdue.length} Items OVERDUE (Wapsi Ka Time Guzar Gaya!)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                const SizedBox(height: 4),
                ...overdue.take(3).map((t) => Text('• ${t.itemName} (${t.qty} ${t.uom})${t.serialNo.isNotEmpty ? " [Sr: ${t.serialNo}]" : ""} to ${t.jpName} - Due: ${t.returnDueDate}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
            ),
          ),
        Card(
          color: const Color(0xFF0B2545),
          child: Padding(padding: const EdgeInsets.all(14), child: Text('Total Catalog Items: ${catalog.length}\nTotal JPs Active: ${jpList.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 8),
        const Text('Recent Store Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        ...transactions.reversed.take(6).map((t) => Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: _cardTouchStyle(t.id),
          child: ListTile(
            onTap: () => _toggleTouch(t.id),
            leading: Icon(t.type == 'RECEIVE' ? Icons.arrow_downward : (t.type == 'RETURN' ? Icons.assignment_return : Icons.arrow_upward), color: t.type == 'RECEIVE' ? Colors.green : Colors.orange),
            title: Text('${t.itemName} - ${t.qty} ${t.uom}${t.serialNo.isNotEmpty ? " (Sr: ${t.serialNo})" : ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('Date: ${t.date} | ${t.type == "ISSUE" ? "JP: ${t.jpName}" : "Store"}'),
          ),
        )),
      ],
    );
  }

  void _openChangePinDialog() {
    final oCtrl = TextEditingController(), nCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Master PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current PIN')),
            const SizedBox(height: 6),
            TextField(controller: nCtrl, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2545)),
            onPressed: () {
              if (oCtrl.text.trim() == _securityPin.trim() && nCtrl.text.trim().isNotEmpty) {
                setState(() => _securityPin = nCtrl.text.trim());
                _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Changed!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current PIN ghalat hai!')));
              }
            },
            child: const Text('Save PIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    final urlCtrl = TextEditingController(text: _firebaseUrl);
    final keyCtrl = TextEditingController(text: _cloudStoreId);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Settings & Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.lock, color: Colors.red), onPressed: () => setState(() { _isSettingsUnlocked = false; _navIndex = 0; })),
          ],
        ),
        const SizedBox(height: 8),
        TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Firebase URL')),
        const SizedBox(height: 6),
        TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Branch Key')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2545)),
          onPressed: () {
            setState(() { _firebaseUrl = urlCtrl.text.trim(); _cloudStoreId = keyCtrl.text.trim(); });
            _saveData();
            _syncWithCloud(silent: false);
          },
          child: const Text('Save Firebase', style: TextStyle(color: Colors.white)),
        ),
        const Divider(height: 24),
        ListTile(
          title: const Text('Master PIN Security', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Current PIN: $_securityPin'),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2545)),
            onPressed: _openChangePinDialog,
            child: const Text('Change PIN', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
