import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
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
              tabs: const ['Entreprise', 'Facturation'],
              selected: _tab,
              onChanged: (i) => setState(() { _tab = i; _saved = false; }),
            ),
            const SizedBox(height: 20),

            if (_tab == 0) _EntrepriseTab(onSaved: () => setState(() => _saved = true))
            else _FacturationTab(onSaved: () => setState(() => _saved = true)),
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
    return ResponsiveSplit(
      sideWidth: 280,
      breakpoint: 780,
      main: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            Text('RC : ${state.settings.rc}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
            Text('IF : ${state.settings.ifNum}', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.text3)),
          ])),
        ),
      ])),
    );
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
                child: Text('${_prefix.text}-P${_startNum.text}-010126', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
