// =============================================================================
// auth_service.dart — 认证服务层
// =============================================================================
// 职责：封装所有 Firebase Authentication 操作，向 UI 层提供统一的 AuthResult 接口。
// UI 层（AuthScreen）只调用本服务，不直接使用 FirebaseAuth SDK。
//
// 支持的认证方式：
//   1. 邮箱 + 密码 注册 / 登录
//   2. Google 账号 登录（移动端原生 SDK；Web 端使用 Popup 弹窗）
//   3. 忘记密码 → 发送重置邮件
//   4. 退出登录
//
// 错误处理策略：
//   - FirebaseAuthException 映射为中英文友好提示（_mapError）
//   - 网络/未知错误返回通用提示，不暴露技术细节给用户
// =============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── 监听登录状态变化 ──────────────────────────────────────────────────────
  // 这个 Stream 被 _AuthGate（main.dart）订阅，用于自动切换登录页 / 主页。
  // 当用户登录成功或退出时，Firebase 会推送新的 User? 值，整个路由自动响应。
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 获取当前已登录用户（未登录时为 null）
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ── 邮箱注册 ──────────────────────────────────────────────────────────────
  // 业务流程：
  //   1. 使用 email + password 创建 Firebase 账号
  //   2. 立即更新用户的 displayName（用于"我的"页面显示真实姓名）
  //   3. 发送邮箱验证邮件（验证链接指向 Firebase 默认页面）
  //   4. 注册成功后返回 User 对象；UI 层会跳转到登录状态
  //
  // [API 需求] 当前纯 Firebase 认证，无需自定义后端。
  //   如未来需要在自有数据库创建用户档案，应在此处注册成功后，
  //   额外调用后端接口：POST /api/users { uid, email, displayName }
  //
  // [TODO: 异常处理] 注册成功但 updateDisplayName / sendEmailVerification 失败时，
  //   账号已创建但姓名为空 / 验证邮件未发送。建议：捕获并重试，或提醒用户手动验证。
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
      // 立即写入显示名称，避免用户在验证前就看到空名
      await credential.user?.updateDisplayName(displayName.trim());
      // 发送验证邮件（不强制要求验证才能登录，由业务决定）
      await credential.user?.sendEmailVerification();
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(
          isZh ? '注册失败，请稍后重试' : 'Registration failed, please try again');
    }
  }

  // ── 邮箱登录 ──────────────────────────────────────────────────────────────
  // 登录成功后，Firebase 会通知 authStateChanges，_AuthGate 自动跳转主页。
  // UI 层（_submit）无需手动 Navigator.push，只监听 AuthResult.isSuccess 判断是否有错误。
  //
  // [TODO: 异常处理] 当前不检查 emailVerified，任何账号都能登录。
  //   如需强制邮箱验证，加入：if (!credential.user!.emailVerified) { 返回错误 }
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
      return AuthResult.failure(
          isZh ? '登录失败，请稍后重试' : 'Sign in failed, please try again');
    }
  }

  // ── Google 登录 ──────────────────────────────────────────────────────────
  // 平台差异：
  //   • Web 端：使用 signInWithPopup，弹出 Google 选账号窗口
  //     ⚠️ 沙盒预览环境（sandbox.novita.ai）因网络限制无法访问
  //        petoteco-5e807.firebaseapp.com/__/auth/handler，会报 ERR_CONNECTION_CLOSED。
  //        这是沙盒网络问题，不是代码问题。正式部署后即可正常使用。
  //     ⚠️ COOP 警告 "window.closed call would be blocked" 是 Chrome 安全策略输出的
  //        控制台警告，不影响实际登录功能。
  //   • 移动端（Android/iOS）：调用原生 Google Sign-In SDK，不依赖 Web 弹窗，
  //     完全不受沙盒网络限制。
  //
  // [API 需求] 同邮箱注册，如需在自有后端创建 Google 用户档案：
  //   POST /api/users/oauth { uid, email, displayName, photoURL, provider: 'google' }
  //
  // [TODO: 异常处理] Web 端若 Firebase Console 的 Authorized Domains 未添加当前域名，
  //   会收到 unauthorized-domain 错误，下方已作处理并给出提示。
  Future<AuthResult> signInWithGoogle({bool isZh = false}) async {
    try {
      if (kIsWeb) {
        // Web 端 Popup 模式：Firebase 打开 Google 选账号弹窗
        // 结果同步返回，不需要 getRedirectResult 处理
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        try {
          final userCredential = await _auth.signInWithPopup(provider);
          return AuthResult.success(userCredential.user);
        } catch (popupError) {
          final errStr = popupError.toString();
          // 用户主动关闭弹窗 → 不算错误，静默返回取消状态
          if (errStr.contains('popup_closed') || errStr.contains('cancelled')) {
            return AuthResult.failure(
                isZh ? '已取消 Google 登录' : 'Google sign-in cancelled');
          }
          rethrow; // 其他错误由外层 FirebaseAuthException 捕获
        }
      } else {
        // 移动端：原生 Google Sign-In → 获取 idToken → Firebase 签发 session
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // 用户在 Google 账号选择界面点了取消
          return AuthResult.failure(
              isZh ? '已取消 Google 登录' : 'Google sign-in cancelled');
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
      // 域名未授权：需在 Firebase Console → Authentication → Settings → Authorized domains 添加
      if (e.code == 'unauthorized-domain') {
        return AuthResult.failure(
          isZh
              ? '当前域名未授权。\n请在 Firebase Console → Authentication → Settings → Authorized domains 添加此域名'
              : 'Domain not authorized.\nAdd this domain in Firebase Console → Authentication → Settings → Authorized domains',
        );
      }
      // 用户关闭了弹窗（Firefox/Safari 的错误码与 Chrome 不同）
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'popup_closed_by_user') {
        return AuthResult.failure(
            isZh ? '已取消 Google 登录' : 'Google sign-in cancelled');
      }
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      final errStr = e.toString();
      // COOP/window.closed 相关 JS 异常：Chrome 安全策略触发，实际登录已成功
      // 此处静默返回取消，避免显示误导性错误弹窗
      if (errStr.contains('popup_closed') ||
          errStr.contains('cancelled') ||
          errStr.contains('window.closed')) {
        return AuthResult.failure(
            isZh ? '已取消 Google 登录' : 'Google sign-in cancelled');
      }
      return AuthResult.failure(
          isZh ? 'Google 登录失败，请稍后重试' : 'Google sign-in failed, please try again');
    }
  }

  // ── 忘记密码 ──────────────────────────────────────────────────────────────
  // Firebase 向用户邮箱发送重置链接，链接指向 Firebase 托管页面。
  // 用户点击链接后，在浏览器中直接设置新密码，无需跳回 App。
  //
  // ⚠️ 密码重置链接常见失败原因（按顺序排查）：
  //   1. 链接已过期：Firebase 默认链接有效期 1 小时，过期后需重新申请
  //   2. 链接已被使用：每条重置链接只能使用一次
  //   3. "The action code is invalid"：通常是上述两种原因之一
  //   ✅ 解决方法：重新点击"忘记密码"，填入邮箱，发一封新邮件
  //
  // [TODO: 异常处理] 发送成功不代表用户一定收到邮件。邮件可能进垃圾箱。
  //   建议在 UI 层提示用户"如未收到，请检查垃圾邮件文件夹"。
  Future<AuthResult> sendPasswordResetEmail(String email,
      {bool isZh = false}) async {
    try {
      // 使用 Firebase 默认重置流程，不设 continueUrl
      // 好处：链接直接在 Firebase 托管页面处理，无浏览器兼容性问题
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code, isZh: isZh));
    } catch (e) {
      return AuthResult.failure(
          isZh ? '发送失败，请稍后重试' : 'Failed to send email, please try again');
    }
  }

  // ── 退出登录 ──────────────────────────────────────────────────────────────
  // 退出后 authStateChanges 推送 null，_AuthGate 自动跳转回 AuthScreen。
  // 移动端同时退出 Google Sign-In（清除 Google 账号选择缓存）。
  // Web 端不需要退出 Google Sign-In（Popup 模式下浏览器管理 Google session）。
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Firebase signOut 通常不会失败；即使失败也不影响本地状态清除
    }
    try {
      if (!kIsWeb) {
        // 移动端：清除 Google Sign-In 本地缓存，下次登录重新弹出账号选择
        await _googleSignIn.signOut();
      }
    } catch (_) {}
  }

  // ── 错误码 → 用户友好提示（中英文双语）──────────────────────────────────
  // Firebase Authentication 错误码文档：
  //   https://firebase.google.com/docs/auth/admin/errors
  // [TODO: 异常处理] 当前 default 分支返回通用提示，如需更精确的错误处理，
  //   可在此添加更多错误码映射。
  String _mapError(String code, {bool isZh = false}) {
    if (isZh) {
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
        case 'unauthorized-domain':
          return 'Google 登录需授权域名，请使用邮箱登录';
        default:
          return '操作失败，请稍后重试 ($code)';
      }
    } else {
      switch (code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password, please try again';
        case 'email-already-in-use':
          return 'This email is already registered';
        case 'weak-password':
          return 'Password too weak, use 6+ characters';
        case 'invalid-email':
          return 'Invalid email format';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts, please try again later';
        case 'network-request-failed':
          return 'Network error, please check connection';
        case 'invalid-credential':
          return 'Incorrect email or password';
        case 'unauthorized-domain':
          return 'Domain not authorized, please use email login';
        default:
          return 'Operation failed, please try again ($code)';
      }
    }
  }
}

// =============================================================================
// AuthResult — 认证操作的统一返回类型
// =============================================================================
// 封装目的：让 UI 层无需 try-catch，只检查 isSuccess 和 errorMessage。
// 所有认证方法都返回 AuthResult，保持 UI 层调用代码整洁一致。
class AuthResult {
  final bool isSuccess;
  final User? user; // 登录/注册成功时携带用户对象；失败或不需要时为 null
  final String? errorMessage; // 失败时的用户可读错误信息

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
