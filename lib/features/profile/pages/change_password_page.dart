import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_primary_button.dart';
import '../../../ui/widgets/sportal_section_card.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../../auth/services/auth_api_client.dart';

/// Change-password screen.
///
/// Backend exposes only the email-code reset flow (see API_ENDPOINTS.md
/// §1.6 / §1.7). For an authenticated change we route through the same
/// forgot/reset flow: we trigger `/auth/forgot-password` on entry, then call
/// `/auth/reset-password` once the user enters the emailed code and the new
/// password.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _sendingCode = false;
  bool _submitting = false;
  String? _error;
  String? _info;
  bool _codeSent = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final auth = ref.read(authSessionProvider);
    if (auth.user.email.isEmpty) {
      setState(() => _error = l10n.t('changePasswordEmailMissing'));
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
      _info = null;
    });
    try {
      final api = ref.read(authApiClientProvider);
      await api.forgotPassword(email: auth.user.email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = l10n.format('changePasswordCodeSent', {
          'email': auth.user.email,
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = l10n.format('changePasswordSendFailed', {'error': '$e'}),
      );
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final auth = ref.read(authSessionProvider);
    final code = _codeController.text.trim();
    final pw = _passwordController.text;
    final confirm = _confirmController.text;

    if (code.isEmpty || pw.isEmpty || confirm.isEmpty) {
      setState(() => _error = l10n.t('changePasswordEmptyFields'));
      return;
    }
    if (pw != confirm) {
      setState(() => _error = l10n.t('changePasswordMismatch'));
      return;
    }
    if (pw.length < 8) {
      setState(() => _error = l10n.t('changePasswordTooShort'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final api = ref.read(authApiClientProvider);
      await api.resetPassword(
        email: auth.user.email,
        code: code,
        newPassword: pw,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('changePasswordSuccess'))));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = l10n.format('changePasswordFailed', {'error': '$e'}),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('changePasswordTitle'),
                subtitle: l10n.t('changePasswordSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 22),
              SportalSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('changePasswordStepOneTitle'),
                      style: SportalTextStyles.b1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('changePasswordStepOneBody'),
                      style: SportalTextStyles.b2.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SportalPrimaryButton(
                      label: _sendingCode
                          ? l10n.t('changePasswordSending')
                          : (_codeSent
                                ? l10n.t('changePasswordResendCode')
                                : l10n.t('changePasswordSendCode')),
                      enabled: !_sendingCode,
                      onPressed: _sendCode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SportalSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('changePasswordStepTwoTitle'),
                      style: SportalTextStyles.b1.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _codeController,
                      hint: l10n.t('changePasswordCodeHint'),
                      icon: Icons.shield_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _passwordController,
                      hint: l10n.t('changePasswordNewPassword'),
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _confirmController,
                      hint: l10n.t('changePasswordConfirmPassword'),
                      icon: Icons.lock_reset_rounded,
                      obscure: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: SportalTextStyles.t1.copyWith(
                          color: SportalColors.errorRed,
                        ),
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _info!,
                        style: SportalTextStyles.t1.copyWith(
                          color: SportalColors.primaryBlue,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SportalPrimaryButton(
                      label: _submitting
                          ? l10n.t('commonLoading')
                          : l10n.t('forgotPasswordReset'),
                      enabled: !_submitting && _codeSent,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: SportalTextStyles.b1.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: SportalTextStyles.b2.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
