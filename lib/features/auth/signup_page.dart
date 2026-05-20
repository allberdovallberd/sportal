import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/sportal_api_exception.dart';
import '../../ui/sportal_colors.dart';
import '../../ui/sportal_text_styles.dart';
import '../../ui/widgets/auth_text_field.dart';
import '../../ui/widgets/sportal_background.dart';
import '../../ui/widgets/sportal_logo.dart';
import '../../ui/widgets/sportal_primary_button.dart';
import 'auth_form_controller.dart';
import 'services/auth_api_client.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;
  bool _isSubmitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    ref.read(signUpFormControllerProvider.notifier).reset();
    final state = ref.read(signUpFormControllerProvider);
    _usernameController = TextEditingController(text: state.username);
    _emailController = TextEditingController(text: state.email);
    _passwordController = TextEditingController(text: state.password);
    _confirmController = TextEditingController(text: state.confirmPassword);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final l10n = context.l10n;
    final controller = ref.read(signUpFormControllerProvider.notifier);
    controller.submit();
    final state = ref.read(signUpFormControllerProvider);
    if (!state.canContinue) return;

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    try {
      final authApi = ref.read(authApiClientProvider);
      await authApi.register(
        username: state.username,
        email: state.email,
        password: state.password,
      );

      if (!mounted) return;
      context.go(
        '/verify-email?email=${Uri.encodeQueryComponent(state.email.trim())}',
        extra: state.password,
      );
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverError = l10n.t('signupFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(signUpFormControllerProvider);
    final controller = ref.read(signUpFormControllerProvider.notifier);
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
                      mainAxisSize: MainAxisSize.min,
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
                          alignment: Alignment.topCenter,
                          child: keyboardOpen
                              ? const SizedBox(height: 8)
                              : Column(
                                  children: const [
                                    SizedBox(height: 34),
                                    Center(child: SportalLogo(size: 150)),
                                    SizedBox(height: 42),
                                  ],
                                ),
                        ),
                        Text(
                          l10n.t('signupTitle'),
                          style: SportalTextStyles.h1,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: keyboardOpen ? 16 : 32),
                        AuthTextField(
                          hintText: l10n.t('signupUsernameHint'),
                          controller: _usernameController,
                          leadingIcon: Icons.person_rounded,
                          leadingColor:
                              state.hasUsernameRequiredError ||
                                  state.hasUsernameError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          isError:
                              state.hasUsernameRequiredError ||
                              state.hasUsernameError,
                          keyboardType: TextInputType.text,
                          onChanged: (value) {
                            controller.setUsername(value);
                            if (_serverError != null) {
                              setState(() {
                                _serverError = null;
                              });
                            }
                          },
                        ),
                        if (state.hasUsernameRequiredError ||
                            state.hasUsernameError) ...[
                          const SizedBox(height: 6),
                          _FieldError(
                            message: state.hasUsernameRequiredError
                                ? l10n.t('signupEnterUsername')
                                : l10n.t('signupUsernameTooShort'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AuthTextField(
                          hintText: l10n.t('emailHint'),
                          controller: _emailController,
                          leadingSvgAsset: 'assets/icons/mail.svg',
                          leadingColor:
                              state.hasEmailRequiredError ||
                                  state.hasEmailFormatError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          isError:
                              state.hasEmailRequiredError ||
                              state.hasEmailFormatError,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            controller.setEmail(value);
                            if (_serverError != null) {
                              setState(() {
                                _serverError = null;
                              });
                            }
                          },
                        ),
                        if (state.hasEmailRequiredError ||
                            state.hasEmailFormatError) ...[
                          const SizedBox(height: 6),
                          _FieldError(
                            message: state.hasEmailRequiredError
                                ? l10n.t('signupEnterEmail')
                                : l10n.t('signupEnterValidEmail'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AuthTextField(
                          hintText: l10n.t('passwordHint'),
                          controller: _passwordController,
                          leadingSvgAsset: 'assets/icons/lock-closed.svg',
                          leadingColor:
                              state.hasPasswordRequiredError ||
                                  state.hasPasswordError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          isError:
                              state.hasPasswordRequiredError ||
                              state.hasPasswordError,
                          obscureText: state.isPasswordObscured,
                          trailingIcon: state.isPasswordObscured
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          trailingColor:
                              state.hasPasswordRequiredError ||
                                  state.hasPasswordError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          onTrailingTap: controller.togglePasswordObscure,
                          onChanged: (value) {
                            controller.setPassword(value);
                            if (_serverError != null) {
                              setState(() {
                                _serverError = null;
                              });
                            }
                          },
                        ),
                        if (state.hasPasswordRequiredError ||
                            state.hasPasswordError) ...[
                          const SizedBox(height: 6),
                          _FieldError(
                            message: state.hasPasswordRequiredError
                                ? l10n.t('signupEnterPassword')
                                : l10n.t('signupPasswordMin'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AuthTextField(
                          hintText: l10n.t('confirmPasswordHint'),
                          controller: _confirmController,
                          leadingSvgAsset: 'assets/icons/lock-closed.svg',
                          leadingColor:
                              state.hasConfirmRequiredError ||
                                  state.hasConfirmError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          isError:
                              state.hasConfirmRequiredError ||
                              state.hasConfirmError,
                          obscureText: state.isConfirmObscured,
                          trailingIcon: state.isConfirmObscured
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          trailingColor:
                              state.hasConfirmRequiredError ||
                                  state.hasConfirmError
                              ? SportalColors.errorRed
                              : SportalColors.textSecondary,
                          onTrailingTap: controller.toggleConfirmObscure,
                          onChanged: (value) {
                            controller.setConfirmPassword(value);
                            if (_serverError != null) {
                              setState(() {
                                _serverError = null;
                              });
                            }
                          },
                        ),
                        if (state.hasConfirmRequiredError ||
                            state.hasConfirmError) ...[
                          const SizedBox(height: 6),
                          _FieldError(
                            message: state.hasConfirmRequiredError
                                ? l10n.t('signupEnterConfirmPassword')
                                : l10n.t('signupPasswordsDontMatch'),
                          ),
                        ],
                        if (_serverError != null) ...[
                          const SizedBox(height: 8),
                          _FieldError(message: _serverError!),
                        ],
                        const SizedBox(height: 24),
                        SportalPrimaryButton(
                          label: _isSubmitting
                              ? l10n.t('commonLoading')
                              : l10n.t('commonContinue'),
                          enabled: !_isSubmitting,
                          onPressed: _handleSignUp,
                        ),
                        const SizedBox(height: 36),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 26),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.t('haveAccount'),
                                style: SportalTextStyles.b1,
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  l10n.t('signIn'),
                                  style: SportalTextStyles.b1.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: SportalColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error, size: 14, color: SportalColors.errorRed),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            message,
            style: SportalTextStyles.t1.copyWith(color: SportalColors.errorRed),
          ),
        ),
      ],
    );
  }
}
