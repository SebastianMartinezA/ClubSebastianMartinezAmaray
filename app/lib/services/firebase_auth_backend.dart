import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_backend.dart';

/// Implementación real del puerto: Firebase Authentication + Google Sign-In.
///
/// `FirebaseAuth.instance` se toca recién en el primer uso (getter, no campo), así
/// que construir la app en un test no explota por no haber `Firebase.initializeApp`.
class FirebaseAuthBackend implements AuthBackend {
  /// Cliente OAuth de tipo *web* del proyecto: es el `serverClientId` con el que
  /// Google devuelve el `idToken`. Sin él, `signIn()` sólo entrega un access
  /// token y Firebase no puede canjearlo.
  static const String _googleServerClientId =
      '784840267639-ie6f0lu07a7lekp4pfhv8hob9vffcplp.apps.googleusercontent.com';

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;

  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
    serverClientId: _googleServerClientId,
  );

  AuthUser _wrap(fb.User user) => AuthUser(
        id: user.uid,
        email: user.email,
        displayName: user.displayName,
        getIdToken: user.getIdToken,
      );

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final fb.UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _wrap(credential.user!);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthBackendException(error.code, error.message);
    }
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final fb.UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (error) {
      throw AuthBackendException(error.code, error.message);
    }

    // El nombre para mostrar en Firebase (opcional: si falla, no se corta el alta).
    if (displayName != null && displayName.trim().isNotEmpty) {
      try {
        await credential.user?.updateDisplayName(displayName.trim());
      } catch (error) {
        debugPrint('[auth] no se pudo guardar el nombre en Firebase: $error');
      }
    }
    return _wrap(credential.user!);
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final GoogleSignInAccount? account;
    try {
      account = await _google.signIn();
    } on PlatformException catch (error) {
      throw AuthBackendException(AuthBackendCodes.googlePlatformError, error.code);
    }
    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthBackendException(AuthBackendCodes.googleMissingToken);
    }

    try {
      final fb.UserCredential credential = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: auth.accessToken,
        ),
      );
      return _wrap(credential.user!);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthBackendException(error.code, error.message);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      throw AuthBackendException(error.code, error.message);
    }
  }

  @override
  Future<AuthUser?> currentUser() async {
    final fb.User? user = _auth.currentUser;
    return user == null ? null : _wrap(user);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}
