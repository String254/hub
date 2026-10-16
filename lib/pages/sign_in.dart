import 'dart:ui' show ImageFilter;
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sweet = NumberFormat("#,##0", "en_US");

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // THEME HELPERS
  // ============================================================

  static final Color _accent = Palette.nestBlue;

  static final Color _accentLight =
  Color.lerp(Palette.nestBlue, Colors.white, 0.32)!;

  static final Color _accentDeep =
  Color.lerp(Palette.nestBlue, Colors.black, 0.24)!;

  static final Color _ink =
  Color.lerp(Palette.nestBlue, const Color(0xFF0A1633), 0.55)!;

  // ============================================================
  // ANIMATION
  // ============================================================

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;

  // ============================================================
  // FORM
  // ============================================================

  final TextEditingController _userEmailController =
  TextEditingController();

  final TextEditingController _userPasswordController =
  TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool loading = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _loginUser() async {
    try {
      final response = await login(
        _userEmailController.text.trim(),
        _userPasswordController.text,
      );

      if (!mounted) return;

      if (response.error == null) {
        final User user = response.data as User;

        await _saveUserDetails(user);

        if (!mounted) return;

        await _saveThenRedirectToHome(user);
      } else {
        setState(() {
          loading = false;
        });

        Get.snackbar(
          'Sorry, try again',
          response.error!,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      Get.snackbar(
        'Sign in failed',
        'Unable to sign in. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      debugPrint('Login error: $e');
    }
  }

  // ============================================================
  // SAVE USER DETAILS
  // ============================================================

  Future<void> _saveUserDetails(User user) async {
    try {
      final SharedPreferences prefs =
      await SharedPreferences.getInstance();

      await prefs.setString('name', user.name);
      await prefs.setInt('userId', user.id);

      if (user.name.isNotEmpty) {
        final String firstName = user.name.split(' ')[0];

        await prefs.setString('first_name', firstName);
      }

      debugPrint('User details saved to SharedPreferences');
    } catch (e) {
      debugPrint('Error saving user details: $e');
    }
  }

  // ============================================================
  // SAVE TOKEN + REDIRECT
  // ============================================================

  Future<void> _saveThenRedirectToHome(User user) async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.setString('token', user.token!);
    await prefs.setInt('userId', user.id);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => NavigationSideBar(),
      ),
          (route) => false,
    );
  }

  // ============================================================
  // SUBMIT LOGIN
  // ============================================================

  void _submit() {
    if (formKey.currentState!.validate()) {
      setState(() {
        loading = true;
      });

      _loginUser();
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _showForgotPasswordDialog() async {
    final String initialEmail =
    _userEmailController.text.trim();

    final String? result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reset Password',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          ) {
        return _ForgotPasswordDialog(
          initialEmail: initialEmail,
          accent: _accent,
          accentLight: _accentLight,
          accentDeep: _accentDeep,
          ink: _ink,
        );
      },
      transitionBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
          ) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.94 + (0.06 * curved.value),
            child: Transform.translate(
              offset: Offset(
                0,
                22 * (1 - curved.value),
              ),
              child: child,
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.startsWith('success:')) {
      final String message =
      result.substring('success:'.length);

      Get.snackbar(
        'Password reset',
        message.isEmpty
            ? 'Password reset instructions have been sent to your email.'
            : message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } else if (result.startsWith('error:')) {
      final String message =
      result.substring('error:'.length);

      Get.snackbar(
        'Unable to reset password',
        message.isEmpty
            ? 'Unable to process your password reset request.'
            : message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

    _passwordVisible = false;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // ANIMATION HELPER
  // ============================================================

  Animation<double> _reveal(double begin, double end) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final double screenWidth =
        MediaQuery.of(context).size.width;

    final bool isCompact = screenWidth <= 1000;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ==================================================
            // ANIMATED BACKGROUND
            // ==================================================

            Positioned.fill(
              child: _buildBackground(),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 36,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCompact ? 440 : 470,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LOGO

                        _Reveal(
                          animation: _reveal(0.00, 0.55),
                          offset: 22,
                          scale: 0.86,
                          child: _buildLogoBadge(
                            isCompact,
                          ),
                        ),

                        SizedBox(
                          height: isCompact ? 26 : 32,
                        ),

                        // HEADING

                        _Reveal(
                          animation: _reveal(0.10, 0.62),
                          offset: 20,
                          child: _buildHeading(
                            isCompact,
                          ),
                        ),

                        SizedBox(
                          height: isCompact ? 26 : 32,
                        ),

                        // GLASS CARD

                        _Reveal(
                          animation: _reveal(0.22, 0.82),
                          offset: 26,
                          child: _buildGlassCard(),
                        ),

                        SizedBox(
                          height: isCompact ? 22 : 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final double t =
            _ambientController.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: Palette.background,
              ),
            ),

            _buildOrb(
              alignment: Alignment(
                -1.15 + (0.35 * t),
                -1.05 + (0.22 * t),
              ),
              size: 620,
              color: _accent,
              opacity: 0.22,
            ),

            _buildOrb(
              alignment: Alignment(
                1.22 - (0.28 * t),
                -0.72 + (0.34 * t),
              ),
              size: 500,
              color: _accentLight,
              opacity: 0.32,
            ),

            _buildOrb(
              alignment: Alignment(
                0.95 - (0.42 * t),
                1.18 - (0.26 * t),
              ),
              size: 680,
              color: _accent,
              opacity: 0.16,
            ),

            _buildOrb(
              alignment: Alignment(
                -1.08 + (0.22 * t),
                1.02 - (0.32 * t),
              ),
              size: 420,
              color: _accentLight,
              opacity: 0.26,
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrb({
    required Alignment alignment,
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGO BADGE
  // ============================================================

  Widget _buildLogoBadge(bool isCompact) {
    final double size = isCompact ? 104 : 122;

    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final double t =
            _ambientController.value;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.78),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(
                  alpha: 0.18 + (0.10 * t),
                ),
                blurRadius: 38 + (22 * t),
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 12),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
              ),
              child: Center(
                child: child,
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ============================================================
  // HEADING
  // ============================================================

  Widget _buildHeading(bool isCompact) {
    return Column(
      children: [
        Text(
          'Welcome back',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SF-Pro-Text-Regular',
            fontSize: isCompact ? 30 : 34,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Sign in to continue to your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SF-Pro-Text-Regular',
            fontSize: isCompact ? 14.5 : 15.5,
            color: _ink.withValues(alpha: 0.55),
            height: 1.5,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GLASS CARD
  // ============================================================

  Widget _buildGlassCard() {
    const double radius = 28;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.16),
            blurRadius: 46,
            spreadRadius: -10,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.4,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              26,
              30,
              26,
              26,
            ),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _buildForm() {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEmailField(),

          const SizedBox(height: 18),

          _buildPasswordField(),

          const SizedBox(height: 4),

          Align(
            alignment: Alignment.centerRight,
            child: _buildForgotPasswordButton(),
          ),

          const SizedBox(height: 16),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    double fontSize = 15,
  }) {
    OutlineInputBorder border(
        Color color,
        double width,
        ) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: false,

      labelStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: fontSize,
        color: _ink.withValues(alpha: 0.60),
      ),

      floatingLabelStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: fontSize - 1,
        fontWeight: FontWeight.w600,
        color: Palette.nestBlue,
      ),

      hintStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: fontSize,
        color: _ink.withValues(alpha: 0.28),
      ),

      prefixIcon: Padding(
        padding: const EdgeInsets.only(
          left: 4,
          right: 2,
        ),
        child: Icon(
          icon,
          size: 20,
          color: Palette.nestBlue.withValues(alpha: 0.85),
        ),
      ),

      prefixIconConstraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      border: border(
        Palette.nestBlue.withValues(alpha: 0.10),
        1,
      ),

      enabledBorder: border(
        Palette.nestBlue.withValues(alpha: 0.14),
        1,
      ),

      focusedBorder: border(
        Palette.nestBlue,
        1.6,
      ),

      errorBorder: border(
        Colors.red.shade300,
        1,
      ),

      focusedErrorBorder: border(
        Colors.red.shade400,
        1.6,
      ),

      errorStyle: const TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 12,
      ),
    );
  }

  // ============================================================
  // EMAIL FIELD
  // ============================================================

  Widget _buildEmailField() {
    return TextFormField(
      controller: _userEmailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        color: _ink,
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 15,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';

        if (email.isEmpty) {
          return 'Invalid email address';
        }

        return null;
      },
      decoration: _decoration(
        label: 'Email',
        hint: 'you@example.com',
        icon: BootstrapIcons.envelope,
      ),
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _userPasswordController,
      textCapitalization: TextCapitalization.none,
      obscureText: !_passwordVisible,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: _ink,
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 15,
      ),
      validator: (value) {
        if ((value ?? '').length < 5) {
          return 'Use at least 5 characters';
        }

        return null;
      },
      decoration: _decoration(
        label: 'Password',
        hint: '••••••••',
        icon: BootstrapIcons.lock,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            splashRadius: 20,
            icon: Icon(
              _passwordVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: _ink.withValues(alpha: 0.45),
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORGOT PASSWORD BUTTON
  // ============================================================

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _showForgotPasswordDialog,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Palette.nestBlue,
      ),
      child: const Text(
        'Forgot password?',
        style: TextStyle(
          color: Palette.nestBlue,
          fontSize: 13.5,
          fontFamily: 'SF-Pro-Text-Regular',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _buildSubmitButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: loading ? 0.85 : 1.0,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _accentLight,
              _accent,
              _accentDeep,
            ],
            stops: const [
              0.0,
              0.52,
              1.0,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.36),
              blurRadius: 26,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: loading ? null : _submit,
            splashColor: Colors.white.withValues(alpha: 0.16),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Center(
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: 'SF-Pro-Text-Regular',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// FORGOT PASSWORD DIALOG
// ================================================================

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.accent,
    required this.accentLight,
    required this.accentDeep,
    required this.ink,
  });

  final String initialEmail;

  final Color accent;
  final Color accentLight;
  final Color accentDeep;
  final Color ink;

  @override
  State<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState
    extends State<_ForgotPasswordDialog> {
  // ============================================================
  // DIALOG FORM CONTROLLERS
  // ============================================================

  late final TextEditingController _emailController;

  final GlobalKey<FormState> _resetFormKey =
  GlobalKey<FormState>();

  bool _isLoading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(
      text: widget.initialEmail,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    final FormState? form = _resetFormKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ApiResponse response = await forgotPassword(
        _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      if (response.error == null) {
        final String message =
            response.data?.toString() ??
                'Password reset instructions '
                    'have been sent to your email.';

        Navigator.of(context).pop(
          'success:$message',
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        _showInlineError(
          response.error ??
              'Unable to process your password reset request.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showInlineError(
        'Unable to process your password reset request.',
      );

      debugPrint(
        'Forgot password error: $e',
      );
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showInlineError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.red.shade600,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const double radius = 26;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  radius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.22),
                    blurRadius: 50,
                    spreadRadius: -12,
                    offset: const Offset(0, 24),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  radius,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 22,
                    sigmaY: 22,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(
                        radius,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ========================================
                        // GRADIENT ACCENT BAR
                        // ========================================

                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                widget.accentLight,
                                widget.accent,
                                widget.accentDeep,
                              ],
                              stops: const [
                                0.0,
                                0.5,
                                1.0,
                              ],
                            ),
                          ),
                        ),

                        // ========================================
                        // CONTENT
                        // ========================================

                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            26,
                            26,
                            26,
                            20,
                          ),
                          child: Form(
                            key: _resetFormKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                              children: [
                                // ==================================
                                // ICON BADGE
                                // ==================================

                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin:
                                        Alignment.topLeft,
                                        end: Alignment
                                            .bottomRight,
                                        colors: [
                                          widget.accentLight
                                              .withValues(
                                            alpha: 0.30,
                                          ),
                                          widget.accent
                                              .withValues(
                                            alpha: 0.16,
                                          ),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: widget.accent
                                            .withValues(
                                          alpha: 0.18,
                                        ),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.accent
                                              .withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 22,
                                          spreadRadius: -6,
                                          offset: const Offset(
                                            0,
                                            8,
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        BootstrapIcons.key,
                                        color: Palette.nestBlue,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // ==================================
                                // TITLE
                                // ==================================

                                Text(
                                  'Reset Password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily:
                                    'SF-Pro-Text-Regular',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: widget.ink,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // ==================================
                                // SUBTITLE
                                // ==================================

                                Text(
                                  'Enter the email associated with your '
                                      'account and we\'ll send a reset link.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily:
                                    'SF-Pro-Text-Regular',
                                    fontSize: 13.5,
                                    height: 1.55,
                                    color: widget.ink.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ==================================
                                // EMAIL
                                // ==================================

                                TextFormField(
                                  controller: _emailController,
                                  enabled: !_isLoading,
                                  keyboardType:
                                  TextInputType.emailAddress,
                                  textInputAction:
                                  TextInputAction.done,
                                  textCapitalization:
                                  TextCapitalization.none,
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) {
                                      _submit();
                                    }
                                  },
                                  style: TextStyle(
                                    color: widget.ink,
                                    fontFamily:
                                    'SF-Pro-Text-Regular',
                                    fontSize: 15,
                                  ),
                                  validator: (value) {
                                    final String email =
                                        value?.trim() ?? '';

                                    if (email.isEmpty) {
                                      return 'Please enter your email address';
                                    }

                                    final RegExp emailRegex =
                                    RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                    );

                                    if (!emailRegex
                                        .hasMatch(email)) {
                                      return 'Enter a valid email address';
                                    }

                                    return null;
                                  },
                                  decoration: _decoration(
                                    label: 'Email address',
                                    hint: 'you@example.com',
                                    icon: BootstrapIcons.envelope,
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // ==================================
                                // SUBMIT
                                // ==================================

                                _buildSubmitButton(),

                                const SizedBox(height: 6),

                                // ==================================
                                // CANCEL
                                // ==================================

                                Center(
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                      Navigator.of(
                                        context,
                                      ).pop();
                                    },
                                    style: TextButton.styleFrom(
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                      foregroundColor:
                                      widget.ink.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontFamily:
                                        'SF-Pro-Text-Regular',
                                        fontSize: 14,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: widget.ink
                                            .withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _buildSubmitButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isLoading ? 0.85 : 1.0,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              widget.accentLight,
              widget.accent,
              widget.accentDeep,
            ],
            stops: const [
              0.0,
              0.52,
              1.0,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.36),
              blurRadius: 26,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _submit,
            splashColor: Colors.white.withValues(alpha: 0.16),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Send Reset Link',
                style: TextStyle(
                  fontFamily: 'SF-Pro-Text-Regular',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    OutlineInputBorder border(
        Color color,
        double width,
        ) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,

      labelStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 15,
        color: widget.ink.withValues(alpha: 0.60),
      ),

      floatingLabelStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Palette.nestBlue,
      ),

      hintStyle: TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 15,
        color: widget.ink.withValues(alpha: 0.28),
      ),

      prefixIcon: Padding(
        padding: const EdgeInsets.only(
          left: 4,
          right: 2,
        ),
        child: Icon(
          icon,
          size: 20,
          color: Palette.nestBlue.withValues(alpha: 0.85),
        ),
      ),

      prefixIconConstraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),

      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),

      border: border(
        Palette.nestBlue.withValues(alpha: 0.10),
        1,
      ),

      enabledBorder: border(
        Palette.nestBlue.withValues(alpha: 0.14),
        1,
      ),

      focusedBorder: border(
        Palette.nestBlue,
        1.6,
      ),

      errorBorder: border(
        Colors.red.shade300,
        1,
      ),

      focusedErrorBorder: border(
        Colors.red.shade400,
        1.6,
      ),

      errorStyle: const TextStyle(
        fontFamily: 'SF-Pro-Text-Regular',
        fontSize: 12,
      ),
    );
  }
}

// ================================================================
// REVEAL WRAPPER
// ================================================================

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.offset = 24,
    this.scale = 1.0,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (
          context,
          child,
          ) {
        final double t = animation.value.clamp(
          0.0,
          1.0,
        );

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              0,
              offset * (1 - t),
            ),
            child: Transform.scale(
              scale: 1 + ((scale - 1) * (1 - t)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}