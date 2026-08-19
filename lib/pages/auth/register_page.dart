import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/buttons.dart';
import '../../services/auth_manager.dart';
import '../navigation_shell.dart';
import '../../widgets/app_toast.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeTerms) {
        AppToast.showInfo(context, 'Please agree to the Terms & Conditions');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final success = await AuthManager.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        mobileNo: _phoneController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          AppToast.showSuccess(context, 'Account created successfully!');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const NavigationShell()),
            (route) => false,
          );
        } else {
          AppToast.showError(context, 'Registration failed. Email address may already be in use.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                  Text(
                    'Create Account',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to get 10 GB of secure storage free',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  Text(
                    'Full Name',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email
                  Text(
                    'Email Address (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final emailVal = value?.trim() ?? '';
                      final phoneVal = _phoneController.text.trim();
                      if (emailVal.isEmpty && phoneVal.isEmpty) {
                        return 'Please enter either email or phone number';
                      }
                      if (emailVal.isNotEmpty) {
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailVal)) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter your email address',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Phone
                  Text(
                    'Phone Number (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final phoneVal = value?.trim() ?? '';
                      final emailVal = _emailController.text.trim();
                      if (phoneVal.isEmpty && emailVal.isEmpty) {
                        return 'Please enter either email or phone number';
                      }
                      if (phoneVal.isNotEmpty) {
                        if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phoneVal)) {
                          return 'Please enter a valid phone number (8-15 digits)';
                        }
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter phone number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
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
                    onFieldSubmitted: (_) => _handleRegister(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Create a password',
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
                  const SizedBox(height: 20),

                  // Terms & Conditions checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeTerms,
                        onChanged: (val) {
                          setState(() {
                            _agreeTerms = val ?? false;
                          });
                        },
                        activeColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms of Service & Privacy Policy',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Sign Up Button
                  PrimaryButton(
                    text: 'Create Account',
                    isLoading: _isLoading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 32),

                  // Already have account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
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
