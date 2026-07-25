import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../widgets/klr_logo.dart';
import '../widgets/responsive.dart';

/// Page de connexion : porte d'entrée de l'application.
/// Accès d'usine admin/admin, modifiables dans Paramètres → Sécurité.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _userFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Curseur déjà dans le premier champ : la saisie peut commencer au clavier.
    WidgetsBinding.instance.addPostFrameCallback((_) => _userFocus.requestFocus());
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _userFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final ok = context.read<AppState>().login(_user.text, _password.text);
    if (ok) return; // le shell bascule automatiquement sur l'app
    // Message unique : ne pas révéler lequel des deux champs est faux.
    setState(() => _error = 'Identifiant ou mot de passe incorrect.');
    _password.clear();
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          // Sur un écran de 360 px, 24 de marge plus 36 de padding interne ne
          // laissaient que 240 px utiles au formulaire : on resserre les deux.
          padding: EdgeInsets.all(isPhone(context) ? 16 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: isPhone(context)
                  ? const EdgeInsets.fromLTRB(22, 30, 22, 26)
                  : const EdgeInsets.fromLTRB(36, 40, 36, 36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KlrLogo(height: 96),
                  const SizedBox(height: 18),
                  Text(
                    'GESTION',
                    style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.text2, letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _LoginField(
                    controller: _user,
                    focusNode: _userFocus,
                    hint: 'Nom d\'utilisateur',
                    icon: Icons.person_outline_rounded,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    onChanged: (_) => _clearError(),
                  ),
                  const SizedBox(height: 14),
                  _LoginField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    hint: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) => _clearError(),
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: AppColors.text3,
                      ),
                      tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      const Icon(Icons.error_outline, size: 15, color: AppColors.red),
                      const SizedBox(width: 7),
                      Expanded(child: Text(_error!, style: GoogleFonts.dmSans(
                          fontSize: 12.5, color: AppColors.red, fontWeight: FontWeight.w500))),
                    ]),
                  ],
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: Text('Se connecter', style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const _LoginField({
    required this.controller, required this.focusNode,
    required this.hint, required this.icon,
    this.obscure = false, this.trailing, this.onSubmitted, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3),
        prefixIcon: Icon(icon, size: 18, color: AppColors.text3),
        suffixIcon: trailing,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}
