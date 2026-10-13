import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/common/password_recovery_flow.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/message_helper.dart';
import 'package:attendance_app/utils/app_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isProcessingLogin = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward();
  }

  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_isProcessingLogin) return;

    _isProcessingLogin = true;
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => isLoading = false);
      _isProcessingLogin = false;
      MessageHelper.showWarning(context, 'Please enter email and password');
      return;
    }

    // Play Store Review Bypass Credentials Check
    if ((email == 'playstore.test@workzi.app' || 
         email == 'google.reviewer@workzi.app' || 
         email == 'playstore@workzi.com' ||
         email == 'demo@workzi.app') &&
        (password == 'Playstore@2026' || password == 'workzi1234' || password == 'demo1234')) {
      _bypassDemoLogin(role: 'super_admin');
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final currentUser = credential.user!;
      await currentUser.getIdToken(true);

      // Session population and routing is now fully handled by AuthWrapper.

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No account found for this email. Please contact your administrator.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for this email. Please sign in instead.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      if (mounted) {
        MessageHelper.showError(context, message);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        MessageHelper.showError(context, 'Login failed. Please try again.');
      }
    } finally {
      _isProcessingLogin = false;
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _bypassDemoLogin({String role = 'super_admin'}) {
    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    // Initialize full bypass mock session for Play Store review team
    AppSession().clear();
    AppSession().isDemoMode = true;
    AppSession().populate(
      uid: 'playstore_demo_reviewer',
      email: 'playstore.reviewer@workzi.app',
      role: role,
      companyId: 'demo_organization',
      companyName: 'Workzi Demo Enterprise',
      userName: role == 'super_admin' ? 'Google Play Reviewer (Admin)' : 'Google Play Reviewer',
      department: 'Quality Assurance & Review',
      officeLat: 13.0827,
      officeLng: 80.2707,
      allowedRadius: 10000,
      shiftStartTime: '09:00',
      shiftEndTime: '18:00',
      gracePeriod: 30,
      paidLeavesPerYear: 24,
    );

    if (mounted) {
      setState(() => isLoading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 22,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 22),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/signin logo.png',
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Attendance',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'OS',
                                      style: TextStyle(
                                        color: Color(0xFF5C5CFF),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Welcome Back',
                            style: AppTheme.h1.copyWith(
                              fontSize: 28,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to your account to continue',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildInputField(
                            controller: emailController,
                            focusNode: _emailFocus,
                            hint: 'Work Email',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(
                            controller: passwordController,
                            focusNode: _passwordFocus,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            isVisible: _isPasswordVisible,
                            onToggleVisibility: () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PasswordRecoveryFlow(
                                      isChangePassword: false,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF5C5CFF),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: SizedBox(
                              width: 327,
                              height: 51,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C5CFF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: isLoading ? null : () => _bypassDemoLogin(role: 'super_admin'),
                              icon: const Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: Color(0xFF6B7280),
                              ),
                              label: const Text(
                                'Play Store Review Access (Demo Mode)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
  }) {
    final isFocused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? AppTheme.primary : const Color(0xFFE5E7EB),
          width: isFocused ? 1.4 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: isPassword && !isVisible,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF667085),
          ),
          prefixIcon: Icon(
            icon,
            size: 20,
            color: isFocused ? AppTheme.primary : const Color(0xFF667085),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF667085),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
