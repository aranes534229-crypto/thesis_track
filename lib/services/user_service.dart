import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final String role;
}

class UserService {
  UserService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final cleanedName = name.trim();
    final cleanedEmail = email.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanedEmail,
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'name': cleanedName,
        'email': user.email ?? cleanedEmail,
        'role': role,
      });
    } catch (error) {
      try {
        await user.delete();
      } catch (_) {
        // The original registration error is the useful one to show.
      }
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      final name = data['name'];
      final email = data['email'];
      final role = data['role'];

      if (name is! String || email is! String || role is! String) {
        return null;
      }

      if (role != 'student' && role != 'adviser') {
        return null;
      }

      return UserProfile(name: name, email: email, role: role);
    });
  }
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
    }
  }

  return 'Something went wrong. Please try again.';
}
