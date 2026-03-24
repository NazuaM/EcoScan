import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'tutorial_screen.dart';
import 'swap_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _imageBytes;
  Map<String, dynamic>? _data;
  bool _isLoading = false;

  // ⚠️ Change to your laptop's local IP when testing on phone
  final String backendUrl = "http://127.0.0.1:8000/analyze";
  String get baseUrl => backendUrl.replaceAll('/analyze', '');

  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isGuest => currentUser?.isAnonymous ?? true;

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

  Color get resultColor =>
      isRecyclable ? const Color(0xFF2E7D32) : Colors.red[700]!;

  // ── FIRESTORE POINTS ────────────────────────
  Future<void> _addPoints(int pts, String reason) async {
    if (isGuest) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid);
    await ref.update({
      'score': FieldValue.increment(pts),
      'scans': FieldValue.increment(1),
      'lastScan': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Text("🌱 "),
          Text("+$pts pts  •  $reason",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── IMAGE PICKER ────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1024);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _data = null;
      });
      _uploadImage(picked);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text("How do you want to scan?",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _sourceButton(
                icon: Icons.camera_alt_rounded,
                label: "Camera",
                color: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _sourceButton(
                icon: Icons.photo_library_rounded,
                label: "Gallery",
                color: const Color(0xFF00897B),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── UPLOAD ──────────────────────────────────
  Future<void> _uploadImage(XFile file) async {
    setState(() => _isLoading = true);
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(http.MultipartFile.fromBytes(
          'file', await file.readAsBytes(),
          filename: 'upload.jpg'));
      var response =
          await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() => _data = jsonResponse);
        if (needsConfirmation) {
          await _showConfirmationDialog();
        } else {
          if (isRecyclable) {
            await _addPoints(10, "Recyclable item scanned!");
          }
        }
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Cannot connect to server.\n$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── CONFIDENCE DIALOG ───────────────────────
  Future<void> _showConfirmationDialog() async {
    final materialOptions = [
      safeValue('material'),
      'Plastic', 'Glass', 'Metal', 'Paper',
      'Cardboard', 'Wood', 'Fabric', 'Electronics', 'Rubber', 'Other',
    ];
    String selectedMaterial = safeValue('material');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle),
              child: Icon(Icons.help_outline,
                  color: Colors.orange[700]),
            ),
            const SizedBox(width: 10),
            const Expanded(
                child: Text("Quick Check",
                    style: TextStyle(fontSize: 17))),
          ]),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'I detected "${safeValue('item_name')}" but I\'m not 100% sure. Can you confirm the material?',
                    style: TextStyle(
                        color: Colors.orange[900], fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMaterial,
                      isExpanded: true,
                      items: materialOptions
                          .toSet()
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setD(() => selectedMaterial = val);
                        }
                      },
                    ),
                  ),
                ),
              ]),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(
                    () => _data!['confidence'] = 'Confirmed');
                if (isRecyclable) {
                  _addPoints(10, "Recyclable item scanned!");
                }
              },
              child: Text("Looks right",
                  style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _data!['material'] = selectedMaterial;
                  _data!['confidence'] = 'User Confirmed';
                  final m = selectedMaterial.toLowerCase();
                  _data!['recyclable'] = ![
                    'food', 'organic', 'other'
                  ].any((x) => m.contains(x));
                });
                if (isRecyclable) {
                  _addPoints(10, "Recyclable item scanned!");
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: Colors.red[700]));
  }

  // ── NAVIGATION ──────────────────────────────
  void _openTutorial() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorialScreen(
            itemName: safeValue('item_name'),
            material: safeValue('material'),
            state: safeValue('state'),
            quality: safeValue('quality'),
            backendUrl: backendUrl,
            unsplashUrl: 'https://api.unsplash.com/search/photos',
            onTutorialCompleted: () =>
                _addPoints(20, "DIY tutorial completed!"),
          ),
        ));
  }

  void _openSwap() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SwapScreen(
            initialItem: safeValue('item_name'),
            backendUrl: backendUrl,
          ),
        ));
  }

  void _openProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // ── RECYCLING CENTERS ───────────────────────
  Future<void> _showLocations() async {
    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    if (position.latitude == 0 && position.longitude == 0) {
      _showError("Could not detect location.");
      return;
    }

    String category =
        safeValue('material_category').toLowerCase();
    String rawMaterial = safeValue('material').toLowerCase();
    String itemName = safeValue('item_name').toLowerCase();

    String jsonString = await rootBundle
        .loadString('assets/uae_recycling_centers.json');
    List<dynamic> allCenters = json.decode(jsonString);

    final Map<String, List<String>> kwMap = {
      'metal': ['metal', 'aluminum', 'steel', 'tin', 'copper', 'iron', 'scrap', 'can', 'cans', 'metallic'],
      'plastic': ['plastic', 'bottle', 'bottles', 'pvc', 'jug', 'pet', 'foam', 'bags'],
      'paper': ['paper', 'cardboard', 'carton', 'newspaper', 'books'],
      'glass': ['glass', 'bottle', 'bottles'],
      'electronics': ['electronics', 'e-waste', 'electronic', 'computer', 'phone', 'battery', 'batteries', 'cable', 'lamps'],
      'furniture': ['furniture', 'sofa', 'chair', 'table', 'bed', 'bulk', 'sofas'],
      'medication': ['medication', 'medicine', 'hazardous', 'expired', 'medicines'],
      'textiles': ['textiles', 'clothing', 'fabric', 'cloth', 'textile', 'leather'],
      'wood': ['wood', 'timber', 'wooden'],
      'general_waste': ['general', 'waste', 'organic', 'compost'],
      'rubber': ['rubber'],
      'other': ['general recyclables', 'plastic', 'paper', 'metal'],
    };

    List<String> terms = [category, rawMaterial];
    for (var e in kwMap.entries) {
      if (category.contains(e.key) ||
          rawMaterial.contains(e.key)) {
        terms.addAll(e.value);
      }
    }
    terms.addAll(rawMaterial.split(' '));
    terms.addAll(itemName.split(' '));
    terms = terms
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.length > 2)
        .toList();

    List<Map<String, dynamic>> validCenters = [];
    for (var center in allCenters) {
      List<dynamic> mats = center['materials'];
      bool accepts = mats.any((m) {
        final cm = m.toString().toLowerCase();
        return terms
            .any((t) => cm.contains(t) || t.contains(cm));
      });
      if (!accepts) {
        accepts = mats.any((m) =>
            m.toString().toLowerCase().contains('general'));
      }
      if (!accepts) continue;

      final double lat = (center['lat'] as num).toDouble();
      final double lon = (center['lon'] as num).toDouble();
      if (lat < 22 || lat > 27 || lon < 51 || lon > 57) continue;

      double dist = _haversine(
          position.latitude, position.longitude, lat, lon);
      if (dist <= 50) {
        validCenters.add({
          "name": center['name'],
          "city": center['city'],
          "type": center['type'] ?? "Recycling Center",
          "access": center['access'],
          "dist": dist,
          "url": center['url'] ?? "",
        });
      }
    }

    validCenters
        .sort((a, b) => a['dist'].compareTo(b['dist']));
    if (validCenters.length > 5) {
      validCenters = validCenters.sublist(0, 5);
    }
    _showCentersSheet(validCenters, rawMaterial);
  }

  double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _launchUrl(String? link) async {
    if (link == null || link.isEmpty) return;
    await launchUrl(Uri.parse(link),
        mode: LaunchMode.externalApplication);
  }

  void _showCentersSheet(
      List<Map<String, dynamic>> centers, String material) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("♻️ Nearby for $material",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${centers.length} center(s) within 50km",
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 13)),
              const Divider(height: 20),
              if (centers.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                        "No compatible centers found nearby"))
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: centers.length,
                    itemBuilder: (ctx, i) {
                      final c = centers[i];
                      final is247 = c['access']
                          .toString()
                          .contains("24/7");
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius:
                                BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: const Icon(Icons.recycling,
                                color: Color(0xFF2E7D32)),
                          ),
                          title: Row(children: [
                            Expanded(
                                child: Text(c['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13))),
                            if (is247)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: const Text("24/7",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32))),
                              ),
                          ]),
                          subtitle: Text(
                              "${c['type']} • ${(c['dist'] as double).toStringAsFixed(1)} km",
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12)),
                          trailing: IconButton(
                              icon: const Icon(
                                  Icons.directions_rounded,
                                  color: Color(0xFF1565C0)),
                              onPressed: () =>
                                  _launchUrl(c['url'])),
                          onTap: () => _launchUrl(c['url']),
                        ),
                      );
                    },
                  ),
                ),
            ]),
      ),
    );
  }

  // ── MAIN UI ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(children: [
                const Text("EcoScan ♻️",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white)),
                const Spacer(),
                if (!isGuest)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .snapshots(),
                    builder: (ctx, snap) {
                      final userData =
                        snap.data?.data() as Map<String, dynamic>?;
                      final score =
                        (userData?['score'] as num?)?.toInt() ?? 0;
                      return GestureDetector(
                        onTap: _openProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: Text("🌱 $score pts",
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      );
                    },
                  )
                else
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text("👤 Guest",
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70)),
                    ),
                  ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Scanned image
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(children: [
                        Image.memory(_imageBytes!,
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover),
                        if (_data != null)
                          Positioned(
                            top: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: resultColor.withOpacity(0.9),
                                  borderRadius:
                                      BorderRadius.circular(20)),
                              child: Text(
                                  isRecyclable
                                      ? "♻️ Recyclable"
                                      : "🚫 Not Recyclable",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Loading
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Column(children: [
                        CircularProgressIndicator(
                            color: Color(0xFF2E7D32)),
                        SizedBox(height: 16),
                        Text("Analyzing your item...",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        Text("Identifying material & recyclability",
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ]),
                    ),

                  // Result card
                  if (_data != null && !_isLoading) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: resultColor.withOpacity(0.3),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: resultColor.withOpacity(0.06),
                              blurRadius: 15)
                        ],
                      ),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: resultColor.withOpacity(0.08),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      resultColor.withOpacity(0.15),
                                  shape: BoxShape.circle),
                              child: Icon(
                                  isRecyclable
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: resultColor,
                                  size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(safeValue('item_name'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17)),
                                  Text(
                                      isRecyclable
                                          ? "This item is recyclable ✅"
                                          : "This item is not recyclable ❌",
                                      style: TextStyle(
                                          color: resultColor,
                                          fontSize: 13)),
                                ])),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _detailRow("🧪 Material",
                                safeValue('material')),
                            _detailRow(
                                "📦 State", safeValue('state')),
                            _detailRow(
                                "⭐ Quality", safeValue('quality')),
                            _detailRow("🔢 Quantity",
                                safeValue('quantity')),
                            _detailRow("🎯 Confidence",
                                safeValue('confidence')),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color:
                                      resultColor.withOpacity(0.07),
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(Icons.lightbulb_outline,
                                    color: resultColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(safeValue('action'),
                                        style: TextStyle(
                                            color: resultColor,
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 13))),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  if (!_isLoading) ...[
                    _actionButton(
                      icon: Icons.document_scanner_rounded,
                      label: _data == null
                          ? "Scan an Object"
                          : "Scan Another Object",
                      color: const Color(0xFF2E7D32),
                      onTap: _showImageSourceSheet,
                    ),
                    if (_data != null &&
                        (isUpcyclable || isRecyclable)) ...[
                      const SizedBox(height: 10),
                      _actionButton(
                        icon: Icons.auto_awesome_rounded,
                        label: "Get DIY Upcycling Tutorial",
                        color: Colors.orange[700]!,
                        onTap: _openTutorial,
                      ),
                    ],
                    if (_data != null) ...[
                      const SizedBox(height: 10),
                      _actionButton(
                        icon: Icons.swap_horiz_rounded,
                        label: "Find Eco-Friendly Alternatives",
                        color: const Color(0xFF00897B),
                        onTap: _openSwap,
                      ),
                    ],
                    if (_data != null) ...[
                      const SizedBox(height: 10),
                      _actionButton(
                        icon: Icons.location_on_rounded,
                        label: isRecyclable
                            ? "Find Nearby Recycling Centers"
                            : "Find Nearby Disposal & Recycling Centers",
                        color: const Color(0xFF1565C0),
                        onTap: _showLocations,
                      ),
                    ],
                  ],

                  // Empty state
                  if (_imageBytes == null && !_isLoading) ...[
                    const SizedBox(height: 40),
                    _emptyState(),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value == "Unknown") return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 115,
                child: Text(label,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13))),
          ]),
    );
  }

  Widget _emptyState() {
    return Column(children: [
      Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.green.shade100, width: 2)),
        child: const Center(
            child: Text("♻️", style: TextStyle(fontSize: 52))),
      ),
      const SizedBox(height: 20),
      const Text("Ready to scan!",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        "Point your camera at any waste item.\nGet recycling tips, DIY ideas & nearby centers.",
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.grey[500], fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 24),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _featurePill("🔍 AI Detection"),
            _featurePill("🛠️ DIY Tutorials"),
            _featurePill("🌿 Eco Swaps"),
            _featurePill("📍 Find Centers"),
          ]),
    ]);
  }

  Widget _featurePill(String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4)
          ]),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.green[800],
              fontWeight: FontWeight.w500)),
    );
  }
}