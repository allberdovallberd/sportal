import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/sportal_api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/providers/auth_session_provider.dart';
import '../../ui/sportal_colors.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/sportal_background.dart';
import '../../ui/widgets/sportal_primary_button.dart';
import 'services/auth_api_client.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    super.key,
    this.initialEmail = '',
    this.initialPassword,
  });

  final String initialEmail;

  /// When provided the page auto-logs in after successful verification so the
  /// user enters the app as a fully-authenticated session owner.
  final String? initialPassword;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage>
    with WidgetsBindingObserver {
  static const int _codeLength = 6;
  static const double _maxBoxSize = 64;
  static const double _boxGap = 10;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasError = false;
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorText;
  String? _infoText;

  String get _email => widget.initialEmail.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestKeyboard();
    });
  }

  /// Requests focus and forces the system keyboard to appear.
  /// Plain [requestFocus] is a no-op when the node already holds focus
  /// (e.g. the OS hid the keyboard after the user switched apps).
  void _requestKeyboard() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-open keyboard after returning from another app (e.g. mail client).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestKeyboard();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    if (_hasError || _errorText != null || _infoText != null) {
      setState(() {
        _hasError = false;
        _errorText = null;
        _infoText = null;
      });
    } else {
      setState(() {});
    }

    // Auto-submit when 6 digits have been entered.
    if (value.trim().length == _codeLength &&
        _email.isNotEmpty &&
        !_isSubmitting) {
      _validateCode();
    }
  }

  Future<void> _validateCode() async {
    final l10n = context.l10n;
    final code = _codeController.text.trim();
    if (code.length != _codeLength || _email.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _hasError = false;
      _errorText = null;
      _infoText = null;
    });

    try {
      final authApi = ref.read(authApiClientProvider);
      await authApi.verifyEmail(email: _email, code: code);

      if (!mounted) return;

      final password = widget.initialPassword;
      if (password != null && password.isNotEmpty) {
        // Auto-login so the user enters the app as an authenticated session
        // owner rather than as a guest.
        try {
          final payload = await authApi.login(
            email: _email,
            password: password,
          );
          if (!mounted) return;
          ref.read(authSessionProvider.notifier).setSession(payload);

          try {
            final me = await authApi.fetchMe(accessToken: payload.accessToken);
            if (mounted) {
              ref.read(authSessionProvider.notifier).setUser(me);
            }
          } catch (_) {
            // If /users/me fails we still keep the session from login response.
          }
        } catch (_) {
          // Auto-login failed — fall through to login page so the user can
          // authenticate manually.
          if (!mounted) return;
          context.go('/login?email=${Uri.encodeQueryComponent(_email)}');
          return;
        }
      }

      if (!mounted) return;
      context.go('/home');
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorText = l10n.t('verificationInvalidCode');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    final l10n = context.l10n;
    if (_email.isEmpty || _isResending) return;

    setState(() {
      _isResending = true;
      _hasError = false;
      _errorText = null;
      _infoText = null;
    });

    try {
      final authApi = ref.read(authApiClientProvider);
      await authApi.resendCode(email: _email);
      if (!mounted) return;
      setState(() {
        _infoText = l10n.t('verificationResent');
      });
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorText = l10n.t('verificationResendFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = _codeController.text;
    final maxRowWidth = MediaQuery.sizeOf(context).width - 32;
    final computedBoxSize =
        (maxRowWidth - (_boxGap * (_codeLength - 1))) / _codeLength;
    final boxSize = math.min(_maxBoxSize, computedBoxSize.clamp(40.0, 64.0));
    final rowWidth = (boxSize * _codeLength) + (_boxGap * (_codeLength - 1));
    final emailText = _email.isEmpty
        ? l10n.t('verificationEmailMissing')
        : _email;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SportalBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _requestKeyboard,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/signup');
                                }
                              },
                              splashRadius: 18,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            l10n.t('verificationTitle'),
                            style: SportalTextStyles.h1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            l10n.format('verificationSubtitle', {
                              'email': emailText,
                            }),
                            style: SportalTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.32,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 38),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_codeLength, (index) {
                              final hasDigit = index < code.length;
                              final digit = hasDigit ? code[index] : '';
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == _codeLength - 1 ? 0 : _boxGap,
                                ),
                                child: RepaintBoundary(
                                  child: _OtpBox(
                                    digit: digit,
                                    hasError: _hasError,
                                    size: boxSize,
                                  ),
                                ),
                              );
                            }),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: rowWidth,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error,
                                      size: 16,
                                      color: SportalColors.errorRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errorText!,
                                        style: SportalTextStyles.t1.copyWith(
                                          color: SportalColors.errorRed,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_infoText != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: rowWidth,
                                child: Text(
                                  _infoText!,
                                  style: SportalTextStyles.t1.copyWith(
                                    color: SportalColors.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: rowWidth,
                              child: GestureDetector(
                                onTap: _resendCode,
                                child: Text(
                                  _isResending
                                      ? l10n.t('verificationResending')
                                      : l10n.t('verificationResend'),
                                  style: SportalTextStyles.b1.copyWith(
                                    color: SportalColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SportalPrimaryButton(
                            label: _isSubmitting
                                ? l10n.t('commonLoading')
                                : l10n.t('verificationVerify'),
                            enabled:
                                !_isSubmitting &&
                                _email.isNotEmpty &&
                                code.length == _codeLength,
                            onPressed: _validateCode,
                          ),
                          Offstage(
                            offstage: true,
                            child: TextField(
                              controller: _codeController,
                              focusNode: _focusNode,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(_codeLength),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              onChanged: _onCodeChanged,
                              onSubmitted: (_) => _validateCode(),
                            ),
                          ),
                        ],
                      ),
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.hasError,
    required this.size,
  });

  final String digit;
  final bool hasError;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2B55),
        borderRadius: BorderRadius.circular(12),
        border: hasError
            ? Border.all(color: SportalColors.errorRed, width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        digit,
        style: SportalTextStyles.h1.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: hasError ? SportalColors.errorRed : Colors.white,
        ),
      ),
    );
  }
}
