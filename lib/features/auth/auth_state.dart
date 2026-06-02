import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/api_client.dart';

class AuthState {
  final String? token;
  final String? email;
  final String? userId;
  final bool initialized;

  const AuthState({
    this.token,
    this.email,
    this.userId,
    this.initialized = false,
  });

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? email,
    String? userId,
    bool? initialized,
  }) {
    return AuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      initialized: initialized ?? this.initialized,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _kToken = 'auth_token';
  static const _kEmail = 'auth_email';
  static const _kUserId = 'auth_user_id';

  @override
  AuthState build() => const AuthState();

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    state = AuthState(
      token: prefs.getString(_kToken),
      email: prefs.getString(_kEmail),
      userId: prefs.getString(_kUserId),
      initialized: true,
    );
  }

  Future<void> _persist({
    required String token,
    required String email,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kUserId, userId);
  }

  Future<void> _handleAuthSuccess(
    Map<String, dynamic> res, {
    required String email,
  }) async {
    final token = res['access_token'];
    final userId = res['user_id'];
    if (token is! String || token.isEmpty || userId is! String || userId.isEmpty) {
      throw Exception(
        'Respuesta de autenticación inválida: faltan access_token o user_id',
      );
    }
    await _persist(token: token, email: email, userId: userId);
    state = AuthState(
      token: token,
      email: email,
      userId: userId,
      initialized: true,
    );
  }

  Future<void> login({required String email, required String password}) async {
    final api = ref.read(unauthApiClientProvider);
    final res = await api.post('/auth/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    await _handleAuthSuccess(res, email: email);
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final api = ref.read(unauthApiClientProvider);
    // ignore: use_null_aware_elements
    final body = <String, dynamic>{'email': email, 'password': password};
    if (displayName != null) body['display_name'] = displayName;
    final res = await api.post('/auth/register', body) as Map<String, dynamic>;
    await _handleAuthSuccess(res, email: email);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kEmail);
    await prefs.remove(_kUserId);
    state = const AuthState(initialized: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
