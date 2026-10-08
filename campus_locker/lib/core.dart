// User-app state: Firebase phone login + profile on top of the shared Hub.
import 'dart:async';
import 'package:campus_shared/campus_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
export 'package:campus_shared/campus_shared.dart';

class AppState extends Hub {
  String name = '', mobile = '', userType = '', sr = '';
  String? _verId;
  bool get loggedIn => mobile.isNotEmpty;
  bool get hasProfile => name.isNotEmpty;
  bool isSender(Txn t) => normMobile(t.senderMobile) == mobile;
  bool isRecipient(Txn t) => normMobile(t.mobile) == mobile;

  Future<void> init() async {
    await start();
    final p = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (p != null) await _loadUser(normMobile(p));
  }

  Future<void> _loadUser(String m) async {
    final u = (await db.doc('users/$m').get()).data();
    name = u?['name'] ?? '';
    userType = u?['type'] ?? '';
    sr = u?['sr'] ?? '';
    mobile = m;
    notifyListeners();
  }

  /// Sends the OTP. Returns an error message or null.
  Future<String?> sendCode(String raw) async {
    final n = normMobile(raw);
    final c = Completer<String?>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: n.startsWith('0') ? '+63${n.substring(1)}' : '+$n',
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
        await _loadUser(normMobile(FirebaseAuth.instance.currentUser!.phoneNumber!));
      },
      verificationFailed: (e) {
        if (!c.isCompleted) c.complete(e.message ?? e.code);
      },
      codeSent: (id, _) {
        _verId = id;
        if (!c.isCompleted) c.complete(null);
      },
      codeAutoRetrievalTimeout: (id) => _verId = id,
    );
    return c.future;
  }

  Future<String?> verify(String code) async {
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verId!, smsCode: code);
      await FirebaseAuth.instance.signInWithCredential(cred);
      await _loadUser(normMobile(FirebaseAuth.instance.currentUser!.phoneNumber!));
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  Future<void> saveProfile(String n, String type, String s) async {
    name = n;
    userType = type;
    sr = s;
    notifyListeners();
    await db.doc('users/$mobile').set({'name': n, 'type': type, 'sr': s});
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    mobile = '';
    name = '';
    notifyListeners();
  }
}

final app = AppState();
