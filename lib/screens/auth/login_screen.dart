import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:study_sync/providers/user_provider.dart';
import 'package:study_sync/screens/auth/register_screen.dart';
import 'package:study_sync/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? null
        : '454503718694-2al5fr2bip3er1u4d65k67qh9e0ct6je.apps.googleusercontent.com',
  );

  bool _showPassword = true;
  bool _isLoading = false;
  bool _submitted = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await Provider.of<UserProvider>(context, listen: false).loadUserData(userCredential.user!);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showSnackBar('An error occurred during login');
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await Provider.of<UserProvider>(context, listen: false)
          .loadUserData(userCredential.user!);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showSnackBar('Google Sign-In failed');
      debugPrint('Google Sign-In error: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'No user found with this email';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password';
        break;
      case 'user-disabled':
        errorMessage = 'This account has been disabled';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email format';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Try again later';
        break;
      default:
        errorMessage = 'Authentication failed: ${e.message}';
    }
    _showSnackBar(errorMessage);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      if (_emailController.text.isEmpty) {
                        _showSnackBar('Please enter your email first');
                        return;
                      }
                      FirebaseAuth.instance
                          .sendPasswordResetEmail(
                            email: _emailController.text.trim(),
                          )
                          .then(
                            (_) => _showSnackBar('Password reset email sent'),
                          )
                          .catchError(
                            (e) => _handleAuthError(e as FirebaseAuthException),
                          );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 30),
                OutlinedButton(
                  onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: _isGoogleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google'),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: "Don't have an account? ",
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}