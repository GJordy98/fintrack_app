import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// Flux réactif de l'utilisateur connecté.
  Stream<User?> get userStream => _firebaseAuth.authStateChanges();

  /// Obtenir l'utilisateur actuel.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Inscription e-mail et mot de passe.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Connexion e-mail et mot de passe.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Connexion Google.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Déclenche le flux d'authentification Google natif (v7.0.0+).
      // En v7, authenticate() lève une GoogleSignInException si l'utilisateur
      // annule (plutôt que de renvoyer null).
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Obtient le jeton d'identité (authentication est un getter synchrone en v7).
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Impossible de récupérer le jeton d'identité Google (ID Token).");
      }

      // Crée un identifiant de connexion Firebase.
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // Se connecte à Firebase avec l'identifiant.
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      // Annulation par l'utilisateur : ce n'est pas une erreur à afficher.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw Exception('Erreur de connexion Google : ${e.description ?? e.code}');
    } catch (e) {
      throw Exception('Erreur de connexion Google : $e');
    }
  }

  /// Déconnexion globale.
  Future<void> signOut() async {
    try {
      // On tente de déconnecter Google en premier
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // S'il n'était pas connecté avec Google ou si la session est expirée, on ignore l'erreur
      }
      // Puis on déconnecte Firebase
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion : $e');
    }
  }
}
