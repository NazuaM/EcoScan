import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TutorialScreen extends StatefulWidget {
  final String itemName;
  final String material;
  final String state;
  final String quality;
  final String backendUrl;
  final String unsplashUrl;
  final Future<void> Function()? onTutorialCompleted;

  const TutorialScreen({
    super.key,
    required this.itemName,
    required this.material,
    required this.state,
    required this.quality,
    required this.backendUrl,
    required this.unsplashUrl,
    this.onTutorialCompleted,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _tutorial;
  String _skillLevel = "Beginner";
  bool _tutorialClaimed = false;

  final List<String> _skillLevels = ["Beginner", "Intermediate", "Advanced"];

  final Map<String, bool> _tools = {
    "Scissors": true, "Glue": true, "Knife": false,
    "Paint": false, "Drill": false, "Sewing Kit": false,
    "Sandpaper": false, "Rope/Twine": false,
  };

  String get baseUrl => widget.backendUrl.replaceAll('/analyze', '');

  String _inspirationEmojiForMaterial() {
    final m = widget.material.toLowerCase();
    if (m.contains('plastic')) return '🧴';
    if (m.contains('glass')) return '🍾';
    if (m.contains('paper') || m.contains('cardboard')) return '📦';
    if (m.contains('metal')) return '🥫';
    if (m.contains('wood')) return '🪵';
    if (m.contains('fabric') || m.contains('textile')) return '🧵';
    if (m.contains('electronic')) return '🔌';
    return '🛠️';
  }

  Widget _buildInspirationFallback() {
    final title = (_tutorial?['project_title'] ?? widget.itemName).toString();
    final subtitle = '${widget.material} • DIY upcycle idea';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80), Color(0xFFFFB74D)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛠️♻️', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_inspirationEmojiForMaterial()}  ♻️  ${_inspirationEmojiForMaterial()}',
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateTutorial() async {
    setState(() { _isLoading = true; _tutorial = null; });

    final selectedTools = _tools.entries
        .where((e) => e.value).map((e) => e.key.toLowerCase()).toList();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/tutorial"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "item_name": widget.itemName,
          "material": widget.material,
          "state": widget.state,
          "quality": widget.quality,
          "skill_level": _skillLevel,
          "available_tools": selectedTools,
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _tutorial = json.decode(response.body));
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Could not connect: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _claimPoints() async {
    if (_tutorialClaimed || widget.onTutorialCompleted == null) return;
    await widget.onTutorialCompleted!();
    setState(() => _tutorialClaimed = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("🌱 +20 pts — Tutorial completed!"),
        backgroundColor: Color(0xFF2E7D32),
      ));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("🛠️ DIY Tutorial", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Item info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange[100], borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.inventory_2, color: Colors.orange[800]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("${widget.material} • ${widget.state}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ])),
              ]),
            ),

            const SizedBox(height: 20),

            // Skill level
            const Text("Your Skill Level",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(children: _skillLevels.map((level) {
              final selected = _skillLevel == level;
              final color = level == "Beginner" ? Colors.green
                  : level == "Intermediate" ? Colors.orange : Colors.red;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(level, style: TextStyle(
                      color: selected ? Colors.white : color,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                  selected: selected,
                  selectedColor: color,
                  backgroundColor: color.withOpacity(0.1),
                  onSelected: (_) => setState(() => _skillLevel = level),
                ),
              ));
            }).toList()),

            const SizedBox(height: 20),

            // Tools
            const Text("Available Tools",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _tools.keys.map((tool) => FilterChip(
                label: Text(tool, style: const TextStyle(fontSize: 12)),
                selected: _tools[tool]!,
                onSelected: (val) => setState(() => _tools[tool] = val),
                selectedColor: Colors.orange[100],
                checkmarkColor: Colors.orange[800],
              )).toList(),
            ),

            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateTutorial,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? "Generating..." : "Generate Tutorial"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tutorial result
            if (_tutorial != null) ...[
              if (_tutorial!.containsKey('error'))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                  child: Text("Error: ${_tutorial!['error']}", style: const TextStyle(color: Colors.red)),
                )
              else ...[

                // ── Unsplash image of the upcycled result ──
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("✨ Inspiration",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildInspirationFallback(),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.15),
                                  Colors.black.withOpacity(0.45),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_tutorial!['project_title'] ?? widget.itemName).toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Visual reference only • not an exact final result",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Visual reference",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Project title card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange[700]!, Colors.orange[500]!]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("🎨 PROJECT",
                        style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(_tutorial!['project_title'] ?? "DIY Project",
                        style: const TextStyle(color: Colors.white,
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _infoBadge(Icons.timer, _tutorial!['time_required'] ?? "N/A"),
                      const SizedBox(width: 8),
                      _infoBadge(Icons.bar_chart, _tutorial!['difficulty'] ?? _skillLevel),
                    ]),
                  ]),
                ),

                const SizedBox(height: 14),

                // What you need
                _sectionCard(title: "🧰 What You Need", child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((_tutorial!['materials_needed'] as List?)?.isNotEmpty == true) ...[
                      Text("Materials:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[800])),
                      ..._bulletList(_tutorial!['materials_needed'] as List),
                      const SizedBox(height: 8),
                    ],
                    if ((_tutorial!['tools_needed'] as List?)?.isNotEmpty == true) ...[
                      Text("Tools:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[800])),
                      ..._bulletList(_tutorial!['tools_needed'] as List),
                    ],
                  ],
                )),

                const SizedBox(height: 12),

                // Steps
                _sectionCard(title: "📋 Step-by-Step", child: Column(
                  children: (_tutorial!['steps'] as List? ?? []).asMap().entries.map((entry) {
                    final step = entry.value as Map<String, dynamic>;
                    final num = step['step'] ?? (entry.key + 1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: Colors.orange[700], shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text("$num", style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(step['title'] ?? "",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(step['description'] ?? "",
                              style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
                        ])),
                      ]),
                    );
                  }).toList(),
                )),

                const SizedBox(height: 12),

                // Eco impact
                if (_tutorial!['eco_impact'] != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.green[50], borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200)),
                    child: Row(children: [
                      const Text("🌍", style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Eco Impact", style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green[800])),
                        Text(_tutorial!['eco_impact'],
                            style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      ])),
                    ]),
                  ),

                // Tips
                if ((_tutorial!['tips'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _sectionCard(title: "💡 Tips", child: Column(
                      children: _bulletList(_tutorial!['tips'] as List))),
                ],

                const SizedBox(height: 20),

                // Claim points button
                if (!_tutorialClaimed && widget.onTutorialCompleted != null)
                  ElevatedButton.icon(
                    onPressed: _claimPoints,
                    icon: const Icon(Icons.stars_rounded),
                    label: const Text("I completed this! Claim +20 pts"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (_tutorialClaimed)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Text("+20 pts claimed!", style: TextStyle(
                          color: Colors.green[800], fontWeight: FontWeight.bold)),
                    ]),
                  ),

                const SizedBox(height: 24),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  List<Widget> _bulletList(List items) {
    return items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("• ", style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold)),
        Expanded(child: Text(item.toString(),
            style: TextStyle(color: Colors.grey[700], fontSize: 13))),
      ]),
    )).toList();
  }
}
