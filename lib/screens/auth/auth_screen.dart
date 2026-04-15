import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/locale_provider.dart';
import '../../screens/main_nav_screen.dart';
import '../../theme/app_theme.dart';

// =============================================================================
// AuthScreen — 登录 / 注册 / 忘记密码 三合一认证页面
// =============================================================================
// 核心设计原则：
//   • 一个页面处理三种模式（_AuthMode），通过动画切换 → 减少路由跳转
//   • firebaseAvailable=false 时为 UI 预览模式（开发期无 Firebase 环境可用）
//   • 登录成功后 **不手动** 调用 Navigator.push，依赖 _AuthGate 的 StreamBuilder
//     自动路由到 MainNavScreen，这样退出登录也能正常回来。
//   • 错误/成功消息统一通过 _errorMsg / _successMsg 状态显示在表单下方
// =============================================================================
class AuthScreen extends StatefulWidget {
  // firebaseAvailable: 控制页面工作模式
  //   true  → 真实 Firebase 模式（生产/测试环境）
  //   false → 纯 UI 预览模式（Firebase 初始化失败时的降级方案）
  final bool firebaseAvailable;
  const AuthScreen({super.key, this.firebaseAvailable = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// 页面的三种工作模式，通过 _switchMode 切换，切换时触发 fade 动画
enum _AuthMode { login, register, forgotPassword }

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMsg;
  String? _successMsg;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    // 切换模式时清除上一次的错误/成功消息，避免模式间消息串行
    setState(() {
      _mode = mode;
      _errorMsg = null;
      _successMsg = null;
    });
    // 重置动画，让新模式内容以 fade-in 方式出现
    _animController.reset();
    _animController.forward();
  }

  // ── 提交表单 ──────────────────────────────────────────────────────────────
  // 根据当前 _mode 调用不同的 AuthService 方法：
  //   login        → signInWithEmail → 成功后 _AuthGate 自动跳主页
  //   register     → signUpWithEmail → 成功后切换到 login 模式并显示提示
  //   forgotPassword → sendPasswordResetEmail → 成功后显示"邮件已发送"提示
  //
  // 预览模式（firebaseAvailable=false）：
  //   直接跳 MainNavScreen，用于开发期测试 UI 而无需真实账号
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Web 预览模式：直接跳主页，不调用 Firebase
    if (!widget.firebaseAvailable) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
      return;
    }

    final s = context.read<LocaleProvider>().strings;
    final isZh = s.locale == 'zh';

    setState(() {
      _loading = true;
      _errorMsg = null;
      _successMsg = null;
    });

    AuthResult result;

    switch (_mode) {
      case _AuthMode.login:
        result = await _authService.signInWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          isZh: isZh,
        );
        if (result.isSuccess && mounted) {
          // ✅ 登录成功：不手动跳转！
          // Firebase authStateChanges 会推送新 User，_AuthGate 的 StreamBuilder
          // 自动重建并显示 MainNavScreen。这样退出登录也能正常回到此页面。
          setState(() => _loading = false);
          return;
        }
        break;
      case _AuthMode.register:
        result = await _authService.signUpWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text,
          isZh: isZh,
        );
        if (result.isSuccess) {
          // 注册成功后切回登录模式，让用户主动登录（也可改为自动登录）
          // [TODO: 异常处理] 如需强制验证邮箱才能登录，此处可加逻辑提示用户先点验证邮件
          setState(() {
            _successMsg = isZh
                ? '注册成功！请查收验证邮件，验证后即可登录。'
                : 'Account created! Please check your email to verify.';
            _loading = false;
          });
          _switchMode(_AuthMode.login);
          return;
        }
        break;
      case _AuthMode.forgotPassword:
        result = await _authService.sendPasswordResetEmail(
          _emailCtrl.text,
          isZh: isZh,
        );
        if (result.isSuccess) {
          // 发送成功：显示提示，用户需去邮箱点击链接
          // ⚠️ 重置链接有效期1小时；链接指向 Firebase 托管页面，若遇网络问题可能无法打开
          setState(() {
            _successMsg = isZh
                ? '重置邮件已发送！\n请查收邮箱并点击链接（链接1小时内有效）。\n若链接无法打开，请使用正常网络环境或稍后重试。'
                : 'Reset email sent!\nCheck your inbox and click the link (expires in 1 hour).\nIf link fails to open, try on a different network.';
            _loading = false;
          });
          return;
        }
        break;
    }

    setState(() {
      _loading = false;
      if (!result.isSuccess) _errorMsg = result.errorMessage;
    });
  }

  // ── Google登录 ────────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    if (!widget.firebaseAvailable) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
      return;
    }
    final isZh = context.read<LocaleProvider>().strings.locale == 'zh';
    setState(() { _loading = true; _errorMsg = null; });
    // Popup 模式：等待弹窗结果后继续
    // COOP 警告 "window.closed would be blocked" 是正常现象，不影响登录
    // 登录成功后 _AuthGate 的 StreamBuilder 会自动跳转到主页
    final result = await _authService.signInWithGoogle(isZh: isZh);
    if (!mounted) return;
    if (!result.isSuccess && result.errorMessage != null) {
      // 只在真正失败时显示错误（取消登录不算错误）
      final msg = result.errorMessage!;
      if (!msg.contains('取消') && !msg.contains('cancelled')) {
        setState(() { _loading = false; _errorMsg = msg; });
      } else {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final isLogin = _mode == _AuthMode.login;
    final isRegister = _mode == _AuthMode.register;
    final isForgot = _mode == _AuthMode.forgotPassword;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            // ── 右上角语言切换 ──────────────────────────────────────────────
            Positioned(
              top: 8,
              right: 16,
              child: GestureDetector(
                onTap: () => context.read<LocaleProvider>().toggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.watch<LocaleProvider>().languageFlag,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.watch<LocaleProvider>().languageLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── 主内容区 ────────────────────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  // ── Logo ──────────────────────────────────────────────────
                  _buildLogo(),
                  const SizedBox(height: 32),

                  // Web预览提示条
                  if (!widget.firebaseAvailable)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmberMuted,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.warningAmber, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.warningAmber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Web 预览模式 · 点击任意按钮可直接进入主页',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.warningAmber,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── 标题 ──────────────────────────────────────────────────
                  Text(
                    isForgot
                        ? s.authForgotTitle
                        : isRegister
                            ? s.authRegisterTitle
                            : s.authLoginTitle,
                    style: AppTextStyles.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isForgot
                        ? s.authForgotSubtitle
                        : isRegister
                            ? s.authRegisterSubtitle
                            : s.authLoginSubtitle,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // ── 表单 ──────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (isRegister) ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            label: s.authName,
                            icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? s.authNameRequired
                                : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildTextField(
                          controller: _emailCtrl,
                          label: s.authEmail,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return s.authEmailRequired;
                            if (!v.contains('@')) return s.authEmailInvalid;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        if (!isForgot) ...[
                          _buildTextField(
                            controller: _passwordCtrl,
                            label: s.authPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            toggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return s.authPasswordRequired;
                              if (isRegister && v.length < 6)
                                return s.authPasswordTooShort;
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (isRegister) ...[
                          _buildTextField(
                            controller: _confirmPasswordCtrl,
                            label: s.authConfirmPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            toggleObscure: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v != _passwordCtrl.text)
                                return s.authPasswordMismatch;
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),

                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _switchMode(_AuthMode.forgotPassword),
                        child: Text(
                          s.authForgotLink,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.sageGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  if (_errorMsg != null)
                    _buildMessage(_errorMsg!, isError: true),
                  if (_successMsg != null)
                    _buildMessage(_successMsg!, isError: false),

                  const SizedBox(height: 8),

                  // ── 主按钮 ────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        overlayColor: Colors.transparent,
                        backgroundColor: AppColors.sageGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isForgot
                                  ? s.authSendReset
                                  : isRegister
                                      ? s.authRegisterBtn
                                      : s.authLoginBtn,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),

                  // ── 注册/登录切换（紧靠主按钮下方，最显眼）─────────────────
                  if (!isForgot) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLogin ? s.authNoAccount : s.authHasAccount,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _switchMode(
                              isLogin ? _AuthMode.register : _AuthMode.login),
                          child: Text(
                            isLogin ? s.authRegisterLink : s.authLoginLink,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.sageGreen,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.sageGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Google 登录 ───────────────────────────────────────────
                  if (!isForgot) ...[
                    const SizedBox(height: 20),
                    _buildDivider(s.authOr),
                    const SizedBox(height: 14),
                    _buildGoogleButton(s),
                  ],

                  const SizedBox(height: 20),

                  if (isForgot)
                    GestureDetector(
                      onTap: () => _switchMode(_AuthMode.login),
                      child: Text(
                        s.authBackToLogin,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.sageGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
          ],  // Stack children 结束
        ),    // Stack 结束
      ),      // SafeArea 结束
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.sageMuted,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.sageGreen.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Center(
            child: Text('🐾', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Petoteco',
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.sageGreen,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Smart Pet Health',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.labelMedium,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: toggleObscure != null
            ? GestureDetector(
                onTap: toggleObscure,
                child: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.alertRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.alertRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: AppTextStyles.labelSmall),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }

  Widget _buildGoogleButton(dynamic s) {
    // ── Web 沙盒预览：Firebase 已连接但网络无法访问 firebaseapp.com ──────────
    // Web + 移动端 统一显示可点击的 Google 登录按钮
    // Web 端使用 signInWithPopup，域名已在 Firebase Authorized Domains 中授权
    // 移动端使用原生 Google Sign-In SDK
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _loading ? null : _googleSignIn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('G',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4285F4))),
              const SizedBox(width: 10),
              Text(
                s.authGoogleBtn,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.alertRedMuted : AppColors.successMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? AppColors.alertRed : AppColors.successGreen,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.alertRed : AppColors.successGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: isError ? AppColors.alertRed : AppColors.successGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
