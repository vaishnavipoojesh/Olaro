import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'socket_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Web Client ID for backend verification (required for idToken)
  static const String _webClientId =
      '970798776513-tdst3o68paqr6rbeuqre2s1jussg2rrr.apps.googleusercontent.com';

  // Google Sign In instance
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  GoogleSignInAccount? _currentUser;

  AuthService();

  Future<void> init() async {
    try {
      // Initialize Google Sign In safely with serverClientId
      // This maps to the configuration in google-services.json
      await _googleSignIn.initialize(
        serverClientId: _webClientId,
      );
    } catch (e) {
      debugPrint('AuthService initialization error: $e');
      // Continue execution even if init fails (e.g. invalid config)
      // Login will fail later if needed, but app won't crash.
    }

    // Listen to authentication events
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentUser = event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
      }
    });
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      ApiService.setAuthToken(token);
      return true;
    }
    return false;
  }

  // Get stored user data
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }

  // Sign in with Google
  Future<AuthResult> signInWithGoogle({String? referralCode}) async {
    try {
      // Step 1: Trigger Google Sign In flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Step 3: Get the idToken
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult(
          success: false,
          message: 'Failed to get authentication token from Google',
        );
      }

      // Step 4: Send idToken to backend
      final response = await ApiService.googleSignIn(
        idToken: idToken,
        referralCode: referralCode,
      );

      // Step 5: Save token and user data locally
      await _saveAuthData(response['token'], response['user']);

      return AuthResult(
        success: true,
        message: response['message'],
        isNewUser: response['isNewUser'] ?? false,
        user: response['user'],
        token: response['token'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AuthResult(
          success: false,
          message: 'Sign in cancelled',
        );
      }
      debugPrint('Google Sign-In Error: $e');
      return AuthResult(
        success: false,
        message: 'Sign in failed: $e',
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return AuthResult(
        success: false,
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // Save auth data locally
  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    ApiService.setAuthToken(token);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Disconnect and reset socket to clear any cached user data
      SocketService.instance.reset();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Sign out from backend
      await ApiService.logout();
    } finally {
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      ApiService.clearAuthToken();
      _currentUser = null;
    }
  }

  // Check if Google account is signed in
  Future<bool> isGoogleSignedIn() async {
    final account = await _googleSignIn.attemptLightweightAuthentication();
    return account != null;
  }

  // Get current Google user
  GoogleSignInAccount? getCurrentGoogleUser() {
    return _currentUser;
  }
}

// Auth Result class
class AuthResult {
  final bool success;
  final String message;
  final bool isNewUser;
  final Map<String, dynamic>? user;
  final String? token;

  AuthResult({
    required this.success,
    required this.message,
    this.isNewUser = false,
    this.user,
    this.token,
  });
}
