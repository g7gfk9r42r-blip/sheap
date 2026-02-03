import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

enum _AuthPage { login, register, forgotPassword }

/// Local (route-less) auth navigation so we don't push new routes on top of `/`
/// (otherwise auth state updates wouldn't replace the visible screen).
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthPage _page = _AuthPage.login;

  void _go(_AuthPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    switch (_page) {
      case _AuthPage.login:
        return LoginScreen(
          onGoRegister: () => _go(_AuthPage.register),
          onGoForgotPassword: () => _go(_AuthPage.forgotPassword),
        );
      case _AuthPage.register:
        return RegisterScreen(
          onGoLogin: () => _go(_AuthPage.login),
        );
      case _AuthPage.forgotPassword:
        return ForgotPasswordScreen(
          onGoBack: () => _go(_AuthPage.login),
        );
    }
  }
}


