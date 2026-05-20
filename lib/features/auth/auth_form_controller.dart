import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isPasswordObscured = true,
    this.submitted = false,
  });

  final String email;
  final String password;
  final bool isPasswordObscured;
  final bool submitted;

  bool get isEmailValid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  bool get isPasswordValid => password.length >= 8;
  bool get hasEmailRequiredError => submitted && email.trim().isEmpty;
  bool get hasEmailFormatError =>
      submitted && email.trim().isNotEmpty && !isEmailValid;
  bool get hasPasswordRequiredError => submitted && password.isEmpty;
  bool get hasPasswordError =>
      submitted && password.isNotEmpty && !isPasswordValid;
  bool get canContinue => isEmailValid && isPasswordValid;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isPasswordObscured,
    bool? submitted,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
      submitted: submitted ?? this.submitted,
    );
  }
}

class LoginFormController extends StateNotifier<LoginFormState> {
  LoginFormController() : super(const LoginFormState());

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void togglePasswordObscure() {
    state = state.copyWith(isPasswordObscured: !state.isPasswordObscured);
  }

  void submit() {
    state = state.copyWith(submitted: true);
  }

  void reset() {
    state = const LoginFormState();
  }
}

final loginFormControllerProvider =
    StateNotifierProvider.autoDispose<LoginFormController, LoginFormState>(
      (ref) => LoginFormController(),
    );

class SignUpFormState {
  const SignUpFormState({
    this.username = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isPasswordObscured = true,
    this.isConfirmObscured = true,
    this.submitted = false,
  });

  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final bool isPasswordObscured;
  final bool isConfirmObscured;
  final bool submitted;

  bool get isUsernameValid => username.trim().length >= 3;
  bool get isEmailValid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  bool get isPasswordValid => password.length >= 8;
  bool get matchesPassword =>
      confirmPassword.isNotEmpty && confirmPassword == password;
  bool get hasUsernameRequiredError => submitted && username.trim().isEmpty;
  bool get hasUsernameError =>
      submitted && username.trim().isNotEmpty && !isUsernameValid;
  bool get hasEmailRequiredError => submitted && email.trim().isEmpty;
  bool get hasEmailFormatError =>
      submitted && email.trim().isNotEmpty && !isEmailValid;
  bool get hasPasswordRequiredError => submitted && password.isEmpty;
  bool get hasPasswordError =>
      submitted && password.isNotEmpty && !isPasswordValid;
  bool get hasConfirmRequiredError => submitted && confirmPassword.isEmpty;
  bool get hasConfirmError =>
      submitted && confirmPassword.isNotEmpty && !matchesPassword;
  bool get canContinue =>
      isUsernameValid && isEmailValid && isPasswordValid && matchesPassword;

  SignUpFormState copyWith({
    String? username,
    String? email,
    String? password,
    String? confirmPassword,
    bool? isPasswordObscured,
    bool? isConfirmObscured,
    bool? submitted,
  }) {
    return SignUpFormState(
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
      isConfirmObscured: isConfirmObscured ?? this.isConfirmObscured,
      submitted: submitted ?? this.submitted,
    );
  }
}

class SignUpFormController extends StateNotifier<SignUpFormState> {
  SignUpFormController() : super(const SignUpFormState());

  void setUsername(String value) {
    state = state.copyWith(username: value);
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
  }

  void setPassword(String value) {
    state = state.copyWith(password: value);
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(confirmPassword: value);
  }

  void togglePasswordObscure() {
    state = state.copyWith(isPasswordObscured: !state.isPasswordObscured);
  }

  void toggleConfirmObscure() {
    state = state.copyWith(isConfirmObscured: !state.isConfirmObscured);
  }

  void submit() {
    state = state.copyWith(submitted: true);
  }

  void reset() {
    state = const SignUpFormState();
  }
}

final signUpFormControllerProvider =
    StateNotifierProvider.autoDispose<SignUpFormController, SignUpFormState>(
      (ref) => SignUpFormController(),
    );
