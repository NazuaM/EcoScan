import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // â”€â”€ Email/Password Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Create Firestore user doc
        await _createUserDoc(cred.user!, _nameController.text.trim());
        await cred.user!.updateDisplayName(_nameController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // â”€â”€ Google Sign In â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { setState(() => _isLoading = false); return; }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);

      // Create doc only if new user
      if (cred.additionalUserInfo?.isNewUser == true) {
        await _createUserDoc(cred.user!, cred.user!.displayName ?? "EcoWarrior");
      }
    } on FirebaseAuthException catch (e) {
      _showError("Google sign-in failed: ${_friendlyError(e.code)} (${e.code})");
    } catch (e) {
      _showError("Google sign-in failed. Check Firebase Google provider and SHA-1 settings.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUserDoc(User user, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'score': 0,
      'scans': 0,
      'joinedAt': FieldValue.serverTimestamp(),
      'badges': [],
    });
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email.';
      default: return 'Something went wrong. Try again.';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
    _animController.reset();
    _animController.forward();
  }

  Future<void> _continueAsGuest() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        _showError('Guest sign-in is disabled in Firebase Console.');
      } else {
        _showError(_friendlyError(e.code));
      }
    } catch (_) {
      _showError('Could not continue as guest. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // â”€â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // Logo
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: const Center(
                    child: Text("â™»ï¸", style: TextStyle(fontSize: 44)),
                  ),
                ),

                const SizedBox(height: 16),
                const Text("EcoScan",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 1)),
                const Text("Scan. Learn. Recycle.",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),

                const SizedBox(height: 40),

                // Card
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15),
                            blurRadius: 20, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab switcher
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              _tabButton("Sign In", _isLogin, () { if (!_isLogin) _toggleMode(); }),
                              _tabButton("Create Account", !_isLogin, () { if (_isLogin) _toggleMode(); }),
                            ]),
                          ),

                          const SizedBox(height: 24),

                          // Name field (signup only)
                          if (!_isLogin) ...[
                            _inputField(
                              controller: _nameController,
                              label: "Your Name",
                              icon: Icons.person_outline,
                              validator: (v) => v == null || v.trim().isEmpty ? "Enter your name" : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email
                          _inputField(
                            controller: _emailController,
                            label: "Email",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Enter email";
                              if (!v.contains('@')) return "Invalid email";
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Enter password";
                              if (!_isLogin && v.length < 6) return "Min 6 characters";
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // Submit button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitEmailAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Text(_isLogin ? "Sign In" : "Create Account",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Divider
                          Row(children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text("or", style: TextStyle(color: Colors.grey[500])),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ]),

                          const SizedBox(height: 16),

                          // Google button
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Google "G" logo using text
                                  Container(
                                    width: 22, height: 22,
                                    decoration: const BoxDecoration(shape: BoxShape.circle),
                                    child: const Text("G",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                            color: Color(0xFF4285F4))),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text("Continue with Google",
                                      style: TextStyle(fontSize: 15, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Skip for now
                TextButton(
                  onPressed: _isLoading ? null : _continueAsGuest,
                  child: const Text("Continue as guest",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

