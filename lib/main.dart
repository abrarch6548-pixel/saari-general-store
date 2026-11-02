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
  String id, type, itemId, itemName, category, uom, date, jpName, sourceOrPerson, returnDueDate, remarks, requisitionId, updatedAt;
  double qty;
  bool isReturnable, isReturned;
  StoreTx({required this.id, required this.type, required this.itemId, required this.itemName, required this.category, required this.uom, required this.qty, required this.date, this.jpName = '', this.sourceOrPerson = '', this.isReturnable = false, this.returnDueDate = '', this.isReturned = false, this.remarks = '', this.requisitionId = '', required this.updatedAt});
  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'itemId': itemId, 'itemName': itemName, 'category': category, 'uom': uom, 'qty': qty, 'date': date, 'jpName': jpName, 'sourceOrPerson': sourceOrPerson, 'isReturnable': isReturnable, 'returnDueDate': returnDueDate, 'isReturned': isReturned, 'remarks': remarks, 'requisitionId': requisitionId, 'updatedAt': updatedAt};
  factory StoreTx.fromMap(Map<String, dynamic> m) => StoreTx(id: m['id'] ?? '', type: m['type'] ?? 'RECEIVE', itemId: m['itemId'] ?? '', itemName: m['itemName'] ?? '', category: m['category'] ?? '', uom: m['uom'] ?? 'Pcs', qty: (m['qty'] as num?)?.toDouble() ?? 0.0, date: m['date'] ?? '', jpName: m['jpName'] ?? '', sourceOrPerson: m['sourceOrPerson'] ?? '', isReturnable: m['isReturnable'] ?? false, returnDueDate: m['returnDueDate'] ?? '', isReturned: m['isReturned'] ?? false, remarks: m['remarks'] ?? '', requisitionId: m['requisitionId'] ?? '', updatedAt: m['updatedAt'] ?? '');
}

class JpProfile {
  String id, name, location, updatedAt;
  JpProfile({required this.id, required this.name, this.location = '', required this.updatedAt});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'location': location, 'updatedAt': updatedAt};
  factory JpProfile.fromMap(Map<String, dynamic> m) => JpProfile(id: m['id'] ?? '', name: m['name'] ?? '', location: m['location'] ?? '', updatedAt: m['updatedAt'] ?? '');
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

  List<String> deletedItemIds = [], deletedJpIds = [], deletedTxIds = [], deletedReqIds = [];
  final List<String> commonUoms = ['Pcs', 'Mtr', 'Kg', 'Ltr', 'Box', 'Roll', 'Set', 'Pair', 'Drum', 'Can', 'Pkt', 'Bundle'];
  final List<String> commonCategories = ['General', 'Tools & Tackles', 'Safety & PPE', 'Electrical', 'Mechanical Spares', 'Welding Consumables'];

  String _securityPin = '1234', _firebaseUrl = '', _cloudStoreId = 'saari_general_store', _lastSyncStatus = 'Not Synced';
  bool _isSyncing = false, _isSettingsUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      if (_firebaseUrl.isNotEmpty) _syncWithCloud(silent: true);
    });
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
          if (data['deletedItemIds'] != null) deletedItemIds = List<String>.from(data['deletedItemIds']);
          if (data['deletedJpIds'] != null) deletedJpIds = List<String>.from(data['deletedJpIds']);
          if (data['deletedTxIds'] != null) deletedTxIds = List<String>.from(data['deletedTxIds']);
          if (data['deletedReqIds'] != null) deletedReqIds = List<String>.from(data['deletedReqIds']);
          if (data['securityPin'] != null) _securityPin = data['securityPin'].toString();
          if (data['firebaseUrl'] != null) _firebaseUrl = data['firebaseUrl'].toString();
          if (data['cloudStoreId'] != null) _cloudStoreId = data['cloudStoreId'].toString();
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
        if (t.type == 'RECEIVE' || t.type == 'RETURN') stock += t.qty;
        if (t.type == 'ISSUE') stock -= t.qty;
      }
    }
    return stock;
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

          final localCatMap = {for (var i in catalog) i.id: i};
          localCatMap.removeWhere((id, _) => deletedItemIds.contains(id));
          for (var r in (remote['catalog'] as List? ?? [])) {
            final item = CatalogItem.fromMap(r);
            if (!deletedItemIds.contains(item.id)) localCatMap[item.id] = item;
          }

          final localJpMap = {for (var j in jpList) j.id: j};
          localJpMap.removeWhere((id, _) => deletedJpIds.contains(id));
          for (var r in (remote['jpList'] as List? ?? [])) {
            final jp = JpProfile.fromMap(r);
            if (!deletedJpIds.contains(jp.id)) localJpMap[jp.id] = jp;
          }

          final localTxMap = {for (var t in transactions) t.id: t};
          localTxMap.removeWhere((id, _) => deletedTxIds.contains(id));
          for (var r in (remote['transactions'] as List? ?? [])) {
            final tx = StoreTx.fromMap(r);
            if (!deletedTxIds.contains(tx.id)) localTxMap[tx.id] = tx;
          }

          final localReqMap = {for (var q in requisitions) q.id: q};
          localReqMap.removeWhere((id, _) => deletedReqIds.contains(id));
          for (var r in (remote['requisitions'] as List? ?? [])) {
            final req = MaterialRequisition.fromMap(r);
            if (!deletedReqIds.contains(req.id)) localReqMap[req.id] = req;
          }

          if (mounted) {
            setState(() {
              catalog = localCatMap.values.toList();
              jpList = localJpMap.values.toList();
              transactions = localTxMap.values.toList();
              requisitions = localReqMap.values.toList();
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
        return AlertDialog(
          title: Text('PIN - $title', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Master PIN'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, pinCtrl.text.trim() == _securityPin.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return pinResult ?? false;
  }

  void _openRequisitionDialog() async {
    final targetCtrl = TextEditingController(text: 'Main Warehouse / Store 1');
    final Map<String, bool> checkedMap = {for (var i in catalog) i.id: false};
    final Map<String, TextEditingController> qtyCtrls = {for (var i in catalog) i.id: TextEditingController(text: '1')};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('New Material Requisition', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            height: 400,
            child: Column(
              children: [
                TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'Target Store *')),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: catalog.length,
                    itemBuilder: (ctx, idx) {
                      final item = catalog[idx];
                      final isChecked = checkedMap[item.id] ?? false;
                      final ctrl = qtyCtrls[item.id]!;
                      final stock = _getItemCurrentStock(item.id);

                      return ListTile(
                        leading: Checkbox(
                          value: isChecked,
                          onChanged: (v) => setDState(() => checkedMap[item.id] = v ?? false),
                        ),
                        title: Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text('In-Store: $stock ${item.uom}', style: const TextStyle(fontSize: 10)),
                        trailing: isChecked
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                                    onPressed: () {
                                      double q = double.tryParse(ctrl.text) ?? 1;
                                      if (q > 1) {
                                        ctrl.text = (q - 1).toStringAsFixed(0);
                                        setDState(() {});
                                      }
                                    },
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.zero),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 18),
                                    onPressed: () {
                                      double q = double.tryParse(ctrl.text) ?? 0;
                                      ctrl.text = (q + 1).toStringAsFixed(0);
                                      setDState(() {});
                                    },
                                  ),
                                ],
                              )
                            : null,
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
              onPressed: () {
                final List<RequisitionLine> lines = [];
                for (var item in catalog) {
                  if (checkedMap[item.id] == true) {
                    double q = double.tryParse(qtyCtrls[item.id]?.text ?? '0') ?? 0;
                    if (q > 0) {
                      lines.add(RequisitionLine(
                        itemId: item.id,
                        itemName: item.name,
                        uom: item.uom,
                        prevStock: _getItemCurrentStock(item.id),
                        reqQty: q,
                      ));
                    }
                  }
                }
                if (lines.isEmpty) return;

                setState(() {
                  requisitions.add(MaterialRequisition(
                    id: const Uuid().v4(),
                    reqNo: 'REQ-${DateFormat('yyMMdd').format(DateTime.now())}-${requisitions.length + 1}',
                    date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    targetStore: targetCtrl.text.trim(),
                    items: lines,
                    updatedAt: DateTime.now().toIso8601String(),
                  ));
                });
                _saveData();
                _syncWithCloud(silent: true);
                Navigator.pop(ctx);
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _openIssueToJpDialog(JpProfile jp) async {
    final Map<String, bool> checkedMap = {for (var i in catalog) i.id: false};
    final Map<String, TextEditingController> qtyCtrls = {for (var i in catalog) i.id: TextEditingController(text: '1')};
    final Map<String, bool> retMap = {for (var i in catalog) i.id: i.isReturnableDefault};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('Issue to ${jp.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            height: 400,
            child: ListView.builder(
              itemCount: catalog.length,
              itemBuilder: (ctx, idx) {
                final item = catalog[idx];
                final isChecked = checkedMap[item.id] ?? false;
                final ctrl = qtyCtrls[item.id]!;
                final stock = _getItemCurrentStock(item.id);

                return Column(
                  children: [
                    ListTile(
                      leading: Checkbox(
                        value: isChecked,
                        onChanged: (v) => setDState(() => checkedMap[item.id] = v ?? false),
                      ),
                      title: Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text('Available: $stock ${item.uom}', style: TextStyle(color: stock > 0 ? Colors.green : Colors.red, fontSize: 10)),
                      trailing: isChecked
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                                  onPressed: () {
                                    double q = double.tryParse(ctrl.text) ?? 1;
                                    if (q > 1) {
                                      ctrl.text = (q - 1).toStringAsFixed(0);
                                      setDState(() {});
                                    }
                                  },
                                ),
                                SizedBox(
                                  width: 40,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(contentPadding: EdgeInsets.zero),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 18),
                                  onPressed: () {
                                    double q = double.tryParse(ctrl.text) ?? 0;
                                    ctrl.text = (q + 1).toStringAsFixed(0);
                                    setDState(() {});
                                  },
                                ),
                              ],
                            )
                          : null,
                    ),
                    if (isChecked)
                      Padding(
                        padding: const EdgeInsets.only(left: 45),
                        child: Row(
                          children: [
                            Checkbox(
                              value: retMap[item.id] ?? false,
                              onChanged: (v) => setDState(() => retMap[item.id] = v ?? false),
                            ),
                            const Text('Returnable (Wapsi Hoga)', style: TextStyle(fontSize: 11, color: Colors.teal)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final List<StoreTx> newIssues = [];
                for (var item in catalog) {
                  if (checkedMap[item.id] == true) {
                    double q = double.tryParse(qtyCtrls[item.id]?.text ?? '0') ?? 0;
                    if (q > 0) {
                      newIssues.add(StoreTx(
                        id: const Uuid().v4(),
                        type: 'ISSUE',
                        itemId: item.id,
                        itemName: item.name,
                        category: item.category,
                        uom: item.uom,
                        qty: q,
                        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        jpName: jp.name,
                        isReturnable: retMap[item.id] ?? false,
                        returnDueDate: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7))),
                        updatedAt: DateTime.now().toIso8601String(),
                      ));
                    }
                  }
                }
                if (newIssues.isEmpty) return;
                if (!await _authenticateAction('Issue Material')) return;

                setState(() => transactions.addAll(newIssues));
                _saveData();
                _syncWithCloud(silent: true);
                Navigator.pop(ctx);
              },
              child: const Text('Confirm Issue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialHeader() {
    return const Row(
      children: [
        Icon(Icons.inventory, color: Color(0xFFF25F22)),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SAARI OIL FIELD SERVICES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('GENERAL STORE & LOGISTICS', style: TextStyle(fontSize: 9, color: Color(0xFFF25F22), fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2545),
        title: _buildOfficialHeader(),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync, color: Colors.white),
            onPressed: () => _syncWithCloud(silent: false),
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) async {
          if (i == 4 && !_isSettingsUnlocked) {
            if (await _authenticateAction('Open Settings')) {
              setState(() {
                _isSettingsUnlocked = true;
                _navIndex = i;
              });
            }
            return;
          }
          setState(() => _navIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.post_add), label: 'Requisitions'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'JPs'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_navIndex == 0) return _buildDashboardScreen();
    if (_navIndex == 1) return _buildRequisitionsScreen();
    if (_navIndex == 2) return _buildJpScreen();
    if (_navIndex == 3) return _buildCatalogScreen();
    return _buildSettingsScreen();
  }

  Widget _buildDashboardScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: const Color(0xFF0B2545),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Items Configured in Store', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                Text('${catalog.length} Items Active', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Recent Material Issues', style: TextStyle(fontWeight: FontWeight.bold)),
        ...transactions.reversed.take(6).map((t) => ListTile(
          leading: const Icon(Icons.arrow_upward, color: Colors.orange),
          title: Text('${t.itemName} - ${t.qty} ${t.uom}'),
          subtitle: Text('JP: ${t.jpName} | Date: ${t.date}'),
        )),
      ],
    );
  }

  Widget _buildRequisitionsScreen() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openRequisitionDialog,
        child: const Icon(Icons.add),
      ),
      body: requisitions.isEmpty
          ? const Center(child: Text('No Requisitions Created'))
          : ListView.builder(
              itemCount: requisitions.length,
              itemBuilder: (ctx, idx) {
                final r = requisitions[idx];
                return ListTile(
                  title: Text(r.reqNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Target: ${r.targetStore} | Date: ${r.date}'),
                );
              },
            ),
    );
  }

  Widget _buildJpScreen() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final c = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add JP'),
              content: TextField(controller: c, decoration: const InputDecoration(labelText: 'JP Name')),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (c.text.trim().isNotEmpty) {
                      setState(() {
                        jpList.add(JpProfile(id: const Uuid().v4(), name: c.text.trim(), updatedAt: DateTime.now().toIso8601String()));
                      });
                      _saveData();
                      _syncWithCloud(silent: true);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: jpList.length,
        itemBuilder: (ctx, idx) {
          final jp = jpList[idx];
          return ListTile(
            title: Text(jp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Location: ${jp.location}'),
            trailing: ElevatedButton(
              onPressed: () => _openIssueToJpDialog(jp),
              child: const Text('Issue Material'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogScreen() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final n = TextEditingController();
          String u = 'Pcs';
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setS) => AlertDialog(
                title: const Text('Add Catalog Item'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: n, decoration: const InputDecoration(labelText: 'Item Name')),
                    DropdownButton<String>(
                      value: u,
                      items: commonUoms.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                      onChanged: (v) => setS(() => u = v!),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      if (n.text.trim().isNotEmpty) {
                        setState(() {
                          catalog.add(CatalogItem(id: const Uuid().v4(), name: n.text.trim(), category: 'General', uom: u, updatedAt: DateTime.now().toIso8601String()));
                        });
                        _saveData();
                        _syncWithCloud(silent: true);
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: catalog.length,
        itemBuilder: (ctx, idx) {
          final i = catalog[idx];
          return ListTile(
            title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('In-Stock: ${_getItemCurrentStock(i.id)} ${i.uom}'),
          );
        },
      ),
    );
  }

  Widget _buildSettingsScreen() {
    final urlCtrl = TextEditingController(text: _firebaseUrl);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Firebase URL')),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            setState(() => _firebaseUrl = urlCtrl.text.trim());
            _saveData();
            _syncWithCloud(silent: false);
          },
          child: const Text('Connect Firebase'),
        ),
      ],
    );
  }
}
