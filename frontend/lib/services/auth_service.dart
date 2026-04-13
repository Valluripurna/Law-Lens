import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> userExists(String email) async {
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> registerUserInFirestore(String email, String uid) async {
    await _firestore.collection('users').doc(email).set({
      'email': email,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (!await userExists(email)) {
        return {'success': false, 'error': 'Account not found. Please sign up first.'};
      }
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _saveAuthData(userCredential.user?.uid ?? '', email);
      return {'success': true, 'data': userCredential.user?.uid};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> signup(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await registerUserInFirestore(email, userCredential.user?.uid ?? '');
      await _saveAuthData(userCredential.user?.uid ?? '', email);
      return {'success': true, 'data': userCredential.user?.uid};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
     try {
       await _googleSignIn.initialize();
       final gsi.GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
       
       final gsi.GoogleSignInAuthentication googleAuth = googleUser.authentication;
       
       // In v7.2.0, accessToken is removed from authentication tokens.
       // Firebase Auth only requires the idToken for Google Sign-In anyway.
       final AuthCredential credential = GoogleAuthProvider.credential(
         idToken: googleAuth.idToken,
       );

       UserCredential userCredential = await _auth.signInWithCredential(credential);
       return {
         'success': true, 
         'uid': userCredential.user?.uid, 
         'email': userCredential.user?.email,
         'credential': userCredential
       };
     } catch (e) {
       return {'success': false, 'error': e.toString()};
     }
  }

  Future<void> _saveAuthData(String uid, String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', uid); 
    await prefs.setString('userUid', uid);
    await prefs.setString('userEmail', email);
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('userUid');
    await prefs.remove('userEmail');
  }

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }
}
