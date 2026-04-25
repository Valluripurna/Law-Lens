import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:law_lens/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([FirebaseAuth, FirebaseFirestore, User, UserCredential])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AuthService Unit Tests', () {
    test('isLoggedIn returns false when currentUser is null', () async {
      // Note: We can't easily mock static instances like FirebaseAuth.instance
      // unless the service allows passing an instance.
      // For now, we verify the logic structure.
      final authService = AuthService();
      final loggedIn = await authService.isLoggedIn();
      expect(loggedIn, isFalse);
    });

    test('logout clears shared preferences', () async {
      final authService = AuthService();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', 'test_user');
      
      try {
        await authService.logout();
      } catch (e) {
        // FirebaseAuth.instance will throw in test environment if not initialized
        // but we care about the SharedPreferences clearing logic here.
      }
      
      expect(prefs.getString('userId'), isNull);
    });
  });
}
