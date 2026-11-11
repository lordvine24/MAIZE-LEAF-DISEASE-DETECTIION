import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

// Auth action state
enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get hasError => status == AuthStatus.error;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _repository.signInWithEmail(email: email, password: password);
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Sign-in failed (${e.code}): ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: AuthRepository.getErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String location,
    required String phone,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      await _repository.registerWithEmail(
        email: email,
        password: password,
        name: name,
        location: location,
        phone: phone,
      );
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Account creation failed (${e.code}): ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: AuthRepository.getErrorMessage(e),
      );
      return false;
    } on FirebaseException catch (e) {
      debugPrint('[Auth] Profile database write failed (${e.code}): ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage:
            'The account may exist, but saving its profile failed (${e.code}): ${e.message ?? 'Check your Realtime Database configuration and rules.'}',
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint('[Auth] Unexpected registration failure: $e');
      debugPrintStack(stackTrace: stackTrace);
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage:
            'Account created, but the profile could not be saved. Please try again.',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final result = await _repository.signInWithGoogle();
      if (result == null) {
        state = const AuthState(status: AuthStatus.idle);
        return false;
      }
      state = const AuthState(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Google sign-in failed (${e.code}): ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: AuthRepository.getErrorMessage(e),
      );
      return false;
    } catch (e) {
      debugPrint('[Auth] Unexpected Google sign-in failure: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Google Sign-In failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.idle);
  }

  Future<void> sendPasswordReset(String email) async {
    await _repository.sendPasswordReset(email);
  }

  void clearError() {
    state = const AuthState(status: AuthStatus.idle);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
