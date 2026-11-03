import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/repositories.dart';
import '../../core/errors/app_error.dart';
import '../../core/config/app_config.dart';
import '../../widgets/common.dart';
import '../../widgets/brand_logo.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, required this.mode});
  final String mode;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, accepted = false, hidden = true, resetSent = false;
  final passwordFocus = FocusNode();
  final confirmationFocus = FocusNode();
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    passwordFocus.dispose();
    confirmationFocus.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (widget.mode == 'register' && !accepted) {
      setState(
        () => error = 'Please read and accept the privacy policy and terms.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (widget.mode == 'register') {
        final sent = await auth.register(name.text, email.text, password.text);
        if (!sent && mounted) {
          notify(
            context,
            'Account created. Request another verification email from Overview.',
          );
        }
      } else if (widget.mode == 'forgot-password') {
        await auth.reset(email.text);
        if (mounted) setState(() => resetSent = true);
      } else {
        await auth.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.mode == 'register',
        reset = widget.mode == 'forgot-password';
    final title = register
        ? 'Make room for a healthier you.'
        : reset
        ? 'Let’s get you back in.'
        : 'Good to see you again.';
    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: () => context.go('/'),
          child: const BrandLogo(width: 150),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Panel(
              child: Form(
                key: form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(width: 230)),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reset
                            ? 'We’ll send a reset link if an account exists.'
                            : 'Your food, your progress, your own pace.',
                      ),
                      const SizedBox(height: 24),
                      if (!AppConfig.production)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Development environment · use test accounts only.',
                          ),
                        ),
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                          ),
                          maxLength: 80,
                          autofillHints: const [AutofillHints.name],
                          validator: requiredText,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: email,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: validEmail,
                      ),
                      const SizedBox(height: 16),
                      if (!reset) ...[
                        TextFormField(
                          controller: password,
                          focusNode: passwordFocus,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: hidden,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              // Keep keyboard editing in the field after an eye click.
                              onPressed: () {
                                final focus = confirmationFocus.hasFocus
                                    ? confirmationFocus
                                    : passwordFocus;
                                setState(() => hidden = !hidden);
                                focus.requestFocus();
                              },
                              tooltip: hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter your password'
                              : register && v.length < 12
                              ? 'Use at least 12 characters'
                              : null,
                          onFieldSubmitted: (_) {
                            if (!register && !busy) submit();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (register) ...[
                        TextFormField(
                          controller: confirmation,
                          focusNode: confirmationFocus,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: hidden,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          validator: (v) => v != password.text
                              ? 'Passwords must match'
                              : null,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: accepted,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => accepted = v!),
                          title: const Text(
                            'I accept the privacy policy and terms.',
                          ),
                        ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => context.push('/privacy'),
                              child: const Text('Privacy policy'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/terms'),
                              child: const Text('Terms of service'),
                            ),
                          ],
                        ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(error!),
                        ),
                      if (resetSent)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Check your inbox. If an account exists, a password reset link has been sent.',
                          ),
                        ),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                register
                                    ? 'Create account'
                                    : reset
                                    ? 'Send reset link'
                                    : 'Sign in',
                              ),
                      ),
                      if (!reset && !register)
                        TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          child: const Text('Forgot password?'),
                        ),
                      TextButton(
                        onPressed: () => context.go(
                          register || reset ? '/login' : '/register',
                        ),
                        child: Text(
                          register || reset
                              ? 'Back to sign in'
                              : 'New here? Create an account',
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
    );
  }
}
