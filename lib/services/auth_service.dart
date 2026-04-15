import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 当前用户流（监听登录状态变化）
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 当前用户
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ── 邮箱注册 ──────────────────────────────────────────────────────────────
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // 设置显示名称
      await credential.user?.updateDisplayName(displayName.trim());
      // 发送邮箱验证
      await credential.user?.sendEmailVerification();
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.failure('注册失败，请稍后重试');
    }
  }

  // ── 邮箱登录 ──────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.failure('登录失败，请稍后重试');
    }
  }

  // ── Google登录 ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web端使用Popup方式
        final provider = GoogleAuthProvider();
        final credential = await _auth.signInWithPopup(provider);
        return AuthResult.success(credential.user);
      } else {
        // 移动端
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.failure('已取消Google登录');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        return AuthResult.success(userCredential.user);
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.failure('Google登录失败，请稍后重试');
    }
  }

  // ── 忘记密码 ──────────────────────────────────────────────────────────────
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.failure('发送失败，请稍后重试');
    }
  }

  // ── 退出登录 ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Firebase错误码转中文 ───────────────────────────────────────────────────
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return '该邮箱尚未注册';
      case 'wrong-password':
        return '密码错误，请重试';
      case 'email-already-in-use':
        return '该邮箱已被注册';
      case 'weak-password':
        return '密码强度不足，请使用6位以上';
      case 'invalid-email':
        return '邮箱格式不正确';
      case 'user-disabled':
        return '该账号已被禁用';
      case 'too-many-requests':
        return '操作过于频繁，请稍后再试';
      case 'network-request-failed':
        return '网络连接失败，请检查网络';
      case 'invalid-credential':
        return '邮箱或密码错误';
      default:
        return '操作失败（$code）';
    }
  }
}

// ── 认证结果封装 ──────────────────────────────────────────────────────────────
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorMessage;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorMessage,
  });

  factory AuthResult.success(User? user) =>
      AuthResult._(isSuccess: true, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
