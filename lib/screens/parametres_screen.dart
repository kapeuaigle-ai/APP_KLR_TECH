import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

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
    final state = context.watch<AppState>();
    final isMonoUser = state.isMonoUser;

    // Clamp tab if Utilisateurs tab disappears in mono mode
    final tabCount = isMonoUser ? 2 : 3;
    if (_tab >= tabCount) _tab = 0;

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

            // ── Mode sélecteur ───────────────────────────────
            _ModeSelectorCard(
              isMonoUser: isMonoUser,
              onChanged: (mono) {
                state.setMonoUser(mono);
                if (mono && _tab == 2) setState(() => _tab = 0);
                setState(() => _saved = false);
              },
            ),
            const SizedBox(height: 20),

            // ── Tabs ─────────────────────────────────────────
            AppTabBar(
              tabs: isMonoUser ? const ['Entreprise', 'Facturation'] : const ['Entreprise', 'Facturation', 'Utilisateurs'],
              selected: _tab,
              onChanged: (i) => setState(() { _tab = i; _saved = false; }),
            ),
            const SizedBox(height: 20),

            if (_tab == 0) _EntrepriseTab(onSaved: () => setState(() => _saved = true))
            else if (_tab == 1) _FacturationTab(onSaved: () => setState(() => _saved = true))
            else const _UsersTab(),
          ],
        ),
      ),
    );
  }
}

// ── Mode Selector Card ────────────────────────────────────
class _ModeSelectorCard extends StatelessWidget {
  final bool isMonoUser;
  final ValueChanged<bool> onChanged;
  const _ModeSelectorCard({required this.isMonoUser, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode d\'utilisation', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            Text('Définit comment l\'application est utilisée', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          ]),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _ModeOption(
            icon: Icons.person_outline_rounded,
            title: 'Mono-utilisateur',
            description: 'Application pour un seul utilisateur. Interface simplifiée, sans gestion d\'équipe ni contrôle d\'accès.',
            selected: isMonoUser,
            onTap: () => onChanged(true),
            accentColor: AppColors.emerald,
            accentBg: AppColors.greenBg,
          )),
          const SizedBox(width: 14),
          Expanded(child: _ModeOption(
            icon: Icons.group_outlined,
            title: 'Multi-utilisateurs',
            description: 'Plusieurs collaborateurs avec rôles et permissions différenciés. Gestion complète des équipes.',
            selected: !isMonoUser,
            onTap: () => onChanged(false),
            accentColor: AppColors.blue,
            accentBg: AppColors.blueBg,
          )),
        ]),
        const SizedBox(height: 14),
        // Active mode badge
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(isMonoUser),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMonoUser ? AppColors.greenBg : AppColors.blueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isMonoUser ? Icons.check_circle_rounded : Icons.check_circle_rounded,
                size: 14,
                color: isMonoUser ? AppColors.emerald : AppColors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                isMonoUser
                    ? 'Mode actif : Mono-utilisateur — Équipes masquées, accès simplifié.'
                    : 'Mode actif : Multi-utilisateurs — Toutes les fonctionnalités activées.',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: isMonoUser ? AppColors.emerald : AppColors.blue),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ModeOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
  final Color accentBg;
  const _ModeOption({
    required this.icon, required this.title, required this.description,
    required this.selected, required this.onTap,
    required this.accentColor, required this.accentBg,
  });

  @override
  State<_ModeOption> createState() => _ModeOptionState();
}

class _ModeOptionState extends State<_ModeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selected ? widget.accentBg : (_hovered ? const Color(0xFFFAFAFB) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected ? widget.accentColor : AppColors.border,
              width: widget.selected ? 2 : 1,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.selected ? widget.accentColor.withAlpha(25) : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 20, color: widget.selected ? widget.accentColor : AppColors.text3),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(widget.title, style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: widget.selected ? widget.accentColor : AppColors.text1,
                )),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: widget.selected ? widget.accentColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.selected ? widget.accentColor : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: widget.selected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ]),
              const SizedBox(height: 5),
              Text(widget.description, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3, height: 1.5)),
            ])),
          ]),
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
  late TextEditingController _company, _rc, _ifNum, _address, _ice;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _company = TextEditingController(text: s.company);
    _rc = TextEditingController(text: s.rc);
    _ifNum = TextEditingController(text: s.ifNum);
    _address = TextEditingController(text: s.address);
    _ice = TextEditingController(text: s.ice);
  }

  @override
  void dispose() {
    _company.dispose(); _rc.dispose(); _ifNum.dispose(); _address.dispose(); _ice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informations de l\'entreprise', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 20),
        _SettingField(label: 'NOM DE L\'ENTREPRISE', ctrl: _company),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SettingField(label: 'REGISTRE DE COMMERCE', ctrl: _rc)),
          const SizedBox(width: 14),
          Expanded(child: _SettingField(label: 'NUMÉRO IF', ctrl: _ifNum)),
        ]),
        const SizedBox(height: 14),
        _SettingField(label: 'ADRESSE', ctrl: _address),
        const SizedBox(height: 14),
        _SettingField(label: 'ICE', ctrl: _ice),
        const SizedBox(height: 20),
        Align(alignment: Alignment.centerRight, child: PrimaryBtn(label: 'Enregistrer', icon: Icons.save_outlined, onTap: () {
          final state = context.read<AppState>();
          final s = state.settings;
          s.company = _company.text;
          s.rc = _rc.text;
          s.ifNum = _ifNum.text;
          s.address = _address.text;
          s.ice = _ice.text;
          state.updateSettings(s);
          widget.onSaved();
        })),
      ]))),
      const SizedBox(width: 16),

      SizedBox(width: 280, child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Text(state.settings.company, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text1)),
            ]),
            const SizedBox(height: 8),
            Text(state.settings.address, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3, height: 1.5)),
            Text('RC : ${state.settings.rc}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('IF : ${state.settings.ifNum}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
          ])),
        ),
      ]))),
    ]);
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
  late TextEditingController _prefix, _startNum, _conditions;
  late bool _tvaEnabled;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _prefix = TextEditingController(text: s.prefix);
    _startNum = TextEditingController(text: s.startNum);
    _conditions = TextEditingController(text: s.conditions);
    _tvaEnabled = s.tva > 0;
  }

  @override
  void dispose() {
    _prefix.dispose(); _startNum.dispose(); _conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Configuration de la numérotation', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _SettingField(label: 'PRÉFIXE DOCUMENTS', ctrl: _prefix)),
          const SizedBox(width: 14),
          Expanded(child: _SettingField(label: 'NUMÉRO DE DÉPART', ctrl: _startNum)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EXEMPLE DE NUMÉROTATION', style: AppTheme.label),
            const SizedBox(height: 6),
            Container(
              height: 38, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              alignment: Alignment.centerLeft,
              child: Text('${_prefix.text}-P${_startNum.text}-010126', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ])),
        ]),
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
        Text('Conditions par défaut', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 12),
        TextField(
          controller: _conditions,
          maxLines: 5,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, height: 1.5),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: PrimaryBtn(label: 'Enregistrer', icon: Icons.save_outlined, onTap: () {
          final state = context.read<AppState>();
          final s = state.settings;
          s.prefix = _prefix.text;
          s.startNum = _startNum.text;
          s.tva = _tvaEnabled ? 5 : 0;
          s.conditions = _conditions.text;
          state.updateSettings(s);
          widget.onSaved();
        })),
      ])),
    ]);
  }
}

// ── Users Tab (multi-user only) ───────────────────────────
class _UsersTab extends StatelessWidget {
  const _UsersTab();

  static final _users = [
    ('Koffi Lambert', 'kl@klrtech.ci', 'Administrateur', AppColors.primary, true),
    ('Sara El Mansouri', 'sm@klrtech.ci', 'Comptable', AppColors.purple, true),
    ('Moussa Diallo', 'md@klrtech.ci', 'Chef de Projet', AppColors.emerald, true),
  ];

  @override
  Widget build(BuildContext context) {
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Utilisateurs', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const Spacer(),
        PrimaryBtn(label: 'Inviter', icon: Icons.person_add_outlined, onTap: () {}),
      ]),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
      ..._users.map((u) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          AvatarCircle(initials: u.$1.split(' ').map((w) => w[0]).take(2).join(), color: u.$4, size: 38),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.$1, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
            Text(u.$2, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
            child: Text(u.$3, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text2)),
          ),
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: u.$5 ? AppColors.green : AppColors.text3, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(u.$5 ? 'Actif' : 'Inactif', style: GoogleFonts.dmSans(fontSize: 12, color: u.$5 ? AppColors.green : AppColors.text3)),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3), onPressed: () {}, padding: const EdgeInsets.all(6)),
        ]),
      )),
    ]));
  }
}
