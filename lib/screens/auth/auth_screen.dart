import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen — 登录/注册/忘记密码 三合一页面
// ─────────────────────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, register, forgotPassword }

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
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

  // ── 提交表单 ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
        );
        break;
      case _AuthMode.register:
        result = await _authService.signUpWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text,
        );
        if (result.isSuccess) {
          setState(() {
            _successMsg = '注册成功！请查收验证邮件，验证后即可登录。';
            _loading = false;
          });
          _switchMode(_AuthMode.login);
          return;
        }
        break;
      case _AuthMode.forgotPassword:
        result = await _authService.sendPasswordResetEmail(_emailCtrl.text);
        if (result.isSuccess) {
          setState(() {
            _successMsg = '重置邮件已发送，请查收邮箱。';
            _loading = false;
          });
          return;
        }
        break;
    }

    setState(() {
      _loading = false;
      if (!result.isSuccess) {
        _errorMsg = result.errorMessage;
      }
    });
  }

  // ── Google登录 ────────────────────────────────────────────────────────────
  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final result = await _authService.signInWithGoogle();
    setState(() {
      _loading = false;
      if (!result.isSuccess) {
        _errorMsg = result.errorMessage;
      }
    });
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo区域 ───────────────────────────────────────────────
                  _buildLogo(),
                  const SizedBox(height: 32),

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
                        // 昵称（仅注册时显示）
                        if (isRegister) ...[
                          _buildTextField(
                            controller: _nameCtrl,
                            label: s.authName,
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? s.authNameRequired : null,
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 邮箱
                        _buildTextField(
                          controller: _emailCtrl,
                          label: s.authEmail,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return s.authEmailRequired;
                            if (!v.contains('@')) return s.authEmailInvalid;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 密码（忘记密码时不显示）
                        if (!isForgot) ...[
                          _buildTextField(
                            controller: _passwordCtrl,
                            label: s.authPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            toggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            validator: (v) {
                              if (v == null || v.isEmpty) return s.authPasswordRequired;
                              if (isRegister && v.length < 6) return s.authPasswordTooShort;
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 确认密码（仅注册时）
                        if (isRegister) ...[
                          _buildTextField(
                            controller: _confirmPasswordCtrl,
                            label: s.authConfirmPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            toggleObscure: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v != _passwordCtrl.text) return s.authPasswordMismatch;
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),

                  // 忘记密码链接（仅登录时显示）
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

                  // 错误提示
                  if (_errorMsg != null) _buildMessage(_errorMsg!, isError: true),
                  if (_successMsg != null) _buildMessage(_successMsg!, isError: false),

                  const SizedBox(height: 8),

                  // ── 主按钮 ────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(

                        overlayColor: Colors.transparent,                        backgroundColor: AppColors.sageGreen,
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

                  // Google登录（仅登录和注册页显示）
                  if (!isForgot) ...[
                    const SizedBox(height: 14),
                    _buildDivider(s.authOr),
                    const SizedBox(height: 14),
                    _buildGoogleButton(s),
                  ],

                  const SizedBox(height: 24),

                  // ── 切换登录/注册 ─────────────────────────────────────────
                  if (!isForgot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLogin ? s.authNoAccount : s.authHasAccount,
                          style: AppTextStyles.bodySmall,
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
                            ),
                          ),
                        ),
                      ],
                    ),

                  // 返回登录（忘记密码页）
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
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────
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
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.sageGreen,
            letterSpacing: 1,
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

  // ── 输入框 ────────────────────────────────────────────────────────────────
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
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.alertRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.alertRed, width: 1.5),
        ),
      ),
    );
  }

  // ── 分割线 ────────────────────────────────────────────────────────────────
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

  // ── Google按钮 ────────────────────────────────────────────────────────────
  Widget _buildGoogleButton(dynamic s) {
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
              // Google G 图标
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Text('G',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4285F4))),
              ),
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

  // ── 消息提示 ──────────────────────────────────────────────────────────────
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
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
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
