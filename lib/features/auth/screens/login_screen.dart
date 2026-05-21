import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/login_backdrop.dart';
import '../../../firebase_secrets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_providers.dart';
import '../widgets/auth_brand_panel.dart';
import '../widgets/auth_glass_input_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscure = true;
  String? _error;
  bool _loading = false;
  bool _showSignInForm = false;

  @override
  void initState() {
    super.initState();
    if (!FirebaseSecrets.isConfigured) {
      _error = _firebaseSetupMessage;
    }
    _loadRememberAndBiometric();
  }

  Future<void> _loadRememberAndBiometric() async {
    final data = await ref.read(authServiceProvider).getRememberMe();
    if (mounted) {
      setState(() {
        _rememberMe = data.remember;
        if (data.email != null) _emailController.text = data.email!;
      });
    }
    if (ref.read(skipBiometricOnLoginProvider)) {
      ref.read(skipBiometricOnLoginProvider.notifier).state = false;
      return;
    }
    final bio = ref.read(biometricServiceProvider);
    if (await bio.isEnabled()) {
      final creds = await bio.unlockCredentials();
      if (creds != null && mounted) {
        await _login(
          email: creds.email,
          password: creds.password,
          silent: true,
        );
      }
    }
  }

  static const _firebaseSetupMessage =
      'Firebase is not configured. Open lib/firebase_secrets.dart and paste '
      'your Project ID, API key, and App ID from Firebase Console → Project settings → Your apps.';

  Future<void> _login({
    String? email,
    String? password,
    bool silent = false,
  }) async {
    if (!_formKey.currentState!.validate() && !silent) return;
    if (!FirebaseSecrets.isConfigured) {
      if (!silent) setState(() => _error = _firebaseSetupMessage);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            email: email ?? _emailController.text,
            password: password ?? _passwordController.text,
            rememberMe: _rememberMe,
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (!silent) setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = AppException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LoginBackdrop(
        isDark: isDark,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final formCard = _LoginFormCard(
                isDark: isDark,
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                rememberMe: _rememberMe,
                obscure: _obscure,
                error: _error,
                loading: _loading,
                onRememberChanged: (v) => setState(() => _rememberMe = v),
                onObscureToggle: () => setState(() => _obscure = !_obscure),
                onLogin: () => _login(),
                onGoogleLogin: _googleLogin,
                onClose: () => setState(() => _showSignInForm = false),
              );

              if (wide) {
                return Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(child: AuthBrandPanel(isDark: isDark)),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    Positioned(
                      bottom: 28,
                      right: 28,
                      child: _SignInToggleButton(
                        visible: !_showSignInForm,
                        onPressed: () => setState(() => _showSignInForm = true),
                      ),
                    ),
                    if (_showSignInForm)
                      Positioned(
                        right: 40,
                        top: 0,
                        bottom: 0,
                        child: Center(child: formCard),
                      ),
                  ],
                );
              }
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            AuthBrandPanel(isDark: isDark, compact: true),
                            if (_showSignInForm) ...[
                              const SizedBox(height: 28),
                              formCard,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: _SignInToggleButton(
                      visible: !_showSignInForm,
                      onPressed: () => setState(() => _showSignInForm = true),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SignInToggleButton extends StatelessWidget {
  const _SignInToggleButton({
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Material(
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(
              Theme.of(context).brightness == Brightness.dark,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
        );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.isDark,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.obscure,
    required this.error,
    required this.loading,
    required this.onRememberChanged,
    required this.onObscureToggle,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.onClose,
  });

  final bool isDark;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final bool obscure;
  final String? error;
  final bool loading;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onObscureToggle;
  final VoidCallback onLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GlassCard.frosted(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        borderRadius: 24,
        child: Theme(
          data: authGlassInputTheme(context, isDark: isDark),
          child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue to your workspace',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: onObscureToggle,
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (v) => onRememberChanged(v ?? false),
                  ),
                  const Text('Remember me'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : onLogin,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
    );
  }
}
