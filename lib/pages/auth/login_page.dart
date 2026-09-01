import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/buttons.dart';
import '../../services/auth_manager.dart';
import '../navigation_shell.dart';
import '../../widgets/app_toast.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await AuthManager.login(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          AppToast.showSuccess(context, 'Login successful!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const NavigationShell()),
            (route) => false,
          );
        } else {
          AppToast.showError(context, AuthManager.lastLoginError ?? 'Login failed. Please check your credentials.');
        }
      }
    }
  }

  void _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
    });

    final success = await AuthManager.googleSignIn();

    if (mounted) {
      setState(() {
        _isGoogleLoading = false;
      });

      if (success) {
        AppToast.showSuccess(context, 'Google Sign-In successful!');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavigationShell()),
          (route) => false,
        );
      } else {
        AppToast.showError(context, AuthManager.lastGoogleError ?? 'Google Sign-In failed.');
      }
    }
  }

  void _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      AppToast.showInfo(context, 'Please enter your email first to reset password.');
      return;
    }
    
    setState(() => _isLoading = true);
    final success = await AuthManager.sendResetLink(_emailController.text);
    setState(() => _isLoading = false);
    
    if (mounted) {
      if (success) {
        AppToast.showSuccess(context, 'Password reset link sent to your email!');
      } else {
        AppToast.showError(context, AuthManager.lastForgotError ?? 'Failed to send reset link.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Image.asset('assets/logo.png', height: 72),
                  const SizedBox(height: 16),
                  Text(
                    'MindspaceNLP',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to access your secure storage',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Email
                  Text(
                    'Email Address',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter your email address',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  Text(
                    'Password',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Button
                  PrimaryButton(
                    text: 'Sign In',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 24),

                  // Or Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Login Button
                  _isGoogleLoading
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _handleGoogleLogin,
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                            height: 24,
                          ),
                          label: Text(
                            'Sign In with Google',
                            style: TextStyle(
                              fontWeight: FontWeight.w600, 
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                  
                  const SizedBox(height: 32),

                  // Don't have account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterPage())
                          );
                        },
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
