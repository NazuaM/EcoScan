import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                            border: Border.all(color: Colors.white38, width: 2)),
                        child: Center(
                          child: Text(
                            isGuest ? "" : (user?.displayName?.isNotEmpty == true
                                ? user!.displayName![0].toUpperCase() : "?"),
                            style: const TextStyle(fontSize: 32, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGuest ? "Guest User" : (user?.displayName ?? "EcoWarrior"),
                        style: const TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (!isGuest && user?.email != null)
                        Text(user!.email!,
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isGuest
                  ? _guestPrompt(context)
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users').doc(user!.uid).snapshots(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                        final score = data['score'] ?? 0;
                        final scans = data['scans'] ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Stats row
                            Row(children: [
                              Expanded(child: _statCard("", "$score", "Total Points")),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard("", "$scans", "Items Scanned")),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard("",
                                  "${(score / 10).floor()}", "Recycled")),
                            ]),

                            const SizedBox(height: 20),

                            // Level card
                            _levelCard(score),

                            const SizedBox(height: 20),

                            // Badges
                            _badgesSection(score, scans),

                            const SizedBox(height: 20),

                            // Sign out
                            OutlinedButton.icon(
                              onPressed: () => _signOut(context),
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text("Sign Out",
                                  style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _levelCard(int score) {
    final levels = [
      {"min": 0,   "max": 49,  "name": "Eco Beginner",   "emoji": "", "color": Colors.green[200]},
      {"min": 50,  "max": 149, "name": "Green Explorer",  "emoji": "", "color": Colors.green[400]},
      {"min": 150, "max": 299, "name": "Eco Warrior",     "emoji": "", "color": Colors.green[600]},
      {"min": 300, "max": 499, "name": "Planet Guardian", "emoji": "", "color": Colors.teal[600]},
      {"min": 500, "max": 9999,"name": "EcoScan Legend",  "emoji": "", "color": Colors.amber[700]},
    ];

    final level = levels.lastWhere((l) => score >= (l['min'] as int), orElse: () => levels[0]);
    final nextLevel = levels.indexOf(level) < levels.length - 1
        ? levels[levels.indexOf(level) + 1] : null;

    final progress = nextLevel != null
        ? (score - (level['min'] as int)) /
          ((nextLevel['min'] as int) - (level['min'] as int))
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          (level['color'] as Color).withOpacity(0.15),
          (level['color'] as Color).withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (level['color'] as Color).withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(level['emoji'] as String, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Your Level", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(level['name'] as String,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                    color: level['color'] as Color)),
          ])),
          Text("$score pts",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        if (nextLevel != null) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(level['color'] as Color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text("${(nextLevel['min'] as int) - score} pts to ${nextLevel['name']}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _badgesSection(int score, int scans) {
    final badges = [
      {"emoji": "", "name": "First Scan",   "desc": "Complete your first scan", "earned": scans >= 1},
      {"emoji": "", "name": "5 Scans",      "desc": "Scan 5 items",             "earned": scans >= 5},
      {"emoji": "", "name": "Recycler",     "desc": "Earn 50 points",           "earned": score >= 50},
      {"emoji": "", "name": "Eco Warrior",  "desc": "Earn 150 points",          "earned": score >= 150},
      {"emoji": "", "name": "Planet Saver", "desc": "Earn 300 points",          "earned": score >= 300},
      {"emoji": "", "name": "Legend",       "desc": "Earn 500 points",          "earned": score >= 500},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Badges", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 1, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: badges.length,
        itemBuilder: (ctx, i) {
          final b = badges[i];
          final earned = b['earned'] as bool;
          return Container(
            decoration: BoxDecoration(
              color: earned ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: earned ? Colors.green.shade300 : Colors.grey.shade200),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(earned ? (b['emoji'] as String) : "",
                  style: TextStyle(fontSize: 28, color: earned ? null : Colors.grey[400])),
              const SizedBox(height: 4),
              Text(b['name'] as String,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: earned ? Colors.green[800] : Colors.grey[400]),
                  textAlign: TextAlign.center),
            ]),
          );
        },
      ),
    ]);
  }

  Widget _guestPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        const Text("", style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text("You're using EcoScan as a guest",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text("Create an account to save your points, earn badges, and track your eco impact!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            FirebaseAuth.instance.signOut();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (_) => false,
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("Create Account", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

