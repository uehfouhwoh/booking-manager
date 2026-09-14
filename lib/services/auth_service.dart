import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Listen to whether the user is logged in or out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _saveUserProfile(
      user: user,
      email: user.email ?? '',
      name: user.displayName ?? user.email?.split('@').first ?? 'Student',
    );
  }

  Future<void> _saveUserProfile({
    required User user,
    required String email,
    required String name,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existing = snapshot.data();
    final cleanName = name.trim().isEmpty ? 'Student' : name.trim();
    final existingRole = (existing?['role'] ?? 'student')
        .toString()
        .trim()
        .toLowerCase();
    final role = switch (existingRole) {
      'admin' || 'staff' || 'student' => existingRole,
      _ => 'student',
    };

    await userRef.set({
      'email': email.trim().toLowerCase(),
      'name': cleanName,
      'role': role,
      'avatarKey': existing?['avatarKey'] ?? 'cap',
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _authErrorMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' =>
        'This email still exists in Firebase Authentication.',
      _ => e.message ?? 'Authentication failed. Please try again.',
    };
  }

  Future<String?> _recoverExistingAuthAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return 'This email exists in Firebase Authentication, but the account could not be loaded.';
      }

      if (name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
      }
      await _saveUserProfile(user: user, email: email, name: name);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'This email is still registered in Firebase Authentication. Delete it from Authentication > Users, or log in with the old password so the app can restore the missing database profile.';
      }
      return _authErrorMessage(e);
    } catch (e) {
      return 'This email exists in Firebase Authentication, but the user profile could not be restored: $e';
    }
  }

  // 2. Sign In
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await ensureCurrentUserProfile();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    }
  }

  // 3. Sign Up. Public registration always creates a student profile.
  Future<String?> signUp(String email, String password, String name) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    try {
      // Create the account in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      try {
        // Update their display name immediately
        await credential.user?.updateDisplayName(cleanName);

        // Public sign-up must never create privileged staff/admin accounts.
        await _saveUserProfile(
          user: credential.user!,
          email: cleanEmail,
          name: cleanName,
        );
      } catch (e) {
        await credential.user?.delete();
        rethrow;
      }

      return null; // Success!
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return _recoverExistingAuthAccount(
          email: cleanEmail,
          password: password,
          name: cleanName,
        );
      }
      return _authErrorMessage(e);
    } catch (e) {
      return "Failed to save user data: $e";
    }
  }

  // 4. Log Out
  Future<void> logOut() async {
    await _auth.signOut();
  }
}
