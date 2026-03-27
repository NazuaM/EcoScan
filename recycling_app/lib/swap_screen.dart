import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SwapScreen extends StatefulWidget {
  final String initialItem;
  final String backendUrl;

  const SwapScreen({
    super.key,
    required this.initialItem,
    required this.backendUrl,
  });

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  late TextEditingController _controller;
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  String get baseUrl => widget.backendUrl.replaceAll('/analyze', '');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.initialItem == "Unknown" ? "" : widget.initialItem);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getSwap() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() { _isLoading = true; _result = null; });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/swap"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"item": input}),
      );
      if (response.statusCode == 200) {
        setState(() => _result = json.decode(response.body));
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Could not connect: $e");
    } finally {
      setState(() => _isLoading = false);
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
        title: const Text("Eco-Friendly Swaps",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(children: [
                Icon(Icons.swap_horiz, color: Colors.teal[700]),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Type any waste item to find sustainable alternatives you can use instead.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // Text input
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "What item do you want to replace?",
                hintText: "e.g. plastic bottle, styrofoam cup...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF00897B), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _controller.clear()))
                    : null,
              ),
              onSubmitted: (_) => _getSwap(),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            // Quick chips
            Text("Quick ideas:",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                "Plastic bottle", "Plastic bag", "Styrofoam cup",
                "Paper towel", "Plastic straw", "Disposable razor",
              ].map((item) => ActionChip(
                label: Text(item,
                    style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.teal[50],
                side: BorderSide(color: Colors.teal.shade200),
                onPressed: () {
                  setState(() => _controller.text = item);
                  _getSwap();
                },
              )).toList(),
            ),

            const SizedBox(height: 20),

            // Search button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _getSwap,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.eco),
                label: Text(_isLoading
                    ? "Finding alternatives..."
                    : "Find Eco Alternatives"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Results
            if (_result != null) ...[
              if (_result!.containsKey('error'))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12)),
                  child: Text("Error: ${_result!['error']}",
                      style: const TextStyle(color: Colors.red)),
                )
              else ...[
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.teal[100],
                        shape: BoxShape.circle),
                    child: Icon(Icons.swap_horiz,
                        color: Colors.teal[800]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text("Instead of:",
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      Text(
                        _result!['original_item']?.toString() ??
                            _controller.text,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.red),
                      ),
                    ]),
                  ),
                ]),

                const SizedBox(height: 16),

                ...(_result!['swaps'] as List? ?? [])
                    .asMap()
                    .entries
                    .map((entry) {
                  final swap =
                      entry.value as Map<String, dynamic>;
                  final colors = [
                    Colors.teal,
                    Colors.green,
                    Colors.blue
                  ];
                  final color = colors[entry.key % colors.length];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: color.shade200),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.06),
                            blurRadius: 8)
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: color.shade100,
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: Text(
                              "Option ${entry.key + 1}",
                              style: TextStyle(
                                  color: color.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            swap['name']?.toString() ??
                                "Alternative",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        Icon(Icons.eco,
                            color: color.shade400, size: 20),
                      ]),
                      const SizedBox(height: 10),
                      _swapRow(Icons.thumb_up_outlined, color,
                          "Why better",
                          swap['reason']?.toString() ?? ""),
                      if (swap['estimated_co2_saving'] != null) ...[
                        const SizedBox(height: 6),
                        _swapRow(Icons.cloud_outlined,
                            Colors.green, "CO₂ saving",
                            swap['estimated_co2_saving'].toString()),
                      ],
                      if (swap['where_to_buy'] != null) ...[
                        const SizedBox(height: 6),
                        _swapRow(Icons.store_outlined, Colors.blue,
                            "Where to find",
                            swap['where_to_buy'].toString()),
                      ],
                    ]),
                  );
                }),
              ],
            ],

            // Empty state
            if (_result == null && !_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(children: [
                  Icon(Icons.eco, size: 70, color: Colors.teal[200]),
                  const SizedBox(height: 16),
                  Text(
                    "Search for an item above\nto find eco-friendly swaps",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 15),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _swapRow(IconData icon, MaterialColor color,
      String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color.shade400),
      const SizedBox(width: 6),
      SizedBox(
          width: 80,
          child: Text("$label:",
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 12))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500))),
    ]);
  }
}