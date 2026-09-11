import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../provider/login_provider.dart';

/// Login screen. Authenticates a user against the `users` table
/// and reports the signed-in user (with role) via [onLoggedIn].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.provider, this.onLoggedIn});

  static const String routeName = '/login';

  final LoginProvider? provider;

  /// Called after a successful login.
  final ValueChanged<LoginProvider>? onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginProvider _provider = widget.provider ?? LoginProvider();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await _provider.login(
      _usernameController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (ok) {
      final user = _provider.currentUser!;
      widget.onLoggedIn?.call(_provider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user.displayName}  •  role: ${user.role}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ColoredBox(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
                  child: ListenableBuilder(
                    listenable: _provider,
                    builder: (context, _) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Brand(scheme: scheme),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              autofocus: true,
                              enabled: !_provider.loading,
                              onEditingComplete: () =>
                                  _passwordFocus.requestFocus(),
                              decoration: const InputDecoration(
                                hintText: 'Username',
                                prefixIcon: AppIcon(AppIcons.person_outline,
                                    size: 20),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your username'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscure,
                              enabled: !_provider.loading,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const AppIcon(AppIcons.lock_outline,
                                    size: 20),
                                suffixIcon: IconButton(
                                  tooltip:
                                      _obscure ? 'Show password' : 'Hide password',
                                  icon: AppIcon(
                                    _obscure
                                        ? AppIcons.visibility_outlined
                                        : AppIcons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            _ErrorBanner(message: _provider.error),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _provider.loading ? null : _submit,
                              child: _provider.loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Point of Sale • Desktop',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ],
                        ),
                      );
                    },
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

class _Brand extends StatelessWidget {
  const _Brand({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const AppIcon(AppIcons.point_of_sale, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome back',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to continue to your POS',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AppIcon(AppIcons.error_outline,
                      size: 20, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
