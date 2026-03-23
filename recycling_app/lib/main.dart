import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RecyclingScreen(),
  ));
}

class RecyclingScreen extends StatefulWidget {
  const RecyclingScreen({super.key});

  @override
  State<RecyclingScreen> createState() => _RecyclingScreenState();
}

class _RecyclingScreenState extends State<RecyclingScreen> {
  Uint8List? _webImage;
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  int _score = 0;

  // Replace with your actual backend URL if running locally
  final String backendUrl = "http://127.0.0.1:8000/analyze";

  // ---------------- SAFETY HELPERS ----------------
  String safeValue(String key) {
    if (_data == null || _data![key] == null) return "Unknown";
    return _data![key].toString();
  }

  bool get isRecyclable {
    if (_data == null || _data!['recyclable'] == null) return false;
    return _data!['recyclable'] == true;
  }

  // ---------------- LOCATION LOGIC ----------------
  Future<void> _showLocations() async {
    // 1. Get User Location
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();

    // ---------------- NEW SAFETY CHECK ----------------
    // If the browser returns 0,0 (Atlantic Ocean), warn the user
    if (position.latitude == 0 && position.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not detect location. Check GPS settings.")),
      );
      return;
    }
    // --------------------------------------------------

    // 2. Get Material Context
    String category = safeValue('material_category').toLowerCase();
    String rawMaterial = safeValue('material').toLowerCase();

    // 3. Load JSON Database
    String jsonString =
        await rootBundle.loadString('assets/uae_recycling_centers.json');
    List<dynamic> allCenters = json.decode(jsonString);

    List<Map<String, dynamic>> validCenters = [];

    // 4. Filter & Calculate Distance
    for (var center in allCenters) {
      List<dynamic> materials = center['materials'];

      // Check if this center accepts the material
      bool accepts = materials.any((m) =>
          m.toString().toLowerCase() == category ||
          m.toString().toLowerCase().contains(rawMaterial));

      if (!accepts) continue;

      // Force conversion to double to prevent parsing errors
      final double centerLat = (center['lat'] as num).toDouble();
      final double centerLon = (center['lon'] as num).toDouble();

      // Skip invalid coordinates (Safety Check)
      if (centerLat < 22 || centerLat > 27 || centerLon < 51 || centerLon > 57) {
        continue;
      }

      // Calculate Distance using Haversine formula
      double dist = _calculateDistance(
        position.latitude,
        position.longitude,
        centerLat,
        centerLon,
      );

      // Only show centers within 50km
      if (dist <= 50) {
        validCenters.add({
          "name": center['name'],
          "city": center['city'],
          "type": center['type'] ?? "Recycling Center",
          "access": center['access'],
          "dist": dist,
          "lat": centerLat,
          "lon": centerLon,
          "url": center['url'] ?? "" // <--- READ THE URL FROM JSON
        });
      }
    }

    // 5. Sort by Nearest
    validCenters.sort((a, b) => a['dist'].compareTo(b['dist']));

    // 6. Limit to Top 5 Results
    if (validCenters.length > 5) {
      validCenters = validCenters.sublist(0, 5);
    }

    _displayBottomSheet(validCenters, rawMaterial);
  }

  // ---------------- MATH (Haversine) ----------------
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth radius in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  // ---------------- MAP LAUNCHER (UPDATED) ----------------
  Future<void> _launchMapUrl(String? link) async {
    // If the JSON is missing the URL, do nothing
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Map link not available for this location")),
      );
      return;
    }

    // Use the exact link provided in the JSON file
    final Uri url = Uri.parse(link);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch map');
    }
  }

  // ---------------- UI: BOTTOM SHEET ----------------
  void _displayBottomSheet(
      List<Map<String, dynamic>> centers, String material) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Nearby for $material",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(),
              if (centers.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No compatible centers found nearby"))
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: centers.length,
                    itemBuilder: (context, index) {
                      var c = centers[index];
                      bool is247 = c['access'].toString().contains("24/7");

                      return ListTile(
                        leading: const Icon(Icons.recycling,
                            color: Colors.green),
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(c['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            if (is247)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text("24/7",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              )
                          ],
                        ),
                        subtitle: Text(
                            "${c['type']} • ${c['dist'].toStringAsFixed(1)} km"),
                        trailing: IconButton(
                          icon: const Icon(Icons.directions, color: Colors.blue),
                          onPressed: () {
                            // HERE IS THE FIX: Pass the stored URL string
                            _launchMapUrl(c['url']);
                          },
                        ),
                        onTap: () => _launchMapUrl(c['url']),
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

  // ---------------- IMAGE PICKER & UPLOAD ----------------
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _webImage = null;
        _data = null;
      });
      _uploadImage(picked);
    }
  }

  Future<void> _uploadImage(XFile file) async {
    setState(() => _isLoading = true);
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(http.MultipartFile.fromBytes(
          'file', await file.readAsBytes(),
          filename: 'upload.jpg'));

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          _data = jsonResponse;
          if (isRecyclable) _score += 10;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error connecting to server: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- MAIN UI SCAFFOLD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("IEEE Recycling AI"),
        backgroundColor: Colors.green[700],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
                child: Text("Score: $_score",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_data != null) ...[
                    // Result Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isRecyclable ? Icons.check_circle : Icons.cancel,
                            color: isRecyclable ? Colors.green : Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isRecyclable ? "Recyclable!" : "Not Recyclable",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isRecyclable
                                    ? Colors.green[800]
                                    : Colors.red[800]),
                          ),
                          const SizedBox(height: 10),
                          Text("Material: ${safeValue('material')}",
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 5),
                          Text("Certainty: ${safeValue('confidence')}",
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Buttons
                  ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Scan Object"),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15))),

                  const SizedBox(height: 20),

                  if (_data != null && isRecyclable)
                    ElevatedButton.icon(
                      onPressed: _showLocations,
                      icon: const Icon(Icons.map),
                      label: const Text("Find Nearby Centers"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15)),
                    ),
                ],
              ),
      ),
    );
  }
}