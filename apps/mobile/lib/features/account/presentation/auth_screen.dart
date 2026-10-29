import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/session_controller.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const minPasswordLength = 10;

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.register = false, super.key});

  final bool register;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late bool _register = widget.register;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionControllerProvider.notifier);
    try {
      if (_register) {
        await session.register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
          locale: LocaleNotifier.supportedCodes.contains(locale) ? locale : 'uz',
        );
      } else {
        await session.login(email: _email.text, password: _password.text);
      }
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = apiErrorText(l10n, error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_register ? l10n.accountCreate : l10n.accountSignIn)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (_register) ...[
                TextFormField(
                  key: const ValueKey('auth-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: l10n.authName),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextFormField(
                key: const ValueKey('auth-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l10n.authEmail),
                validator: (value) => _emailPattern.hasMatch(value?.trim() ?? '') ? null : l10n.authEmailInvalid,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const ValueKey('auth-password'),
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.authPassword,
                  helperText: _register ? l10n.authPasswordHint : null,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? l10n.authShowPassword : l10n.authHidePassword,
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return l10n.authPasswordRequired;
                  if (_register && password.length < minPasswordLength) return l10n.authPasswordShort;
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  key: const ValueKey('auth-error'),
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const ValueKey('auth-submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? l10n.accountCreate : l10n.accountSignIn),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('auth-switch'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                child: Text(_register ? l10n.authSwitchToSignIn : l10n.authSwitchToRegister),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(l10n.authSecurityNote, style: textTheme.bodySmall)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
