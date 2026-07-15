import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository) : super(AuthInitial()) {
    _userSubscription = _authRepository.userStream.listen((User? user) {
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _userSubscription;

  Future<void> signInWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError('Une erreur inattendue est survenue: $e'));
      emit(Unauthenticated());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authRepository.signUpWithEmail(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError('Une erreur inattendue est survenue: $e'));
      emit(Unauthenticated());
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      final credential = await _authRepository.signInWithGoogle();
      if (credential == null) {
        // L'utilisateur a annulé la connexion.
        emit(Unauthenticated());
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
    } catch (e) {
      emit(AuthError('Erreur de déconnexion: $e'));
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-disabled':
        return 'Cet utilisateur a été désactivé.';
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cette adresse e-mail.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cette adresse e-mail est déjà utilisée par un autre compte.';
      case 'operation-not-allowed':
        return 'Cette opération n\'est pas autorisée.';
      case 'weak-password':
        return 'Le mot de passe choisi est trop faible.';
      case 'invalid-credential':
        return 'Identifiants invalides (e-mail ou mot de passe incorrect).';
      default:
        return 'Une erreur d\'authentification s\'est produite (code: $code).';
    }
  }
}
