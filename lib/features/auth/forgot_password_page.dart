import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/sportal_api_exception.dart';
import '../../ui/sportal_colors.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/auth_text_field.dart';
import '../../ui/widgets/sportal_background.dart';
import '../../ui/widgets/sportal_primary_button.dart';
import 'services/auth_api_client.dart';

enum _ForgotPasswordStep { requestCode, verifyCode, resetPassword }

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  _ForgotPasswordStep _step = _ForgotPasswordStep.requestCode;
  String _submittedEmail = '';

  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _isResetting = false;

  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email) || _isSendingCode) {
      setState(() {
        _errorText = l10n.t('forgotPasswordValidEmail');
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorText = null;
    });

    try {
      await ref.read(authApiClientProvider).forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _submittedEmail = email;
        _step = _ForgotPasswordStep.verifyCode;
      });
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = l10n.t('forgotPasswordCodeSendFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  void _verifyCode() {
    final l10n = context.l10n;
    if (_isVerifyingCode) return;

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorText = l10n.t('forgotPasswordEnterCode');
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _errorText = null;
    });

    // Backend does not expose a separate endpoint for reset-code check.
    // Final code validation happens on /auth/reset-password.
    setState(() {
      _isVerifyingCode = false;
      _step = _ForgotPasswordStep.resetPassword;
    });
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    final email = _submittedEmail.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        code.length != 6 ||
        newPassword.length < 8 ||
        confirmPassword != newPassword ||
        _isResetting) {
      setState(() {
        _errorText = l10n.t('forgotPasswordValidInfo');
      });
      return;
    }

    setState(() {
      _isResetting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authApiClientProvider)
          .resetPassword(email: email, code: code, newPassword: newPassword);
      if (!mounted) return;
      context.go('/login');
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = l10n.t('forgotPasswordResetFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emailText = _submittedEmail.isEmpty
        ? _emailController.text.trim()
        : _submittedEmail;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SportalBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => context.go('/login'),
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOut,
                          child: SizedBox(height: keyboardOpen ? 12 : 36),
                        ),
                        Text(
                          l10n.t('forgotPasswordTitle'),
                          style: SportalTextStyles.h1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (_step == _ForgotPasswordStep.requestCode)
                          Text(
                            l10n.t('forgotPasswordPromptEmail'),
                            textAlign: TextAlign.center,
                            style: SportalTextStyles.b2.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          )
                        else
                          Text(
                            l10n.format('forgotPasswordPromptCode', {
                              'email': emailText,
                            }),
                            textAlign: TextAlign.center,
                            style: SportalTextStyles.b2.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.32,
                            ),
                          ),
                        const SizedBox(height: 28),
                        if (_step == _ForgotPasswordStep.requestCode) ...[
                          AuthTextField(
                            hintText: l10n.t('emailHint'),
                            controller: _emailController,
                            leadingSvgAsset: 'assets/icons/mail.svg',
                            leadingColor: SportalColors.textSecondary,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() {
                                  _errorText = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SportalPrimaryButton(
                            label: _isSendingCode
                                ? l10n.t('forgotPasswordSendingCode')
                                : l10n.t('forgotPasswordSendCode'),
                            enabled: !_isSendingCode,
                            onPressed: _sendCode,
                          ),
                        ],
                        if (_step == _ForgotPasswordStep.verifyCode) ...[
                          AuthTextField(
                            hintText: l10n.t('forgotPasswordCodeHint'),
                            controller: _codeController,
                            leadingIcon: Icons.verified_outlined,
                            leadingColor: SportalColors.textSecondary,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() {
                                  _errorText = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SportalPrimaryButton(
                            label: _isVerifyingCode
                                ? l10n.t('forgotPasswordConfirming')
                                : l10n.t('verificationVerify'),
                            enabled: !_isVerifyingCode,
                            onPressed: _verifyCode,
                          ),
                        ],
                        if (_step == _ForgotPasswordStep.resetPassword) ...[
                          AuthTextField(
                            hintText: l10n.t('forgotPasswordNewPasswordHint'),
                            controller: _newPasswordController,
                            leadingSvgAsset: 'assets/icons/lock-closed.svg',
                            leadingColor: SportalColors.textSecondary,
                            obscureText: _isNewPasswordObscured,
                            trailingIcon: _isNewPasswordObscured
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            trailingColor: SportalColors.textSecondary,
                            onTrailingTap: () {
                              setState(() {
                                _isNewPasswordObscured =
                                    !_isNewPasswordObscured;
                              });
                            },
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() {
                                  _errorText = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          AuthTextField(
                            hintText: l10n.t('confirmPasswordHintPlain'),
                            controller: _confirmPasswordController,
                            leadingSvgAsset: 'assets/icons/lock-closed.svg',
                            leadingColor: SportalColors.textSecondary,
                            obscureText: _isConfirmPasswordObscured,
                            trailingIcon: _isConfirmPasswordObscured
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            trailingColor: SportalColors.textSecondary,
                            onTrailingTap: () {
                              setState(() {
                                _isConfirmPasswordObscured =
                                    !_isConfirmPasswordObscured;
                              });
                            },
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() {
                                  _errorText = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          SportalPrimaryButton(
                            label: _isResetting
                                ? l10n.t('commonLoading')
                                : l10n.t('forgotPasswordReset'),
                            enabled: !_isResetting,
                            onPressed: _resetPassword,
                          ),
                        ],
                        if (_errorText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorText!,
                            style: SportalTextStyles.t1.copyWith(
                              color: SportalColors.errorRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
