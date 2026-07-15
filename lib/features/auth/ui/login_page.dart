import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// Couleur de marque fintrack (teal du logo).
const Color _kBrand = Color(0xFF005166);
const Color _kBrandDark = Color(0xFF0A6B7D);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text;
    final password = _passwordController.text;
    final cubit = context.read<AuthCubit>();

    if (_isLogin) {
      cubit.signInWithEmail(email, password);
    } else {
      cubit.signUpWithEmail(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    // Dégradé de fond aux couleurs fintrack (teal).
    final backgroundGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF04252B), Color(0xFF06333B), Color(0xFF005166)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF3F4), Color(0xFFD3E7EA), Color(0xFFBFDDE1)],
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : _kBrand,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // Connexion réussie : on revient à l'application (l'écran a été
            // ouvert depuis Paramètres → Cloud). La sync se lance seule.
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        child: Stack(
          children: [
            // Fond dégradé dynamique
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(gradient: backgroundGradient),
            ),

            // Cercles décoratifs floutés (teal) pour l'effet glassmorphic
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? _kBrandDark : _kBrand)
                      .withValues(alpha: 0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.15,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.9,
                height: size.width * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark
                          ? const Color(0xFF0A6B7D)
                          : const Color(0xFF4FA3AE))
                      .withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),

            // Contenu central scrollable
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo fintrack
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          height: 96,
                          width: 96,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Image.asset(
                            'assets/icon/app_icon_foreground.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: isDark ? Colors.white : _kBrand,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _isLogin
                            ? 'Maîtrisez votre budget au quotidien.'
                            : 'Rejoignez-nous et commencez à épargner.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? const Color(0xFFB8D8DC)
                              : const Color(0xFF3D6B72),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Carte glassmorphic
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: isDark ? 0.3 : 0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: (isDark ? Colors.white : _kBrand)
                                    .withValues(alpha: 0.10),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _isLogin
                                        ? 'Connexion'
                                        : 'Création de compte',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : _kBrand,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // E-mail
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: _fieldDecoration(
                                      theme,
                                      label: 'Adresse e-mail',
                                      icon: Icons.email_outlined,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Veuillez saisir votre e-mail';
                                      }
                                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(val)) {
                                        return 'Adresse e-mail invalide';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Mot de passe
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: _isLogin
                                        ? TextInputAction.done
                                        : TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        _isLogin ? _submit() : null,
                                    decoration: _fieldDecoration(
                                      theme,
                                      label: 'Mot de passe',
                                      icon: Icons.lock_outline,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Veuillez saisir votre mot de passe';
                                      }
                                      if (!_isLogin && val.length < 6) {
                                        return 'Le mot de passe doit faire au moins 6 caractères';
                                      }
                                      return null;
                                    },
                                  ),

                                  // Confirmation (inscription)
                                  if (!_isLogin) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: _fieldDecoration(
                                        theme,
                                        label: 'Confirmer le mot de passe',
                                        icon: Icons.lock_reset,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (!_isLogin) {
                                          if (val == null || val.isEmpty) {
                                            return 'Veuillez confirmer votre mot de passe';
                                          }
                                          if (val != _passwordController.text) {
                                            return 'Les mots de passe ne correspondent pas';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 24),

                                  // Bouton principal
                                  BlocBuilder<AuthCubit, AuthState>(
                                    builder: (context, state) {
                                      final isLoading = state is AuthLoading;
                                      return FilledButton(
                                        onPressed: isLoading ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          backgroundColor:
                                              isDark ? _kBrandDark : _kBrand,
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                _isLogin
                                                    ? 'Se connecter'
                                                    : "S'inscrire",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 20),

                                  // Séparateur
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.4))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          'ou continuer avec',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: isDark
                                                ? const Color(0xFF7FA6AB)
                                                : const Color(0xFF6E9298),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.4))),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Bouton Google (sans image réseau)
                                  BlocBuilder<AuthCubit, AuthState>(
                                    builder: (context, state) {
                                      final isLoading = state is AuthLoading;
                                      return OutlinedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => context
                                                .read<AuthCubit>()
                                                .signInWithGoogle(),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          side: BorderSide(
                                            color: (isDark
                                                    ? Colors.white
                                                    : _kBrand)
                                                .withValues(alpha: 0.20),
                                            width: 1.5,
                                          ),
                                          backgroundColor: Colors.white
                                              .withValues(
                                                  alpha: isDark ? 0.06 : 0.85),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const _GoogleGlyph(),
                                            const SizedBox(width: 12),
                                            Flexible(
                                              child: Text(
                                                'Continuer avec Google',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bascule connexion / inscription
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? "Vous n'avez pas de compte ? "
                                : "Vous avez déjà un compte ? ",
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFB8D8DC)
                                  : const Color(0xFF3D6B72),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _formKey.currentState?.reset();
                                _emailController.clear();
                                _passwordController.clear();
                                _confirmPasswordController.clear();
                              });
                            },
                            child: Text(
                              _isLogin ? "S'inscrire" : "Se connecter",
                              style: TextStyle(
                                color: isDark ? const Color(0xFF7FD3DE) : _kBrand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kBrand, width: 1.5),
      ),
    );
  }
}

/// Petit « G » Google dessiné en local (pas de dépendance réseau).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15,
          height: 1.1,
        ),
      ),
    );
  }
}
