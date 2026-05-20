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
import 'providers/auth_session_provider.dart';
import 'services/auth_api_client.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    ref.read(loginFormControllerProvider.notifier).reset();
    final state = ref.read(loginFormControllerProvider);
    _emailController = TextEditingController(text: state.email);
    _passwordController = TextEditingController(text: state.password);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final l10n = context.l10n;
    final formController = ref.read(loginFormControllerProvider.notifier);

    formController.submit();
    final formState = ref.read(loginFormControllerProvider);
    if (!formState.canContinue) return;

    setState(() {
      _isSubmitting = true;
      _serverError = null;
    });

    try {
      final authApi = ref.read(authApiClientProvider);
      final payload = await authApi.login(
        email: formState.email,
        password: formState.password,
      );
      ref.read(authSessionProvider.notifier).setSession(payload);

      try {
        final me = await authApi.fetchMe(accessToken: payload.accessToken);
        ref.read(authSessionProvider.notifier).setUser(me);
      } catch (_) {
        // If /users/me fails we still keep the session from login response.
      }

      if (!mounted) return;
      context.go('/home');
    } on SportalApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverError = l10n.t('loginFailed');
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
    final state = ref.watch(loginFormControllerProvider);
    final controller = ref.read(loginFormControllerProvider.notifier);
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
                            onPressed: () => context.go('/onboarding'),
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
                          l10n.t('loginTitle'),
                          style: SportalTextStyles.h1,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: keyboardOpen ? 16 : 32),
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
                                ? l10n.t('loginEnterEmail')
                                : l10n.t('loginEnterValidEmail'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AuthTextField(
                          hintText: l10n.t('passwordHintPlain'),
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
                                ? l10n.t('loginEnterPassword')
                                : l10n.t('loginPasswordMin'),
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
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => context.go('/forgot-password'),
                            child: Text(
                              l10n.t('forgotPassword'),
                              style: SportalTextStyles.b2.copyWith(
                                color: SportalColors.primaryBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 26),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.t('noAccount'),
                                style: SportalTextStyles.b1,
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => context.go('/signup'),
                                child: Text(
                                  l10n.t('signUp'),
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
