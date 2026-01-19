import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../../app/routes.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/profile.dart';
import '../providers/auth_provider.dart';

/// Sign up screen with email, password, name, and role selection.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  late final FormGroup _form;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _form = FormGroup({
      'fullName': FormControl<String>(
        validators: [Validators.required, Validators.minLength(2)],
      ),
      'email': FormControl<String>(
        validators: [Validators.required, Validators.email],
      ),
      'password': FormControl<String>(
        validators: [Validators.required, Validators.minLength(6)],
      ),
      'confirmPassword': FormControl<String>(
        validators: [Validators.required],
      ),
      'role': FormControl<String>(
        value: 'client',
        validators: [Validators.required],
      ),
    });

    // Add password match validation
    _form.control('confirmPassword').setValidators([
      Validators.required,
      Validators.delegate((control) {
        final password = _form.control('password').value;
        final confirm = control.value;
        return password == confirm ? null : {'mustMatch': true};
      }),
    ]);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_form.valid) {
      _form.markAllAsTouched();
      return;
    }

    final fullName = _form.control('fullName').value as String;
    final email = _form.control('email').value as String;
    final password = _form.control('password').value as String;
    final roleString = _form.control('role').value as String;
    final role = roleString == 'trainer' ? UserRole.trainer : UserRole.client;

    final success = await ref.read(authNotifierProvider.notifier).signUp(
          email: email,
          password: password,
          fullName: fullName,
          role: role,
        );

    if (success && mounted) {
      // Navigate based on role
      if (role == UserRole.trainer) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // Listen for auth errors
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError && next.error is Failure) {
        final failure = next.error! as Failure;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.displayMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ReactiveForm(
                formGroup: _form,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join FitnessFun today',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Role selection
                    Text(
                      'I am a...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ReactiveValueListenableBuilder<String>(
                      formControlName: 'role',
                      builder: (context, control, child) {
                        return SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'client',
                              label: Text('Client'),
                              icon: Icon(Icons.person_outlined),
                            ),
                            ButtonSegment(
                              value: 'trainer',
                              label: Text('Trainer'),
                              icon: Icon(Icons.sports_outlined),
                            ),
                          ],
                          selected: {control.value ?? 'client'},
                          onSelectionChanged: (selected) {
                            control.value = selected.first;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Full name field
                    ReactiveTextField<String>(
                      formControlName: 'fullName',
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validationMessages: {
                        'required': (error) => 'Name is required',
                        'minLength': (error) =>
                            'Name must be at least 2 characters',
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    ReactiveTextField<String>(
                      formControlName: 'email',
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validationMessages: {
                        'required': (error) => 'Email is required',
                        'email': (error) => 'Enter a valid email',
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    ReactiveTextField<String>(
                      formControlName: 'password',
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      validationMessages: {
                        'required': (error) => 'Password is required',
                        'minLength': (error) =>
                            'Password must be at least 6 characters',
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password field
                    ReactiveTextField<String>(
                      formControlName: 'confirmPassword',
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSignup(),
                      validationMessages: {
                        'required': (error) => 'Please confirm your password',
                        'mustMatch': (error) => 'Passwords do not match',
                      },
                    ),
                    const SizedBox(height: 32),

                    // Sign up button
                    FilledButton(
                      onPressed: isLoading ? null : _handleSignup,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 16),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Log In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
