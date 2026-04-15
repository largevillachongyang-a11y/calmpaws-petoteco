import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/locale_provider.dart';
import '../../screens/main_nav_screen.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen — 登录 / 注册 / 忘记密码 三合一页面
// firebaseAvailable: false 时为 Web 预览模式，按钮只做 UI 展示
// ─────────────────────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  final bool firebaseAvailable;
  const AuthScreen({super.key, this.firebaseAvailable = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

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
    setState(() {
      _mode = mode;
      _errorMsg = null;
      _successMsg = null;
    });
    _animController.reset();
    _animController.forward();
  }

  // ── 提交（Firebase 不可用时直接跳主页做 UI 预览）────────────────────────────
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
          // 不用手动跳转，_AuthGate 的 StreamBuilder 监听 authStateChanges，会自动切换到主页
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
          setState(() {
            _successMsg = isZh
                ? '重置邮件已发送，请查收邮箱。'
                : 'Reset email sent! Please check your inbox.';
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
    // Redirect 模式：调用后页面跳走，下面代码不再执行
    // 回来后由 _AuthGate.getRedirectResult() 处理
    await _authService.signInWithGoogle(isZh: isZh);
    if (mounted) setState(() => _loading = false);
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
    // Web 预览环境：Google Redirect 登录在沙盒里受网络限制无法完成
    // 正式 App（Android/iOS）原生 Google 登录完全正常
    if (kIsWeb && widget.firebaseAvailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.sageMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_iphone_rounded, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(
              s.locale == 'zh'
                  ? 'Google 登录仅限移动端 App'
                  : 'Google login available in mobile app',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    // 移动端 or Web 预览模式（firebaseAvailable=false）：正常显示按钮
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
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
