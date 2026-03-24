import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'tutorial_screen.dart';
import 'swap_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EcoScanApp());
}

class EcoScanApp extends StatelessWidget {
  const EcoScanApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF00897B),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
 
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class RecyclingScreen extends StatefulWidget {
  const RecyclingScreen({super.key});
  @override
  State<RecyclingScreen> createState() => _RecyclingScreenState();
}

class _RecyclingScreenState extends State<RecyclingScreen> {
  Uint8List? _imageBytes;
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  int _score = 0;

  final String backendUrl = "http://127.0.0.1:8000/analyze";
  String get baseUrl => backendUrl.replaceAll('/analyze', '');

  String safeValue(String key) {
    if (_data == null || _data![key] == null) return "Unknown";
    return _data![key].toString();
  }

  bool get isRecyclable {
    if (_data == null || _data!['recyclable'] == null) return false;
    return _data!['recyclable'] == true;
  }

  bool get isUpcyclable {
    if (_data == null || _data!['upcyclable'] == null) return false;
    return _data!['upcyclable'] == true;
  }

  bool get needsConfirmation {
    final c = safeValue('confidence').toLowerCase();
    return c == 'medium' || c == 'low';
  }

  Color get resultColor => isRecyclable ? Colors.green : Colors.red;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _imageBytes = bytes; _data = null; });
      _uploadImage(picked);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Scan an Object", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text("Take a Photo"),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text("Choose from Gallery"),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _uploadImage(XFile file) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(http.MultipartFile.fromBytes('file', await file.readAsBytes(), filename: 'upload.jpg'));
      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() => _data = jsonResponse);
        if (needsConfirmation) {
          await _showConfirmationDialog();
        } else {
          if (isRecyclable) setState(() => _score += 10);
        }
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Cannot connect to server. Is the backend running?\n$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfirmationDialog() async {
    final List<String> materialOptions = [
      safeValue('material'),
      'Plastic', 'Glass', 'Metal', 'Paper', 'Cardboard',
      'Wood', 'Fabric', 'Electronics', 'Rubber', 'Other',
    ];
    String selectedMaterial = safeValue('material');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.help_outline, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Expanded(child: Text("Please Confirm", style: TextStyle(fontSize: 17))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I detected "${safeValue('item_name')}" but I\'m not fully confident. Please confirm the material.',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text("What material is this?", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMaterial,
                    isExpanded: true,
                    items: materialOptions.toSet().map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) { if (val != null) setDialogState(() => selectedMaterial = val); },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() { _data!['confidence'] = 'Confirmed'; if (isRecyclable) _score += 10; });
              },
              child: const Text("Looks right"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _data!['material'] = selectedMaterial;
                  _data!['confidence'] = 'User Confirmed';
                  final m = selectedMaterial.toLowerCase();
                  final nonRecyclable = ['food', 'organic', 'other'];
                  _data!['recyclable'] = !nonRecyclable.any((x) => m.contains(x));
                  if (isRecyclable) _score += 10;
                });
              },
              child: const Text("Update Material"),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  void _openTutorial() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TutorialScreen(
      itemName: safeValue('item_name'),
      material: safeValue('material'),
      state: "Used", 
      quality: "Good",
      backendUrl: "http://127.0.0.1:8000/analyze", // Your API base
      unsplashUrl: "https://api.unsplash.com/search/photos", // Add this line!
    )));
  }

  void _openSwapScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SwapScreen(
      initialItem: safeValue('item_name'), backendUrl: backendUrl,
    )));
  }

  Future<void> _showLocations() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    if (position.latitude == 0 && position.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not detect location.")));
      return;
    }

    String category = safeValue('material_category').toLowerCase();
    String rawMaterial = safeValue('material').toLowerCase();
    String itemName = safeValue('item_name').toLowerCase();

    String jsonString = await rootBundle.loadString('assets/uae_recycling_centers.json');
    List<dynamic> allCenters = json.decode(jsonString);
    List<Map<String, dynamic>> validCenters = [];

    // Expanded keyword map — this is the fix
    final Map<String, List<String>> materialKeywords = {
      'metal':         ['metal', 'aluminum', 'steel', 'tin', 'copper', 'iron', 'scrap', 'can', 'cans', 'metallic'],
      'plastic':       ['plastic', 'bottle', 'bottles', 'pvc', 'jug', 'pet', 'foam', 'bags'],
      'paper':         ['paper', 'cardboard', 'carton', 'newspaper', 'books'],
      'glass':         ['glass', 'bottle', 'bottles'],
      'electronics':   ['electronics', 'e-waste', 'electronic', 'computer', 'phone', 'battery', 'batteries', 'cable', 'it assets', 'computers', 'lamps'],
      'furniture':     ['furniture', 'sofa', 'chair', 'table', 'bed', 'bulk', 'sofas'],
      'medication':    ['medication', 'medicine', 'hazardous', 'expired', 'medicines'],
      'textiles':      ['textiles', 'clothing', 'fabric', 'cloth', 'textile', 'leather'],
      'wood':          ['wood', 'timber', 'wooden'],
      'general_waste': ['general', 'waste', 'organic', 'compost'],
      'other':         ['general recyclables', 'plastic', 'paper', 'metal'],
      'rubber':        ['rubber'],
    };

    List<String> expandedTerms = [category, rawMaterial];
    for (var entry in materialKeywords.entries) {
      if (category.contains(entry.key) || rawMaterial.contains(entry.key)) {
        expandedTerms.addAll(entry.value);
      }
    }
    expandedTerms.addAll(rawMaterial.split(' '));
    expandedTerms.addAll(itemName.split(' '));
    expandedTerms = expandedTerms.map((e) => e.trim().toLowerCase()).where((e) => e.length > 2).toList();

    for (var center in allCenters) {
      List<dynamic> materials = center['materials'];
      bool accepts = materials.any((m) {
        final cm = m.toString().toLowerCase();
        return expandedTerms.any((term) => cm.contains(term) || term.contains(cm));
      });
      // Fallback: "general recyclables" centers accept most things
      if (!accepts) {
        accepts = materials.any((m) => m.toString().toLowerCase().contains('general'));
      }
      if (!accepts) continue;

      final double centerLat = (center['lat'] as num).toDouble();
      final double centerLon = (center['lon'] as num).toDouble();
      if (centerLat < 22 || centerLat > 27 || centerLon < 51 || centerLon > 57) continue;

      double dist = _calculateDistance(position.latitude, position.longitude, centerLat, centerLon);
      if (dist <= 50) {
        validCenters.add({
          "name": center['name'], "city": center['city'],
          "type": center['type'] ?? "Recycling Center",
          "access": center['access'], "dist": dist, "url": center['url'] ?? "",
        });
      }
    }

    validCenters.sort((a, b) => a['dist'].compareTo(b['dist']));
    if (validCenters.length > 5) validCenters = validCenters.sublist(0, 5);
    _displayCentersSheet(validCenters, rawMaterial);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  Future<void> _launchMapUrl(String? link) async {
    if (link == null || link.isEmpty) return;
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  void _displayCentersSheet(List<Map<String, dynamic>> centers, String material) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nearby centers for $material", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (centers.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text("No compatible centers found within 50km"))
            else SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: centers.length,
                itemBuilder: (context, index) {
                  var c = centers[index];
                  bool is247 = c['access'].toString().contains("24/7");
                  return ListTile(
                    leading: const Icon(Icons.recycling, color: Colors.green),
                    title: Row(children: [
                      Expanded(child: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (is247) Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                        child: const Text("24/7", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                    ]),
                    subtitle: Text("${c['type']} • ${c['dist'].toStringAsFixed(1)} km"),
                    trailing: IconButton(icon: const Icon(Icons.directions, color: Colors.blue), onPressed: () => _launchMapUrl(c['url'])),
                    onTap: () => _launchMapUrl(c['url']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("EcoScan ♻️", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text("🌱 $_score pts", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imageBytes != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover)),
              const SizedBox(height: 16),
            ],
            if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 12),
              Text("Analyzing your item...", style: TextStyle(color: Colors.grey)),
            ]))),
            if (_data != null && !_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: resultColor.withOpacity(0.4), width: 2),
                  boxShadow: [BoxShadow(color: resultColor.withOpacity(0.08), blurRadius: 12)],
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(isRecyclable ? Icons.check_circle : Icons.cancel, color: resultColor, size: 36),
                    const SizedBox(width: 10),
                    Text(isRecyclable ? "Recyclable ✅" : "Not Recyclable ❌",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: resultColor)),
                  ]),
                  const Divider(height: 24),
                  _detailRow("🏷️ Item", safeValue('item_name')),
                  _detailRow("🧪 Material", safeValue('material')),
                  _detailRow("📦 State", safeValue('state')),
                  _detailRow("⭐ Quality", safeValue('quality')),
                  _detailRow("🔢 Quantity", safeValue('quantity')),
                  _detailRow("🎯 Confidence", safeValue('confidence')),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: resultColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.tips_and_updates, color: resultColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(safeValue('action'), style: TextStyle(color: resultColor, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (!_isLoading) ...[
              ElevatedButton.icon(
                onPressed: _showImageSourceSheet,
                icon: const Icon(Icons.document_scanner),
                label: Text(_data == null ? "Scan an Object" : "Scan Another Object"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (_data != null && (isUpcyclable || isRecyclable)) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _openTutorial, icon: const Icon(Icons.auto_awesome),
                  label: const Text("Get DIY Upcycling Tutorial"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
              if (_data != null) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _openSwapScreen, icon: const Icon(Icons.swap_horiz),
                  label: const Text("Find Eco-Friendly Alternatives"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
              if (_data != null) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _showLocations, icon: const Icon(Icons.location_on),
                  label: Text(isRecyclable
                      ? "Find Nearby Recycling Centers"
                      : "Find Nearby Disposal & Recycling Centers"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
            if (_imageBytes == null && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(children: [
                  Icon(Icons.recycling, size: 80, color: Colors.green[200]),
                  const SizedBox(height: 16),
                  Text("Tap 'Scan an Object' to get started", textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Identify materials, get upcycling ideas,\nand find recycling centers near you",
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value == "Unknown") return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}
