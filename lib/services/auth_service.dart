import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

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
    bool isZh = false,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.sendEmailVerification();
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(isZh ? '注册失败，请稍后重试' : 'Registration failed, please try again');
    }
  }

  // ── 邮箱登录 ──────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
    bool isZh = false,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(isZh ? '登录失败，请稍后重试' : 'Sign in failed, please try again');
    }
  }

  // ── Google登录 ────────────────────────────────────────────────────────────
  Future<AuthResult> signInWithGoogle({bool isZh = false}) async {
    try {
      if (kIsWeb) {
        // Web 端：改用 Redirect 方式，彻底避免 COOP/window.close 错误
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        await _auth.signInWithRedirect(provider);
        // signInWithRedirect 会跳转页面，下面代码不会执行
        // 页面回来后 AuthGate 的 authStateChanges 会自动处理
        return AuthResult.success(null);
      } else {
        // 移动端
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.failure(isZh ? '已取消 Google 登录' : 'Google sign-in cancelled');
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
      if (e.code == 'unauthorized-domain') {
        return AuthResult.failure(
          isZh
              ? 'Google 登录需要在 Firebase Console 中授权当前域名。'
              : 'This domain is not authorized for Google sign-in.',
        );
      }
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(isZh ? 'Google 登录失败，请稍后重试' : 'Google sign-in failed, please try again');
    }
  }

  // ── 忘记密码 ──────────────────────────────────────────────────────────────
  Future<AuthResult> sendPasswordResetEmail(String email, {bool isZh = false}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(isZh ? '发送失败，请稍后重试' : 'Failed to send email, please try again');
    }
  }

  // ── 退出登录 ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    // Web 端：强制刷新页面，确保状态彻底清除
    if (kIsWeb) {
      html.window.location.reload();
    }
  }

  // ── 错误码转提示文字（中英双语）────────────────────────────────────────────
  String _mapError(String code, {bool isZh = false}) {
    if (isZh) {
      switch (code) {
        case 'user-not-found':       return '该邮箱尚未注册';
        case 'wrong-password':       return '密码错误，请重试';
        case 'email-already-in-use': return '该邮箱已被注册';
        case 'weak-password':        return '密码强度不足，请使用6位以上';
        case 'invalid-email':        return '邮箱格式不正确';
        case 'user-disabled':        return '该账号已被禁用';
        case 'too-many-requests':    return '操作过于频繁，请稍后再试';
        case 'network-request-failed': return '网络连接失败，请检查网络';
        case 'invalid-credential':   return '邮箱或密码错误';
        case 'unauthorized-domain':  return 'Google 登录需授权域名，请使用邮箱登录';
        default:                     return '操作失败，请稍后重试';
      }
    } else {
      switch (code) {
        case 'user-not-found':       return 'No account found with this email';
        case 'wrong-password':       return 'Incorrect password, please try again';
        case 'email-already-in-use': return 'This email is already registered';
        case 'weak-password':        return 'Password too weak, use 6+ characters';
        case 'invalid-email':        return 'Invalid email format';
        case 'user-disabled':        return 'This account has been disabled';
        case 'too-many-requests':    return 'Too many attempts, please try again later';
        case 'network-request-failed': return 'Network error, please check connection';
        case 'invalid-credential':   return 'Incorrect email or password';
        case 'unauthorized-domain':  return 'Domain not authorized, please use email login';
        default:                     return 'Operation failed, please try again';
      }
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
