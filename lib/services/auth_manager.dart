import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'role_manager.dart';
import 'app_storage.dart';

class MockUser {
  final String id;
  final String name;
  final String email;
  final AppRole role;
  final String initials;

  MockUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.initials,
  });
}

class AuthManager {
  static const String _baseUrl = 'https://mindspacenlp.com/api';

  static MockUser? currentUser;
  static String? token;

  static String? lastGoogleError;

  // Google Client IDs from Google Cloud Console
  // Android client ID is matched automatically by SHA-1 + package name — do NOT pass it as clientId
  static const String googleAndroidClientId = '691958183695-nmunvqg3rn3upfeniqqt3rpkvfkle53o.apps.googleusercontent.com';
  static const String googleWebClientId = '691958183695-ttg8pgkls57ktf6n0gjh8rfhgo06vibt.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // On Android: clientId and serverClientId must NOT be set — Android resolves the OAuth
    // client automatically using the APK SHA-1 fingerprint + package name registered in Google Cloud Console.
    // serverClientId being set causes signIn() to silently return null on Android.
    clientId: kIsWeb ? googleWebClientId : null,
    scopes: ['email', 'profile'],
  );

  static Future<bool> login(String email, String password) async {
    final cleanedEmail = email.trim().toLowerCase();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanedEmail,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['access_token'];
        
        final userData = data['user'] ?? {};
        final String userId = userData['id']?.toString() ?? '1';
        final name = userData['name'] ?? 'User';
        final userEmail = userData['email'] ?? cleanedEmail;

        final roleStr = userData['role']?.toString().toLowerCase() ?? '';
        final role = (roleStr == 'admin' || userEmail.contains('admin') || name.toLowerCase().contains('admin'))
            ? AppRole.admin
            : AppRole.user;

        final initials = name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();

        currentUser = MockUser(
          id: userId,
          name: name,
          email: userEmail,
          role: role,
          initials: initials.isEmpty ? 'U' : initials,
        );

        RoleManager.switchRole(role);
        await SessionStorage.save(token!, userId, name, userEmail, roleStr);
        return true;
      }
    } catch (e) {
      debugPrint('Login API error: $e');
    }
    return false;
  }

  static Future<bool> register(String name, String email, String password, {String? mobileNo}) async {
    final cleanedEmail = email.trim().toLowerCase();
    final cleanedMobile = mobileNo?.trim();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': cleanedEmail.isEmpty ? null : cleanedEmail,
          'mobile_no': cleanedMobile == null || cleanedMobile.isEmpty ? null : cleanedMobile,
          'password': password,
          'password_confirmation': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['access_token'];
        
        final userData = data['user'] ?? {};
        final String userId = userData['id']?.toString() ?? '1';
        final returnedEmail = userData['email'] ?? userData['mobile_no'] ?? cleanedEmail;

        currentUser = MockUser(
          id: userId,
          name: name,
          email: returnedEmail,
          role: AppRole.user,
          initials: name.isNotEmpty ? name[0].toUpperCase() : 'U',
        );

        RoleManager.switchRole(AppRole.user);
        await SessionStorage.save(token!, userId, name, returnedEmail, 'user');
        return true;
      }
    } catch (e) {
      debugPrint('Register API error: $e');
    }
    return false;
  }

  static String? lastForgotError;

  static Future<bool> sendResetLink(String email) async {
    lastForgotError = null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return true;
      } else {
        lastForgotError = body['message']?.toString() ?? 'Unable to send reset link (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Forgot password API error: $e');
      lastForgotError = 'Network error: $e';
    }
    return false;
  }

  static Future<bool> googleSignIn() async {
    try {
      // Triggers native system Google Account picker on device
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // null = user cancelled picker or Play Services could not complete sign-in
      if (googleUser == null) {
        lastGoogleError = 'Sign-in was cancelled or no Google account was selected.';
        return false;
      }

      final userName = (googleUser.displayName != null && googleUser.displayName!.isNotEmpty)
          ? googleUser.displayName!
          : 'Google User';
      final userEmail = googleUser.email;
      final String userId = googleUser.id;

      // Get Google auth tokens for backend verification
      GoogleSignInAuthentication? googleAuth;
      String? idToken;
      String? accessToken;
      try {
        googleAuth = await googleUser.authentication;
        idToken = googleAuth.idToken;
        accessToken = googleAuth.accessToken;
      } catch (authErr) {
        debugPrint('Could not get Google auth tokens: $authErr');
        // Continue without idToken — we'll send email + name to backend
      }

      // Call backend to exchange Google credentials for Laravel API token
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': idToken ?? '',
            'access_token': accessToken ?? '',
            'google_id': userId,
            'name': userName,
            'email': userEmail,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Try both common token field names
          token = data['access_token'] ?? data['token'];

          final userData = data['user'] ?? data['data'] ?? {};
          final String backendId = userData['id']?.toString() ?? userId;
          final String backendName = userData['name']?.toString() ?? userName;
          final String backendEmail = userData['email']?.toString() ?? userEmail;
          final roleStr = userData['role']?.toString().toLowerCase() ?? 'user';
          final role = (roleStr == 'admin') ? AppRole.admin : AppRole.user;

          final initials = backendName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();

          currentUser = MockUser(
            id: backendId,
            name: backendName,
            email: backendEmail,
            role: role,
            initials: initials.isEmpty ? 'G' : initials,
          );

          RoleManager.switchRole(role);
          await SessionStorage.save(token!, backendId, backendName, backendEmail, roleStr);
          return true;
        } else {
          // Show exact backend response so we can debug
          lastGoogleError = 'Backend /api/auth/google returned ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
          await _googleSignIn.signOut();
          return false;
        }
      } catch (backendErr) {
        lastGoogleError = 'Backend unreachable: $backendErr';
        await _googleSignIn.signOut();
        return false;
      }
    } catch (e) {
      debugPrint('Native Google Sign-In SDK exception: $e');
      lastGoogleError = e.toString();
    }

    return false;
  }

  static Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    currentUser = null;
    token = null;
    RoleManager.switchRole(AppRole.user);
    await SessionStorage.clear();
  }

  static Future<bool> tryAutoLogin() async {
    try {
      final session = await SessionStorage.load();
      if (session != null) {
        token = session['token'];
        
        final userData = session['user'];
        final String userId = userData['id']?.toString() ?? '1';
        final name = userData['name'] ?? 'User';
        final email = userData['email'] ?? '';
        
        final roleStr = userData['role']?.toString().toLowerCase() ?? '';
        final role = roleStr == 'admin' ? AppRole.admin : AppRole.user;
        
        final initials = name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();

        currentUser = MockUser(
          id: userId,
          name: name,
          email: email,
          role: role,
          initials: initials.isEmpty ? 'U' : initials,
        );

        RoleManager.switchRole(role);
        return true;
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
    }
    return false;
  }
}

class SessionStorage {
  static Future<void> save(String token, String userId, String name, String email, String role) async {
    final userMap = {
      'id': userId,
      'name': name,
      'email': email,
      'role': role,
    };
    try {
      await AppStorage.write('auth_token', token);
      await AppStorage.write('auth_user', jsonEncode(userMap));
    } catch (e) {
      debugPrint('Session save error: $e');
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final token = await AppStorage.read('auth_token');
      final userStr = await AppStorage.read('auth_user');
      if (token != null && token.isNotEmpty && userStr != null && userStr.isNotEmpty) {
        return {
          'token': token,
          'user': jsonDecode(userStr),
        };
      }
    } catch (e) {
      debugPrint('Session load error: $e');
    }
    return null;
  }

  static Future<void> clear() async {
    try {
      await AppStorage.delete('auth_token');
      await AppStorage.delete('auth_user');
    } catch (e) {
      debugPrint('Session clear error: $e');
    }
  }
}
