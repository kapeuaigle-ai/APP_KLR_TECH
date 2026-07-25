import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../core/signature_image.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  int _tab = 0;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Paramètres', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Configuration de votre entreprise et de l\'application.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              AnimatedOpacity(
                opacity: _saved ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.greenBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.green.withAlpha(76)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: AppColors.green),
                    const SizedBox(width: 6),
                    Text('Modifications enregistrées', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Tabs ─────────────────────────────────────────
            AppTabBar(
              tabs: const ['Entreprise', 'Facturation', 'Sécurité', 'Données'],
              selected: _tab,
              onChanged: (i) => setState(() { _tab = i; _saved = false; }),
            ),
            const SizedBox(height: 20),

            if (_tab == 0) _EntrepriseTab(onSaved: () => setState(() => _saved = true))
            else if (_tab == 1) _FacturationTab(onSaved: () => setState(() => _saved = true))
            else if (_tab == 2) const _SecuriteTab()
            else const _DonneesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Entreprise Tab ────────────────────────────────────────
class _EntrepriseTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _EntrepriseTab({required this.onSaved});

  @override
  State<_EntrepriseTab> createState() => _EntrepriseTabState();
}

class _EntrepriseTabState extends State<_EntrepriseTab> {
  late TextEditingController _company, _address, _bp, _rccm, _regime, _tel, _email;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _company = TextEditingController(text: s.company);
    _address = TextEditingController(text: s.address);
    _bp = TextEditingController(text: s.bp);
    _rccm = TextEditingController(text: s.rccm);
    _regime = TextEditingController(text: s.regime);
    _tel = TextEditingController(text: s.tel);
    _email = TextEditingController(text: s.email);
  }

  @override
  void dispose() {
    _company.dispose(); _address.dispose(); _bp.dispose(); _rccm.dispose();
    _regime.dispose(); _tel.dispose(); _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveSplit(
      sideWidth: 280,
      breakpoint: 780,
      main: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informations de l\'entreprise', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 20),
        _SettingField(label: 'NOM DE L\'ENTREPRISE', ctrl: _company),
        const SizedBox(height: 14),
        _SettingField(label: 'ADRESSE', ctrl: _address),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SettingField(label: 'BOÎTE POSTALE', ctrl: _bp)),
          const SizedBox(width: 14),
          Expanded(child: _SettingField(label: 'RCCM', ctrl: _rccm)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SettingField(label: 'RÉGIME D\'IMPOSITION', ctrl: _regime)),
          const SizedBox(width: 14),
          Expanded(child: _SettingField(label: 'TÉLÉPHONE', ctrl: _tel)),
        ]),
        const SizedBox(height: 14),
        _SettingField(label: 'EMAIL', ctrl: _email),
        const SizedBox(height: 20),
        Align(alignment: Alignment.centerRight, child: PrimaryBtn(label: 'Enregistrer', icon: Icons.save_outlined, onTap: () {
          final state = context.read<AppState>();
          final s = state.settings;
          s.company = _company.text;
          s.address = _address.text;
          s.bp = _bp.text;
          s.rccm = _rccm.text;
          s.regime = _regime.text;
          s.tel = _tel.text;
          s.email = _email.text;
          state.updateSettings(s);
          widget.onSaved();
        })),
      ])),

      side: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Aperçu en-tête document', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
          child: Consumer<AppState>(builder: (ctx, state, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('KL', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(state.settings.company, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text1))),
            ]),
            const SizedBox(height: 8),
            Text(state.settings.address, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3, height: 1.5)),
            Text(state.settings.bp, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('RCCM : ${state.settings.rccm}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('Régime d\'imposition : ${state.settings.regime}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('Tel : ${state.settings.tel}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('Email : ${state.settings.email}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
          ])),
        ),
        const SizedBox(height: 16),
        Text('Aperçu pied de page facture', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
          child: Consumer<AppState>(builder: (ctx, state, _) => Text(
            state.settings.footerLine,
            style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.text3, height: 1.5),
            textAlign: TextAlign.center,
          )),
        ),
      ])),
    );
  }
}

// ── Sécurité Tab ──────────────────────────────────────────
/// Accès à l'application : identifiant et mot de passe du manager.
/// Le mot de passe actuel est exigé pour toute modification, et seule son
/// empreinte salée est conservée (voir core/auth.dart).
class _SecuriteTab extends StatefulWidget {
  const _SecuriteTab();

  @override
  State<_SecuriteTab> createState() => _SecuriteTabState();
}

class _SecuriteTabState extends State<_SecuriteTab> {
  late TextEditingController _username, _current, _next, _confirm;
  bool _showCurrent = false, _showNext = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: context.read<AppState>().settings.username);
    _current = TextEditingController();
    _next = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _username.dispose(); _current.dispose(); _next.dispose(); _confirm.dispose();
    super.dispose();
  }

  void _apply() {
    final state = context.read<AppState>();
    final nom = _username.text.trim();
    final nouveau = _next.text;

    if (nom.isEmpty) {
      setState(() => _error = 'L\'identifiant ne peut pas être vide.');
      return;
    }
    if (_current.text.isEmpty) {
      setState(() => _error = 'Saisis ton mot de passe actuel pour confirmer.');
      return;
    }
    if (nouveau.isNotEmpty) {
      if (nouveau.length < 4) {
        setState(() => _error = 'Le nouveau mot de passe doit faire au moins 4 caractères.');
        return;
      }
      if (nouveau != _confirm.text) {
        setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
        return;
      }
    }
    if (nouveau.isEmpty && nom == state.settings.username) {
      setState(() => _error = 'Aucune modification à enregistrer.');
      return;
    }

    final ok = state.changeCredentials(
      currentPassword: _current.text,
      newUsername: nom,
      newPassword: nouveau.isEmpty ? null : nouveau,
    );
    if (!ok) {
      setState(() => _error = 'Mot de passe actuel incorrect.');
      return;
    }

    _current.clear(); _next.clear(); _confirm.clear();
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        nouveau.isEmpty ? 'Identifiant mis à jour.' : 'Accès mis à jour.',
        style: const TextStyle(fontSize: 13),
      ),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _passwordField(String label, TextEditingController ctrl, IconData icon,
      {required bool visible, VoidCallback? onToggle}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.label),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: !visible,
        onChanged: (_) { if (_error != null) setState(() => _error = null); },
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 17, color: AppColors.text3),
          suffixIcon: onToggle == null ? null : IconButton(
            icon: Icon(visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 17, color: AppColors.text3),
            tooltip: visible ? 'Masquer' : 'Afficher',
            onPressed: onToggle,
          ),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final parDefaut = context.watch<AppState>().settings.usesDefaultPassword;

    return Column(children: [
      if (parDefaut) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.orangeBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Tu utilises encore le mot de passe par défaut (admin). '
              'Change-le pour protéger l\'accès à l\'application.',
              style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 16),
      ],

      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Sécurité', style: GoogleFonts.dmSans(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        ]),
        const SizedBox(height: 6),
        Text(
          'Accès à l\'application. Le mot de passe actuel est demandé pour '
          'confirmer toute modification. Laisse les champs de mot de passe vides '
          'pour ne changer que l\'identifiant.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3, height: 1.5),
        ),
        const SizedBox(height: 20),

        _SettingField(label: 'IDENTIFIANT', ctrl: _username),
        const SizedBox(height: 16),
        _passwordField('MOT DE PASSE ACTUEL', _current, Icons.lock_outline_rounded,
            visible: _showCurrent, onToggle: () => setState(() => _showCurrent = !_showCurrent)),
        const SizedBox(height: 16),
        _passwordField('NOUVEAU MOT DE PASSE', _next, Icons.lock_reset_rounded,
            visible: _showNext, onToggle: () => setState(() => _showNext = !_showNext)),
        const SizedBox(height: 16),
        _passwordField('CONFIRMER LE MOT DE PASSE', _confirm, Icons.lock_outline_rounded,
            visible: _showNext),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.error_outline, size: 15, color: AppColors.red),
            const SizedBox(width: 7),
            Expanded(child: Text(_error!, style: GoogleFonts.dmSans(
                fontSize: 12.5, color: AppColors.red, fontWeight: FontWeight.w500))),
          ]),
        ],
        const SizedBox(height: 20),

        Align(alignment: Alignment.centerRight, child: PrimaryBtn(
          label: 'Enregistrer les accès',
          icon: Icons.shield_outlined,
          onTap: _apply,
        )),
      ])),
    ]);
  }
}

// ── Données Tab ───────────────────────────────────────────
class _DonneesTab extends StatelessWidget {
  const _DonneesTab();

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Réinitialiser les données ?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: Text(
          'Toutes tes données (clients, documents, engagements, dépenses, '
          'activités) seront effacées et remplacées par les données de départ. '
          'Cette action est irréversible.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Réinitialiser', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().resetData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Données réinitialisées.', style: TextStyle(fontSize: 13)),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sauvegarde', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
      const SizedBox(height: 6),
      Text(
        'Tes données sont enregistrées automatiquement sur cet ordinateur à '
        'chaque modification, et rechargées au démarrage.',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3, height: 1.5),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.redBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Zone sensible', style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.red)),
          const SizedBox(height: 4),
          Text(
            'Repartir des données de départ. À utiliser pour nettoyer après des '
            'essais, ou recommencer à zéro.',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2, height: 1.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.red),
            label: Text('Réinitialiser les données', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
      ),
    ]));
  }
}

class _SettingField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _SettingField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.label),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
        decoration: InputDecoration(
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    ]);
  }
}

// ── Facturation Tab ───────────────────────────────────────
class _FacturationTab extends StatefulWidget {
  final VoidCallback onSaved;
  const _FacturationTab({required this.onSaved});

  @override
  State<_FacturationTab> createState() => _FacturationTabState();
}

class _FacturationTabState extends State<_FacturationTab> {
  late TextEditingController _prefix, _startNum, _conditions, _warranty;
  late bool _tvaEnabled;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _prefix = TextEditingController(text: s.prefix);
    _startNum = TextEditingController(text: s.startNum);
    _conditions = TextEditingController(text: s.conditions);
    _warranty = TextEditingController(text: s.warranty);
    _tvaEnabled = s.tva > 0;
  }

  @override
  void dispose() {
    _prefix.dispose(); _startNum.dispose(); _conditions.dispose(); _warranty.dispose();
    super.dispose();
  }

  // Champ texte multi-ligne, partagé par les conditions et la clause de garantie.
  Widget _multiline(TextEditingController ctrl, int maxLines) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, height: 1.5),
    decoration: InputDecoration(
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.all(12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Configuration de la numérotation', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final fields = [
            _SettingField(label: 'PRÉFIXE DOCUMENTS', ctrl: _prefix),
            _SettingField(label: 'NUMÉRO DE DÉPART', ctrl: _startNum),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EXEMPLE DE NUMÉROTATION', style: AppTheme.label),
              const SizedBox(height: 6),
              Container(
                height: 38, padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                alignment: Alignment.centerLeft,
                child: Text('${_prefix.text}-${_startNum.text}-010126', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ]),
          ];
          if (constraints.maxWidth < 680) {
            return Column(children: [
              for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: f),
            ]);
          }
          return Row(children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 14),
            Expanded(child: fields[1]),
            const SizedBox(width: 14),
            Expanded(child: fields[2]),
          ]);
        }),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TVA', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1)),
            Text('Appliquer une TVA de 5% sur les documents', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          ])),
          Switch(value: _tvaEnabled, onChanged: (v) => setState(() => _tvaEnabled = v), activeThumbColor: AppColors.primary),
        ]),
      ])),
      const SizedBox(height: 16),

      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Conditions & garantie', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 4),
        Text('Textes affichés en bas de la dernière page des documents (proforma, facture, BL).',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3, height: 1.5)),
        const SizedBox(height: 16),
        Text('CONDITIONS DE RÈGLEMENT', style: AppTheme.label),
        const SizedBox(height: 6),
        _multiline(_conditions, 4),
        const SizedBox(height: 16),
        Text('CLAUSE DE GARANTIE', style: AppTheme.label),
        const SizedBox(height: 6),
        _multiline(_warranty, 5),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: PrimaryBtn(label: 'Enregistrer', icon: Icons.save_outlined, onTap: () {
          final state = context.read<AppState>();
          final s = state.settings;
          s.prefix = _prefix.text;
          s.startNum = _startNum.text;
          s.tva = _tvaEnabled ? 5 : 0;
          s.conditions = _conditions.text;
          s.warranty = _warranty.text;
          state.updateSettings(s);
          widget.onSaved();
        })),
      ])),
      const SizedBox(height: 16),

      _SignatureCard(onSaved: widget.onSaved),
    ]);
  }
}

// ── Carte Signature du document ───────────────────────────
/// Import et gestion de la signature électronique. Unité isolée : elle mute
/// directement `settings.signature` / `settings.signatureLabel` (le même objet
/// que les autres réglages), donc aucune concurrence avec la carte numérotation.
///
/// Le point d'entrée est volontairement générique (« Importer ») : le jour où
/// la version mobile ajoutera un pavé « Dessiner », il suffira d'un second
/// bouton produisant le même PNG base64 — rien d'autre à toucher.
class _SignatureCard extends StatefulWidget {
  final VoidCallback onSaved;
  const _SignatureCard({required this.onSaved});

  @override
  State<_SignatureCard> createState() => _SignatureCardState();
}

class _SignatureCardState extends State<_SignatureCard> {
  late TextEditingController _label;
  String _base64 = '';
  Uint8List? _bytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _label = TextEditingController(text: s.signatureLabel);
    _base64 = s.signature;
    _bytes = decodeSignature(_base64);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        dialogTitle: 'Choisir une image de signature',
      );
      final bytes = (res != null && res.files.isNotEmpty) ? res.files.first.bytes : null;
      if (bytes == null) return; // dialogue annulé
      final b64 = await encodeSignaturePng(bytes);
      if (!mounted) return;
      setState(() { _base64 = b64; _bytes = decodeSignature(b64); });
    } catch (_) {
      if (mounted) _snack('Image illisible. Choisis un PNG ou un JPG.', AppColors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() => setState(() { _base64 = ''; _bytes = null; });

  void _save() {
    final state = context.read<AppState>();
    final s = state.settings;
    s.signature = _base64;
    s.signatureLabel = _label.text.trim();
    state.updateSettings(s);
    widget.onSaved();
    _snack('Signature enregistrée.', AppColors.green);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasSig = _bytes != null;
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Signature du document', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
      const SizedBox(height: 6),
      Text(
        'Ajoute ta signature électronique : elle apparaîtra dans la case '
        '« Signature » des proformas, factures et bons de livraison. '
        'Un PNG à fond transparent donne le meilleur rendu.',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3, height: 1.5),
      ),
      const SizedBox(height: 16),

      // Aperçu de la signature (ou état vide).
      Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: hasSig
            ? Image.memory(_bytes!, fit: BoxFit.contain)
            : Text('Aucune signature', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3)),
      ),
      const SizedBox(height: 14),

      Row(children: [
        SecondaryBtn(
          label: hasSig ? 'Changer la signature' : 'Importer une signature',
          icon: _busy ? Icons.hourglass_empty : Icons.upload_file_outlined,
          onTap: _import,
        ),
        if (hasSig) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _remove,
            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
            label: Text('Retirer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
          ),
        ],
      ]),
      const SizedBox(height: 16),

      _SettingField(label: 'LÉGENDE SOUS LA SIGNATURE (optionnel)', ctrl: _label),
      const SizedBox(height: 20),

      Align(alignment: Alignment.centerRight, child: PrimaryBtn(label: 'Enregistrer', icon: Icons.save_outlined, onTap: _save)),
    ]));
  }
}
