import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/comptabilite.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suivi', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Engagements, comptabilité, dîme, tâches et notes internes.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),
            AppTabBar(
              tabs: const ['Engagements', 'Comptabilité', 'Dîme', 'Tâches', 'Notes'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 20),
            if (_tab == 0) const _EngagementsTab()
            else if (_tab == 1) const _ComptaTab()
            else if (_tab == 2) const _DimeTab()
            else if (_tab == 3) const _TachesTab()
            else const _NotesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Engagements Tab (créances & dettes) ───────────────────
// Deux listes séparées : ce qu'on nous doit, ce que l'on doit. Un engagement
// est un montant ATTENDU ; chaque règlement (partiel ou total) est un
// mouvement RÉEL qui entre en comptabilité au mois de sa propre date. Un
// engagement soldé n'est plus un encours ; un engagement annulé n'en accepte
// plus, mais garde les règlements déjà passés.
class _EngagementsTab extends StatefulWidget {
  const _EngagementsTab();
  @override
  State<_EngagementsTab> createState() => _EngagementsTabState();
}

class _EngagementsTabState extends State<_EngagementsTab> {
  final _numCtrl = TextEditingController();
  final _tiersCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _acompteCtrl = TextEditingController();
  /// Liste affichée : 'entrant' (créance) ou 'sortant' (dette). Détermine
  /// aussi ce que crée le bouton — pas de sélecteur de type dans le formulaire.
  String _sens = 'entrant';
  /// Second filtre, orthogonal au premier : un engagement soldé le jour même
  /// (dépense au comptant) reste un Engagement, donc apparaît dans Dettes —
  /// ce qui noierait la vraie dette en cours sous des lignes déjà closes.
  /// Faux = « En cours » (défaut) : ni soldé, ni annulé.
  bool _regle = false;
  DateTime _echeance = DateTime.now();
  DateTime _dateAcompte = DateTime.now();
  String _categorie = kCategoriesDepense.first;
  /// Projet auquel rattacher l'engagement créé, `null` = aucun (le cas
  /// courant). C'est ce qui permet à une dette de compter dans le
  /// `montantDepense` — donc la marge — de son projet.
  int? _projetId;
  bool _erreur = false;

  bool get _estCreance => _sens == 'entrant';

  @override
  void dispose() {
    _numCtrl.dispose();
    _tiersCtrl.dispose();
    _descCtrl.dispose();
    _montantCtrl.dispose();
    _acompteCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  /// Enregistre l'engagement saisi, puis l'éventuel acompte comme premier
  /// règlement. Retourne false si le formulaire est incomplet, pour que la
  /// boîte reste ouverte et signale ce qui manque.
  bool _add(AppState state) {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(' ', '')) ?? 0;
    if (_tiersCtrl.text.trim().isEmpty || montant <= 0) return false;
    final ref = _numCtrl.text.trim();
    final id = DateTime.now().microsecondsSinceEpoch;
    state.addEngagement(Engagement(
      id: id,
      sens: _sens,
      tiers: _tiersCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      montant: montant,
      echeance: _echeance,
      categorie: _categorie,
      documentNumero: ref.isEmpty ? null : ref,
      projetId: _projetId,
    ));
    // Acompte facultatif : déjà versé au moment où l'engagement est saisi.
    // `ajouterReglement` l'écrête lui-même au montant si nécessaire.
    final saisi = double.tryParse(_acompteCtrl.text.replaceAll(' ', '')) ?? 0;
    if (saisi > 0) {
      state.ajouterReglement(id, saisi, _dateAcompte);
    }
    return true;
  }

  /// Questionnaire de saisie. Le type vient de la liste ouverte : sur l'onglet
  /// Créances le bouton crée une créance, sur Dettes une dette.
  Future<void> _ouvrirFormulaire(AppState state) async {
    _numCtrl.clear();
    _tiersCtrl.clear();
    _descCtrl.clear();
    _montantCtrl.clear();
    _acompteCtrl.clear();
    _echeance = DateTime.now();
    _dateAcompte = DateTime.now();
    _categorie = kCategoriesDepense.first;
    _projetId = null;
    _erreur = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_estCreance ? 'Nouvelle Créance' : 'Nouvelle Dette',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                    const SizedBox(height: 2),
                    Text(_estCreance
                            ? 'Entre en comptabilité une fois encaissée.'
                            : 'Entre en comptabilité une fois payée.',
                        style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                  ])),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close, size: 18, color: AppColors.text2),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),

              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field(_estCreance ? 'NOM DU DÉBITEUR' : 'CRÉANCIER',
                      _tf(_tiersCtrl, _estCreance ? 'Ex : Advans' : 'Ex : Orange CI')),
                  const SizedBox(height: 14),
                  _field('DESCRIPTION', _tf(_descCtrl, 'Ex : Équipements réseau')),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.end, children: [
                    _field('MONTANT (FCFA)', SizedBox(width: 190, child: _tf(_montantCtrl, '0', numeric: true))),
                    _field('RÉFÉRENCE', SizedBox(width: 190, child: _tf(_numCtrl, 'Facultative'))),
                  ]),
                  const SizedBox(height: 14),
                  _field('DATE D\'ÉCHÉANCE', GestureDetector(
                    onTap: () async {
                      final d = await _pickDate(_echeance);
                      if (d != null) setLocal(() => _echeance = d);
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text(Fmt.jour(_echeance), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ]),
                    ),
                  )),

                  // Masqué s'il n'existe aucun projet : inutile d'encombrer
                  // la boîte pour un manager qui n'en a pas encore créé.
                  if (state.projets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _field('PROJET', _projetDropdown(
                        _projetsPourSelecteur(state.projets, selectionne: _projetId),
                        _projetId,
                        (v) => setLocal(() => _projetId = v))),
                  ],

                  // ── Acompte déjà versé (facultatif) ────────────
                  // C'est le premier règlement de l'engagement, enregistré à sa
                  // propre date dès sa création. Les règlements suivants se
                  // gèrent depuis le menu de la liste, une fois l'engagement créé.
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.end, children: [
                    _field(
                      _estCreance ? 'ACOMPTE DÉJÀ REÇU (FCFA)' : 'ACOMPTE DÉJÀ VERSÉ (FCFA)',
                      SizedBox(width: 190, child: _tf(_acompteCtrl, 'Aucun', numeric: true,
                          onChanged: (_) => setLocal(() {}))),
                    ),
                    if ((double.tryParse(_acompteCtrl.text.replaceAll(' ', '')) ?? 0) > 0)
                      _field('DATE DE L\'ACOMPTE', GestureDetector(
                        onTap: () async {
                          final d = await _pickDate(_dateAcompte);
                          if (d != null) setLocal(() => _dateAcompte = d);
                        },
                        child: Container(
                          width: 190, height: 40,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.text3),
                            const SizedBox(width: 8),
                            Text(Fmt.jour(_dateAcompte), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                          ]),
                        ),
                      )),
                  ]),
                  Builder(builder: (_) {
                    final m = double.tryParse(_montantCtrl.text.replaceAll(' ', '')) ?? 0;
                    final a = double.tryParse(_acompteCtrl.text.replaceAll(' ', '')) ?? 0;
                    if (a <= 0 || m <= 0) return const SizedBox.shrink();
                    final reste = a >= m ? 0.0 : m - a;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        reste == 0
                            ? 'L\'acompte couvre la totalité du montant.'
                            : 'Restera à régler : ${Fmt.money(reste)}',
                        style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2),
                      ),
                    );
                  }),

                  // La catégorie ne sert qu'aux dettes : c'est la ligne de
                  // dépense sous laquelle le paiement sera classé.
                  if (!_estCreance) ...[
                    const SizedBox(height: 16),
                    Text('CATÉGORIE DE DÉPENSE', style: AppTheme.label),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: kCategoriesDepense.map((c) => GestureDetector(
                      onTap: () => setLocal(() => _categorie = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _categorie == c ? AppColors.primary : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _categorie == c ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(c, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _categorie == c ? Colors.white : AppColors.text2)),
                      ),
                    )).toList()),
                  ],

                  if (_erreur) ...[
                    const SizedBox(height: 14),
                    Text(
                      _estCreance
                          ? 'Renseignez le nom du débiteur et un montant supérieur à 0.'
                          : 'Renseignez le créancier et un montant supérieur à 0.',
                      style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red),
                    ),
                  ],
                ]),
              )),

              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  ),
                  const SizedBox(width: 8),
                  PrimaryBtn(label: 'Enregistrer', icon: Icons.check, onTap: () {
                    if (_add(state)) {
                      Navigator.of(ctx).pop();
                    } else {
                      setLocal(() => _erreur = true);
                    }
                  }),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final engagements = state.engagements;
    final creances = engagements.where((e) => e.estEntrant).toList();
    final dettes = engagements.where((e) => !e.estEntrant).toList();

    // Les totaux ne portent que sur le reste dû des engagements actifs : un
    // engagement soldé est déjà passé en comptabilité, un engagement annulé
    // n'est plus un encours.
    final totalCreances = creances.where((e) => !e.annule).fold<double>(0, (s, e) => s + e.reste);
    final totalDettes = dettes.where((e) => !e.annule).fold<double>(0, (s, e) => s + e.reste);
    final soldeNet = totalCreances - totalDettes;

    final listeBase = _estCreance ? creances : dettes;
    // Filtre En cours / Réglées : une dette ou créance soldée (ou annulée)
    // n'est plus un encours — elle n'a rien à faire dans la vue par défaut,
    // qui doit répondre à « qu'est-ce qu'on doit / nous doit encore ? ».
    final enCours = listeBase.where((e) => !e.solde && !e.annule).toList();
    final reglees = listeBase.where((e) => e.solde || e.annule).toList();
    final liste = _regle ? reglees : enCours;
    final typeMot = _estCreance ? 'créance' : 'dette';

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'TOTAL CRÉANCES', value: Fmt.number(totalCreances), unit: 'FCFA'),
        StatCard(label: 'TOTAL DETTES', value: Fmt.number(totalDettes), unit: 'FCFA'),
        StatCard(label: 'SOLDE NET', value: Fmt.number(soldeNet), unit: 'FCFA', red: soldeNet < 0),
      ]),
      const SizedBox(height: 20),

      // Deux listes distinctes : le type n'est plus une case à cocher du
      // formulaire, c'est la liste dans laquelle on se trouve. Sélecteur à
      // gauche, action à droite — une seule ligne au-dessus du tableau, qui
      // s'empile sur téléphone (les deux ensemble réclament 378 px).
      StackingRow(
        left: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppFilterChip(
              label: 'Créances (${creances.length})',
              active: _estCreance,
              onTap: () => setState(() => _sens = 'entrant'),
            ),
            const SizedBox(width: 4),
            AppFilterChip(
              label: 'Dettes (${dettes.length})',
              active: !_estCreance,
              onTap: () => setState(() => _sens = 'sortant'),
            ),
          ]),
        ),
        right: PrimaryBtn(
          label: _estCreance ? 'Nouvelle Créance' : 'Nouvelle Dette',
          icon: Icons.add,
          onTap: () => _ouvrirFormulaire(state),
        ),
      ),
      const SizedBox(height: 10),

      // Second filtre, même idiome visuel que le premier : ce qui reste à
      // encaisser/payer par défaut, l'historique déjà réglé sur demande.
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppFilterChip(
              label: 'En cours (${enCours.length})',
              active: !_regle,
              onTap: () => setState(() => _regle = false),
            ),
            const SizedBox(width: 4),
            AppFilterChip(
              label: 'Réglées (${reglees.length})',
              active: _regle,
              onTap: () => setState(() => _regle = true),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),

      // Téléphone : une carte par engagement (le tableau ferait 1000 px).
      if (isPhone(context))
        if (liste.isEmpty)
          CardBox(
            padding: EdgeInsets.zero,
            child: EmptyHint(_regle
                ? 'Aucune $typeMot réglée'
                : 'Aucune $typeMot en cours'),
          )
        else
          ...liste.map((e) => ListCard(
            // Bande de statut : en retard, réglé, annulé, ou en attente.
            accent: switch (_statutDe(e, now)) {
              'retard' => AppColors.red,
              'paye' => AppColors.green,
              'annulee' => AppColors.text3,
              _ => AppColors.orange,
            },
            background: e.solde ? Colors.white : const Color(0xFFFAFAFB),
            title: Text(e.tiers, style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            // Le type (créance / dette) est déjà donné par le sélecteur au
            // dessus : inutile de le répéter, la place manque.
            subtitle: Row(children: [
              StatusBadge(status: _statutDe(e, now)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.documentNumero ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.primary))),
            ]),
            trailing: _engagementMenu(context, state, e, large: true),
            fields: [
              ('MONTANT', CardValue(Fmt.money(e.montant), bold: true)),
              if (e.regle > 0 && !e.solde)
                ('RÉGLÉ', CardValue('${Fmt.money(e.regle)} · reste ${Fmt.money(e.reste)}',
                    color: AppColors.blue)),
              if (e.description.isNotEmpty) ('OBJET', CardValue(e.description)),
              ('ÉCHÉANCE', CardValue(Fmt.jour(e.echeance),
                  color: _statutDe(e, now) == 'retard' ? AppColors.red : null)),
              if (e.solde)
                ('RÉGLÉ LE', CardValue(_dateTexte(_dernierReglement(e)), color: AppColors.green)),
            ],
          ))
      else
      CardBox(
        padding: EdgeInsets.zero,
        child: HScrollTable(
          minWidth: 1000,
          child: Column(children: [
            Container(
              color: AppColors.bg,
              child: const Row(children: [
                Expanded(flex: 2, child: ThCell('TYPE')),
                Expanded(flex: 3, child: ThCell('RÉFÉRENCE')),
                Expanded(flex: 4, child: ThCell('TIERS')),
                Expanded(flex: 3, child: ThCell('MONTANT')),
                Expanded(flex: 2, child: ThCell('STATUT')),
                Expanded(flex: 3, child: ThCell('ÉCHÉANCE')),
                Expanded(flex: 3, child: ThCell('RÉGLÉ LE')),
                SizedBox(width: 60),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            if (liste.isEmpty)
              EmptyHint(_regle
                  ? 'Aucune $typeMot réglée'
                  : 'Aucune $typeMot en cours')
            else
              ...liste.asMap().entries.map((entry) {
                final e = entry.value;
                final isLast = entry.key == liste.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    color: e.solde ? Colors.white : const Color(0xFFFAFAFB),
                    border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(children: [
                    Expanded(flex: 2, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // Badge neutre : la couleur est réservée au statut,
                        // qui est la seule information à repérer d'un coup d'œil.
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.grayBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(e.estEntrant ? 'Créance' : 'Dette',
                              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text1)),
                        ),
                      ),
                    )),
                    _cell(e.documentNumero ?? '—', flex: 3, color: AppColors.primary, bold: true),
                    // Tiers + objet de l'engagement sur deux lignes.
                    Expanded(flex: 4, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(e.tiers, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text1)),
                        if (e.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
                        ],
                      ]),
                    )),
                    // Montant, et sous lui ce qui a déjà été réglé si un
                    // règlement partiel est déjà passé.
                    Expanded(flex: 3, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(Fmt.money(e.montant), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
                        if (e.regle > 0 && !e.solde) ...[
                          const SizedBox(height: 2),
                          Text('Réglé ${Fmt.money(e.regle)} · reste ${Fmt.money(e.reste)}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.blue)),
                        ],
                      ]),
                    )),
                    Expanded(flex: 2, child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: StatusBadge(status: _statutDe(e, now)),
                    )),
                    _cell(Fmt.jour(e.echeance), flex: 3, color: _statutDe(e, now) == 'retard' ? AppColors.red : AppColors.text2),
                    _cell(_dateTexte(e.solde ? _dernierReglement(e) : null), flex: 3, color: e.solde ? AppColors.green : AppColors.text3),
                    SizedBox(width: 60, child: _engagementMenu(context, state, e)),
                  ]),
                );
              }),
          ]),
        ),
      ),
    ]);
  }
}

/// Section de la comptabilité : un titre, éventuellement un sous-titre, puis
/// soit le tableau de bureau, soit la liste de cartes du téléphone.
///
/// Les deux sections de l'onglet Comptabilité partageaient déjà la même
/// structure ; ce widget évite de la réécrire avec le branchement responsive
/// en plus.
class _SectionCompta extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final bool vide;
  final String messageVide;
  final List<Widget> cartes;
  final Widget tableau;

  const _SectionCompta({
    required this.titre,
    required this.vide,
    required this.messageVide,
    required this.cartes,
    required this.tableau,
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final entete = <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(isPhone(context) ? 2 : 20, 0, 20, sousTitre == null ? 12 : 2),
        child: Text(titre, style: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
      ),
      if (sousTitre != null)
        Padding(
          padding: EdgeInsets.fromLTRB(isPhone(context) ? 2 : 20, 0, 20, 12),
          child: Text(sousTitre!, style: GoogleFonts.dmSans(
              fontSize: 12.5, color: AppColors.text3)),
        ),
    ];

    if (isPhone(context)) {
      // Le titre sort de la carte : sur téléphone chaque ligne est déjà une
      // carte, un cadre supplémentaire n'ajouterait qu'une bordure.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...entete,
        if (vide)
          CardBox(padding: EdgeInsets.zero, child: EmptyHint(messageVide))
        else
          ...cartes,
      ]);
    }

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: entete)),
        tableau,
      ]),
    );
  }
}

// ── Actions sur un engagement ──────────────────────────────

/// Statut affiché d'un engagement, dérivé (jamais stocké) : annulé, soldé, en
/// retard, ou en cours. `now` est un paramètre — jamais `DateTime.now()`
/// directement dans la logique — pour rester cohérent avec `Engagement.enRetard`.
String _statutDe(Engagement e, DateTime now) {
  if (e.annule) return 'annulee';
  if (e.solde) return 'paye';
  if (e.enRetard(now)) return 'retard';
  return 'cours';
}

/// Date du règlement le plus récent, ou `null` si aucun n'existe encore.
DateTime? _dernierReglement(Engagement e) {
  if (e.reglements.isEmpty) return null;
  return e.reglements.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

String _dateTexte(DateTime? d) => d == null ? '—' : Fmt.jour(d);

const _moyenLabels = {
  'especes': 'Espèces', 'virement': 'Virement', 'mobile': 'Mobile Money', 'cheque': 'Chèque',
};
String _moyenLabel(String m) => _moyenLabels[m] ?? m;

/// Solde en un geste : encaisse ou paie le RESTE dû à la date choisie. Un
/// engagement partiellement réglé n'est donc pas rejoué depuis zéro — seul ce
/// qui manque encore entre en comptabilité.
Future<void> _soldeEngagement(
    BuildContext context, AppState state, Engagement e) async {
  // Mêmes bornes que les autres sélecteurs de date de l'écran, et pas de
  // locale explicite : l'application n'enregistre aucun
  // localizationsDelegates, donc on s'en tient au défaut de MaterialApp.
  final d = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (d == null || !context.mounted) return;
  final montant = e.reste;
  if (montant <= 0) return; // déjà soldé entre-temps : rien à faire
  state.ajouterReglement(e.id, montant, d);
  if (!context.mounted) return;
  final entrant = Fmt.money(montant);
  final mois = Comptabilite.monthLabel(Comptabilite.monthKeyFromDate(d));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      e.estEntrant
          ? 'Créance encaissée : $entrant entrent en revenu ($mois).'
          : 'Dette payée : $entrant entrent en dépense ($mois).',
      style: const TextStyle(fontSize: 13),
    ),
    backgroundColor: e.estEntrant ? AppColors.green : AppColors.orange,
    duration: const Duration(seconds: 4),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.all(16),
  ));
}

/// Boîte d'ajout d'UN règlement (montant + date + moyen), plafonné au reste
/// dû. Utilisée par la gestion de la liste des règlements d'un engagement.
/// Retourne `true` si un règlement a effectivement été ajouté.
Future<bool> _ajouterReglementDialog(
    BuildContext context, AppState state, Engagement e) async {
  final ctrl = TextEditingController();
  var date = DateTime.now();
  var moyen = 'especes';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final saisi = double.tryParse(ctrl.text.replaceAll(' ', '')) ?? 0;
        final plafonne = saisi <= 0 ? 0.0 : (saisi > e.reste ? e.reste : saisi);
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Ajouter un règlement', style: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.tiers}\nReste dû : ${Fmt.money(e.reste)}',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3, height: 1.5)),
              const SizedBox(height: 16),
              Text('MONTANT (FCFA)', style: AppTheme.label),
              const SizedBox(height: 6),
              _tf(ctrl, '0', numeric: true, onChanged: (_) => setLocal(() {})),
              const SizedBox(height: 14),
              Text('DATE', style: AppTheme.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100),
                  );
                  if (d != null) setLocal(() => date = d);
                },
                child: Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.text3),
                    const SizedBox(width: 8),
                    Text(Fmt.jour(date), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Text('MOYEN', style: AppTheme.label),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: Reglement.moyens.map((m) => GestureDetector(
                onTap: () => setLocal(() => moyen = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: moyen == m ? AppColors.primary : AppColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: moyen == m ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(_moyenLabel(m), style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: moyen == m ? Colors.white : AppColors.text2)),
                ),
              )).toList()),
              if (saisi > e.reste) ...[
                const SizedBox(height: 12),
                Text('Plafonné au reste dû : ${Fmt.money(e.reste)}.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text2)),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
            ),
            TextButton(
              // Un montant nul ou négatif n'active pas le bouton : l'écran ne
              // doit jamais proposer une action que `ajouterReglement`
              // refuserait en silence.
              onPressed: plafonne <= 0 ? null : () {
                state.ajouterReglement(e.id, plafonne, date, moyen: moyen);
                Navigator.of(ctx).pop(true);
              },
              child: Text('Ajouter', style: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: plafonne <= 0 ? AppColors.text3 : AppColors.primary)),
            ),
          ],
        );
      },
    ),
  );

  ctrl.dispose();
  return ok == true;
}

/// Liste des règlements d'un engagement : chaque ligne peut être supprimée,
/// un bouton permet d'en ajouter un nouveau tant que l'engagement n'est ni
/// soldé ni annulé.
Future<void> _gererReglements(
    BuildContext context, AppState state, Engagement e) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        // Relit l'engagement à chaque rebuild : ajouter/supprimer un
        // règlement mute `state.engagements` sans reconstruire cette boîte
        // depuis l'extérieur.
        final courant = state.engagements.where((x) => x.id == e.id);
        if (courant.isEmpty) return const SizedBox.shrink();
        final c = courant.first;
        final regs = List.of(c.reglements)..sort((a, b) => a.date.compareTo(b.date));

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Règlements', style: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.tiers}\nMontant total : ${Fmt.money(c.montant)} · Reste dû : ${Fmt.money(c.reste)}',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3, height: 1.5)),
              const SizedBox(height: 14),
              if (regs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucun règlement enregistré.',
                      style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                )
              else
                ...regs.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: Text(
                      '${Fmt.jour(r.date)} · ${Fmt.money(r.montant)} · ${_moyenLabel(r.moyen)}',
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
                    )),
                    IconButton(
                      tooltip: 'Supprimer ce règlement',
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        state.supprimerReglement(c.id, r.id);
                        setLocal(() {});
                      },
                    ),
                  ]),
                )),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  // Un engagement soldé ou annulé n'accepte plus de
                  // règlement : le bouton est désactivé, pas juste inopérant.
                  onPressed: (c.solde || c.annule) ? null : () async {
                    final ajoute = await _ajouterReglementDialog(context, state, c);
                    if (ajoute) setLocal(() {});
                  },
                  icon: Icon(Icons.add, size: 16,
                      color: (c.solde || c.annule) ? AppColors.text3 : AppColors.primary),
                  label: Text('Ajouter un règlement', style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: (c.solde || c.annule) ? AppColors.text3 : AppColors.primary)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
            ),
          ],
        );
      },
    ),
  );
}

/// Rattache (ou change) le projet d'un engagement déjà créé — le cas d'un
/// engagement saisi avant que son projet n'existe. `clientId`, quand connu
/// (une créance née d'une facture le porte), fait remonter en tête les
/// projets de la même contrepartie, comme à la création.
Future<void> _rattacherProjetDialog(
    BuildContext context, AppState state, Engagement e) async {
  int? projetId = e.projetId;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Rattacher à un projet', style: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.tiers, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          const SizedBox(height: 12),
          _projetDropdown(
            _projetsPourSelecteur(state.projets, clientId: e.clientId, selectionne: projetId),
            projetId,
            (v) => setLocal(() => projetId = v),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(label: 'Enregistrer', icon: Icons.check, onTap: () {
          state.rattacherProjetEngagement(e.id, projetId);
          Navigator.of(ctx).pop();
        }),
      ],
    )),
  );
}

/// Fiche de lecture d'un engagement : tout ce que la ligne de tableau tronque
/// (description, règlement en cours) affiché en entier, sans possibilité
/// d'édition ni de suppression — ces gestes restent dans leurs boîtes
/// dédiées (« Gérer les règlements », etc.), pour ne jamais poser une action
/// destructive dans une boîte ouverte pour simplement lire.
Future<void> _detailEngagementDialog(
    BuildContext context, AppState state, Engagement e) async {
  final now = DateTime.now();
  final enRetard = e.enRetard(now);

  final clientTrouve = e.clientId == null
      ? null
      : state.clients.where((c) => c.id == e.clientId);
  final clientNom = (clientTrouve != null && clientTrouve.isNotEmpty)
      ? clientTrouve.first.name : null;

  final projetTrouve = e.projetId == null
      ? null
      : state.projets.where((p) => p.id == e.projetId);
  final projetNom = (projetTrouve != null && projetTrouve.isNotEmpty)
      ? projetTrouve.first.nom : null;

  final regs = List.of(e.reglements)..sort((a, b) => a.date.compareTo(b.date));

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        Expanded(child: Text(
          e.estEntrant ? 'Détail de la créance' : 'Détail de la dette',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1),
        )),
        StatusBadge(status: _statutDe(e, now)),
      ]),
      content: SizedBox(
        width: dialogWidth(context, 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field(e.estEntrant ? 'DÉBITEUR' : 'CRÉANCIER',
                Text(e.tiers, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1))),
            if (clientNom != null) ...[
              const SizedBox(height: 12),
              _field('CLIENT', Text(clientNom, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1))),
            ],
            const SizedBox(height: 12),
            _field('DESCRIPTION', Text(
              e.description.isEmpty ? '—' : e.description,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, height: 1.4),
            )),
            const SizedBox(height: 12),
            _field('MONTANT', Text(Fmt.money(e.montant),
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1))),
            const SizedBox(height: 12),
            _field('RÉGLÉ', Text(Fmt.money(e.regle),
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.blue))),
            const SizedBox(height: 12),
            _field('RESTE DÛ', Text(Fmt.money(e.reste),
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                    color: e.reste > 0 ? AppColors.red : AppColors.green))),
            const SizedBox(height: 12),
            _field('ÉCHÉANCE', Text(
              enRetard ? '${Fmt.jour(e.echeance)} · en retard' : Fmt.jour(e.echeance),
              style: GoogleFonts.dmSans(fontSize: 13, color: enRetard ? AppColors.red : AppColors.text1),
            )),
            const SizedBox(height: 12),
            _field('CATÉGORIE', Text(e.categorie, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1))),
            if (e.documentNumero != null) ...[
              const SizedBox(height: 12),
              _field('DOCUMENT LIÉ', Text(e.documentNumero!,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary))),
            ],
            if (projetNom != null) ...[
              const SizedBox(height: 12),
              _field('PROJET', Text(projetNom, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1))),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Text('RÈGLEMENTS', style: AppTheme.label),
            const SizedBox(height: 8),
            if (regs.isEmpty)
              Text('Aucun règlement enregistré.', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))
            else
              ...regs.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${Fmt.jour(r.date)} · ${Fmt.money(r.montant)} · ${_moyenLabel(r.moyen)}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
                ),
              )),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
        ),
      ],
    ),
  );
}

/// Menu d'actions d'un engagement, partagé par la ligne de tableau (bureau)
/// et la carte (téléphone) : solder, gérer les règlements, annuler/réactiver,
/// supprimer. Seule la taille de la cible change.
Widget _engagementMenu(
  BuildContext context,
  AppState state,
  Engagement e, {
  bool large = false,
}) {
  return PopupMenuButton<String>(
    tooltip: 'Actions',
    icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
    padding: EdgeInsets.all(large ? 8 : 6),
    constraints: BoxConstraints(
      minWidth: large ? 40 : 28,
      minHeight: large ? 40 : 28,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    color: Colors.white,
    onSelected: (action) {
      switch (action) {
        case 'detail':
          _detailEngagementDialog(context, state, e);
        case 'valider':
          _soldeEngagement(context, state, e);
        case 'reglements':
          _gererReglements(context, state, e);
        case 'projet':
          _rattacherProjetDialog(context, state, e);
        case 'annuler':
          state.annulerEngagement(e.id);
        case 'reactiver':
          state.reactiverEngagement(e.id);
        case 'supprimer':
          state.deleteEngagement(e.id);
      }
    },
    itemBuilder: (ctx) => [
      // Toujours en tête : lire avant d'agir, et le seul geste qui reste
      // pertinent quel que soit le statut de l'engagement.
      compactMenuItem(value: 'detail', icon: Icons.visibility_outlined,
          iconColor: AppColors.text2, label: 'Détail'),
      if (!e.solde && !e.annule)
        compactMenuItem(value: 'valider', icon: Icons.check_circle_outline,
            iconColor: AppColors.green,
            label: e.estEntrant ? 'Encaissée' : 'Marquer payée'),
      // Accessible tant que l'engagement peut porter des règlements, et en
      // consultation seule une fois soldé.
      compactMenuItem(value: 'reglements', icon: Icons.savings_outlined,
          iconColor: AppColors.blue,
          label: e.regle > 0 ? 'Gérer les règlements' : 'Enregistrer un règlement'),
      // N'apparaît que s'il existe au moins un projet à proposer — un
      // engagement créé avant que son projet n'existe reste rattachable
      // depuis ici.
      if (state.projets.isNotEmpty)
        compactMenuItem(value: 'projet', icon: Icons.link, iconColor: AppColors.blue,
            label: e.projetId == null ? 'Rattacher à un projet' : 'Changer de projet'),
      if (!e.annule)
        compactMenuItem(value: 'annuler', icon: Icons.block, iconColor: AppColors.text3,
            label: 'Annuler l\'engagement')
      else
        compactMenuItem(value: 'reactiver', icon: Icons.undo, iconColor: AppColors.text3,
            label: 'Réactiver'),
      compactMenuItem(value: 'supprimer', icon: Icons.delete_outline, iconColor: AppColors.red,
          label: 'Supprimer'),
    ],
  );
}

// ── Comptabilité Tab ──────────────────────────────────────
class _ComptaTab extends StatefulWidget {
  const _ComptaTab();
  @override
  State<_ComptaTab> createState() => _ComptaTabState();
}

class _ComptaTabState extends State<_ComptaTab> {
  final _labelCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _categorie = kCategoriesDepense.first;
  String? _factureNumero; // null = générale
  /// Projet auquel rattacher la dépense — même rôle que dans le formulaire
  /// créance/dette : c'est ce qui alimente `montantDepense` du projet.
  int? _projetId;
  /// Mois consulté. La comptabilité ne montre qu'un mois à la fois : au
  /// passage au mois suivant, l'écran repart à zéro sur le nouveau mois.
  String? _mois;
  bool _erreurDepense = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => Fmt.jour(d);

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  /// Enregistre la dépense saisie : un engagement sortant créé ET réglé le
  /// jour même. Retourne false si le formulaire est incomplet, pour que la
  /// boîte reste ouverte et signale ce qui manque.
  bool _addDepense(AppState state) {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(' ', '')) ?? 0;
    final libelle = _labelCtrl.text.trim();
    if (libelle.isEmpty || montant <= 0) return false;
    final id = DateTime.now().microsecondsSinceEpoch;
    state.addEngagement(Engagement(
      id: id, sens: 'sortant', tiers: libelle, montant: montant,
      echeance: _date, categorie: _categorie, documentNumero: _factureNumero,
      projetId: _projetId,
    ));
    state.ajouterReglement(id, montant, _date);
    return true;
  }

  /// Questionnaire de saisie d'une dépense — même forme que les créances et
  /// les dettes : un bouton, une boîte, la page reste sur les listes.
  Future<void> _ouvrirFormulaireDepense(AppState state, List<DocumentItem> factures) async {
    _labelCtrl.clear();
    _montantCtrl.clear();
    _date = DateTime.now();
    _categorie = kCategoriesDepense.first;
    _factureNumero = null;
    _projetId = null;
    _erreurDepense = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Nouvelle Dépense',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                    const SizedBox(height: 2),
                    Text('Imputée au mois de sa date.',
                        style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                  ])),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close, size: 18, color: AppColors.text2),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),

              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field('LIBELLÉ', _tf(_labelCtrl, 'Ex : Achat matériel')),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.end, children: [
                    _field('MONTANT (FCFA)', SizedBox(width: 190, child: _tf(_montantCtrl, '0', numeric: true))),
                    _field('DATE', GestureDetector(
                      onTap: () async {
                        final d = await _pickDate(_date);
                        if (d != null) setLocal(() => _date = d);
                      },
                      child: Container(
                        width: 190, height: 40,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.text3),
                          const SizedBox(width: 8),
                          Text(_fmtDate(_date), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                        ]),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  _field('RATTACHEMENT', _factureDropdown(factures, setLocal)),
                  // Masqué s'il n'existe aucun projet. Quand une facture est
                  // choisie ci-dessus, son client — connu via `clientId` —
                  // fait remonter ses projets en tête : une dépense rattachée
                  // à une facture porte presque toujours sur le même projet.
                  if (state.projets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Builder(builder: (_) {
                      final facture = factures.where((f) => f.numero == _factureNumero);
                      final clientId = facture.isEmpty ? null : facture.first.clientId;
                      return _field('PROJET', _projetDropdown(
                          _projetsPourSelecteur(state.projets, clientId: clientId, selectionne: _projetId),
                          _projetId,
                          (v) => setLocal(() => _projetId = v)));
                    }),
                  ],
                  const SizedBox(height: 16),
                  Text('CATÉGORIE', style: AppTheme.label),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: kCategoriesDepense.map((c) => GestureDetector(
                    onTap: () => setLocal(() => _categorie = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _categorie == c ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _categorie == c ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(c, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _categorie == c ? Colors.white : AppColors.text2)),
                    ),
                  )).toList()),

                  if (_erreurDepense) ...[
                    const SizedBox(height: 14),
                    Text('Renseignez le libellé et un montant supérieur à 0.',
                        style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red)),
                  ],
                ]),
              )),

              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  ),
                  const SizedBox(width: 8),
                  PrimaryBtn(label: 'Enregistrer', icon: Icons.check, onTap: () {
                    if (_addDepense(state)) {
                      Navigator.of(ctx).pop();
                    } else {
                      setLocal(() => _erreurDepense = true);
                    }
                  }),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// L'engagement entrant rattaché à cette facture, s'il en existe un —
  /// c'est lui qui porte les règlements d'encaissement.
  Engagement? _engagementFacture(List<Engagement> engagements, String numero) {
    for (final e in engagements) {
      if (e.estEntrant && e.documentNumero == numero) return e;
    }
    return null;
  }

  /// Bascule l'encaissement d'une facture. Faute d'engagement déjà lié, on en
  /// crée un (montant = somme des lignes de la facture) avant d'y porter le règlement — la
  /// génération automatique à la validation de la proforma est une évolution
  /// de phase 2, hors de ce lot.
  Future<void> _toggleEncaissement(
      AppState state, List<Engagement> engagements, DocumentItem f, Engagement? eng, bool v) async {
    if (v) {
      final d = await _pickDate(DateTime.now());
      if (d == null || !mounted) return;
      var cible = eng;
      if (cible == null) {
        final id = DateTime.now().microsecondsSinceEpoch;
        state.addEngagement(Engagement(
          id: id, sens: 'entrant', tiers: f.client, clientId: f.clientId,
          montant: Comptabilite.montantFacture(f),
          echeance: Comptabilite.parseJour(f.date) ?? d,
          documentNumero: f.numero,
        ));
        cible = state.engagements.firstWhere((e) => e.id == id);
      }
      state.ajouterReglement(cible.id, cible.reste, d);
    } else if (eng != null) {
      for (final r in List.of(eng.reglements)) {
        state.supprimerReglement(eng.id, r.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final factures = state.documents['facture'] ?? [];
    final engagements = state.engagements;
    final rows = Comptabilite.bilanMensuel(engagements, state.dimePaidMonths, state.dimePaidDates);

    // Mois consultables : ceux qui ont connu du mouvement, plus le mois en
    // cours (vide au premier jour du mois — c'est la « peau neuve »).
    final moisDispo = <String>{...rows.map((r) => r.monthKey), state.moisCourant}.toList()..sort();
    final mois = moisDispo.contains(_mois) ? _mois! : state.moisCourant;
    final estMoisCourant = mois == state.moisCourant;
    final bilan = Comptabilite.ligneMois(mois, rows);

    // Les factures dont l'engagement lié est soldé se rangent au mois de son
    // dernier règlement ; celles qui ne le sont pas encore restent sur le
    // mois en cours, puisque c'est là qu'on les bascule.
    final facturesMois = factures.where((f) {
      final eng = _engagementFacture(engagements, f.numero);
      if (eng != null && eng.solde) {
        final d = _dernierReglement(eng);
        return d != null && Comptabilite.monthKeyFromDate(d) == mois;
      }
      return estMoisCourant;
    }).toList();

    // Tout engagement soldé ce mois qui n'est pas déjà compté dans une
    // facture ci-dessus : dépenses ponctuelles, dettes et créances validées
    // depuis l'onglet Engagements. `documentNumero` n'écarte que les
    // engagements réellement rattachés à une facture EXISTANTE — une
    // simple référence libre reste visible ici.
    final numerosFactures = factures.map((f) => f.numero).toSet();
    final reglementsMois = engagements.where((e) {
      if (e.documentNumero != null && numerosFactures.contains(e.documentNumero)) return false;
      if (!e.solde) return false;
      final d = _dernierReglement(e);
      return d != null && Comptabilite.monthKeyFromDate(d) == mois;
    }).toList();

    return Column(children: [
      _selecteurMois(moisDispo, mois, estMoisCourant),
      const SizedBox(height: 16),

      // Synthèse du mois affiché
      StatGrid(cards: [
        StatCard(label: 'REVENU ENCAISSÉ', value: Fmt.number(bilan?.revenu ?? 0), unit: 'FCFA'),
        StatCard(label: 'DÉPENSES', value: Fmt.number(bilan?.depenses ?? 0), unit: 'FCFA'),
        StatCard(label: 'BÉNÉFICE', value: Fmt.number(bilan?.benefice ?? 0), unit: 'FCFA', red: (bilan?.benefice ?? 0) < 0),
        StatCard(label: 'DÎME (10%)', value: Fmt.number(bilan?.dime ?? 0), unit: 'FCFA'),
      ]),
      const SizedBox(height: 20),

      // La saisie se fait dans une boîte, comme pour les créances et les
      // dettes — et seulement sur le mois en cours : on n'écrit pas dans un
      // mois déjà clôturé.
      if (estMoisCourant) ...[
        // Bouton pleine largeur sur téléphone, aligné à droite sur bureau.
        SizedBox(
          width: double.infinity,
          child: Align(
            alignment: isPhone(context) ? Alignment.center : Alignment.centerRight,
            child: SizedBox(
              width: isPhone(context) ? double.infinity : null,
              child: PrimaryBtn(
                label: 'Nouvelle Dépense',
                icon: Icons.add,
                onTap: () => _ouvrirFormulaireDepense(state, factures),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],

      // Bénéfice par facture
      _SectionCompta(
        titre: 'Bénéfice par facture',
        vide: facturesMois.isEmpty,
        messageVide: 'Aucune facture sur ce mois',
        // Téléphone : une carte par facture.
        cartes: facturesMois.map((f) {
          final ht = Comptabilite.montantFacture(f);
          final dep = Comptabilite.depensesFacture(f.numero, engagements);
          final benef = ht - dep;
          final eng = _engagementFacture(engagements, f.numero);
          final encaissee = eng?.solde ?? false;
          final derniere = eng == null ? null : _dernierReglement(eng);
          return ListCard(
            accent: benef < 0 ? AppColors.red : AppColors.green,
            background: encaissee ? Colors.white : const Color(0xFFFAFAFB),
            title: Text(f.numero, style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            subtitle: Text(f.client, style: GoogleFonts.dmSans(
              fontSize: 13, color: AppColors.text1), maxLines: 1, overflow: TextOverflow.ellipsis),
            fields: [
              ('MONTANT', CardValue(Fmt.money(ht))),
              ('DÉPENSES', CardValue(Fmt.money(dep))),
              ('BÉNÉFICE', CardValue(Fmt.money(benef), bold: true,
                  color: benef < 0 ? AppColors.red : AppColors.text1)),
              // L'interrupteur d'encaissement reste accessible : c'est
              // l'action principale de cette liste.
              ('ENCAISSÉE', Row(children: [
                Switch(
                  value: encaissee,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => _toggleEncaissement(state, engagements, f, eng, v),
                ),
                Expanded(child: Text(
                  encaissee ? _dateTexte(derniere) : 'en attente',
                  style: GoogleFonts.dmSans(fontSize: 11.5,
                      color: encaissee ? AppColors.green : AppColors.text3),
                  overflow: TextOverflow.ellipsis,
                )),
              ])),
            ],
          );
        }).toList(),
        tableau: HScrollTable(minWidth: 820, child: Column(children: [
          Container(color: AppColors.bg, child: const Row(children: [
            Expanded(flex: 3, child: ThCell('N° FACTURE')),
            Expanded(flex: 4, child: ThCell('CLIENT')),
            Expanded(flex: 3, child: ThCell('MONTANT')),
            Expanded(flex: 3, child: ThCell('DÉPENSES')),
            Expanded(flex: 3, child: ThCell('BÉNÉFICE')),
            Expanded(flex: 3, child: ThCell('ENCAISSÉE')),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (facturesMois.isEmpty)
            const EmptyHint('Aucune facture sur ce mois')
          else
            ...facturesMois.map((f) => _factureRow(state, engagements, f)),
        ])),
      ),
      const SizedBox(height: 20),

      // Dettes & créances réglées — regroupe désormais aussi les dépenses
      // ponctuelles : depuis l'unification, une dette validée et une dépense
      // au comptant sont le même objet (un engagement sortant réglé).
      _SectionCompta(
        titre: 'Dettes & créances réglées',
        sousTitre: 'Réglés ce mois-ci : créances encaissées, dettes payées, et dépenses ponctuelles non rattachées à une facture.',
        vide: reglementsMois.isEmpty,
        messageVide: 'Aucun règlement sur ce mois',
        cartes: reglementsMois.map((e) => _reglementCard(state, e)).toList(),
        tableau: HScrollTable(minWidth: 760, child: Column(children: [
          Container(color: AppColors.bg, child: const Row(children: [
            Expanded(flex: 2, child: ThCell('TYPE')),
            Expanded(flex: 3, child: ThCell('RÉFÉRENCE')),
            Expanded(flex: 3, child: ThCell('TIERS')),
            Expanded(flex: 2, child: ThCell('CATÉGORIE')),
            Expanded(flex: 3, child: ThCell('MONTANT')),
            Expanded(flex: 2, child: ThCell('RÉGLÉ LE')),
            SizedBox(width: 48),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (reglementsMois.isEmpty)
            const EmptyHint('Aucun règlement sur ce mois')
          else
            ...reglementsMois.map((e) => _reglementRow(state, e)),
        ])),
      ),
    ]);
  }

  /// Sélecteur de mois : la comptabilité n'affiche qu'un mois à la fois.
  Widget _selecteurMois(List<String> dispo, String mois, bool courant) => CardBox(
    child: Wrap(spacing: 20, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('EXERCICE AFFICHÉ', style: AppTheme.label),
        const SizedBox(height: 4),
        Text(Comptabilite.monthLabel(mois),
            style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text1)),
      ]),
      Container(
        width: 190, height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: mois,
          isExpanded: true,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          items: dispo.reversed.map((k) => DropdownMenuItem<String>(
            value: k, child: Text(Comptabilite.monthLabel(k), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _mois = v),
        )),
      ),
      if (!courant)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.grayBg, borderRadius: BorderRadius.circular(20)),
          child: Text('Mois clôturé — consultation seule',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text2)),
        ),
    ]),
  );

  Widget _factureRow(AppState state, List<Engagement> engagements, DocumentItem f) {
    final ht = Comptabilite.montantFacture(f);
    final dep = Comptabilite.depensesFacture(f.numero, engagements);
    final benef = ht - dep;
    final eng = _engagementFacture(engagements, f.numero);
    final encaissee = eng?.solde ?? false;
    final derniere = eng == null ? null : _dernierReglement(eng);
    return Container(
      decoration: BoxDecoration(
        color: encaissee ? Colors.white : const Color(0xFFFAFAFB),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _cell(f.numero, flex: 3, color: AppColors.primary, bold: true),
        _cell(f.client, flex: 4),
        _cell(Fmt.money(ht), flex: 3),
        _cell(Fmt.money(dep), flex: 3),
        _cell(Fmt.money(benef), flex: 3, bold: true, color: benef < 0 ? AppColors.red : AppColors.text1),
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Switch(
              value: encaissee,
              activeThumbColor: AppColors.green,
              onChanged: (v) => _toggleEncaissement(state, engagements, f, eng, v),
            ),
            Expanded(child: Text(
              encaissee ? _dateTexte(derniere) : 'en attente',
              style: GoogleFonts.dmSans(fontSize: 11.5, color: encaissee ? AppColors.green : AppColors.text3),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        )),
      ]),
    );
  }

  Widget _reglementCard(AppState state, Engagement e) => ListCard(
    accent: e.estEntrant ? AppColors.green : AppColors.red,
    title: Text(e.tiers.isEmpty ? '—' : e.tiers, style: GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1),
      maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text('${e.estEntrant ? 'Créance' : 'Dette'} · ${e.documentNumero ?? '—'}',
        style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.primary)),
    trailing: IconButton(
      tooltip: 'Supprimer',
      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () => state.deleteEngagement(e.id),
    ),
    fields: [
      ('CATÉGORIE', CardValue(e.categorie)),
      ('MONTANT', CardValue('${e.estEntrant ? '+' : '−'} ${Fmt.money(e.montant)}',
          bold: true, color: e.estEntrant ? AppColors.green : AppColors.red)),
      ('RÉGLÉ LE', CardValue(_dateTexte(_dernierReglement(e)))),
    ],
  );

  Widget _reglementRow(AppState state, Engagement e) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      Expanded(flex: 2, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Align(alignment: Alignment.centerLeft, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: AppColors.grayBg, borderRadius: BorderRadius.circular(20)),
          child: Text(e.estEntrant ? 'Créance' : 'Dette',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text1)),
        )),
      )),
      _cell(e.documentNumero ?? '—', flex: 3, color: AppColors.primary),
      _cell(e.tiers.isEmpty ? '—' : e.tiers, flex: 3),
      _cell(e.categorie, flex: 2, color: AppColors.text2),
      _cell('${e.estEntrant ? '+' : '−'} ${Fmt.money(e.montant)}', flex: 3, bold: true,
          color: e.estEntrant ? AppColors.green : AppColors.red),
      _cell(_dateTexte(_dernierReglement(e)), flex: 2, color: AppColors.text2),
      SizedBox(width: 48, child: IconButton(
        tooltip: 'Supprimer',
        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
        onPressed: () => state.deleteEngagement(e.id),
      )),
    ]),
  );

  /// `rebuild` vient du StatefulBuilder de la boîte : c'est lui qu'il faut
  /// rafraîchir, pas l'onglet en arrière-plan.
  Widget _factureDropdown(List<DocumentItem> factures, StateSetter rebuild) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
      value: _factureNumero,
      isExpanded: true,
      hint: Text('Générale', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('Générale', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
        ...factures.map((f) => DropdownMenuItem<String?>(value: f.numero, child: Text(f.numero, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => rebuild(() => _factureNumero = v),
    )),
  );

}

// ── Fabriques partagées par les onglets ───────────────────
Widget _field(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(label, style: AppTheme.label),
  const SizedBox(height: 6),
  child,
]);

Widget _tf(TextEditingController c, String hint, {bool numeric = false, ValueChanged<String>? onChanged}) => SizedBox(
  height: 40,
  child: TextField(
    controller: c,
    onChanged: onChanged,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
      filled: true, fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
    ),
  ),
);

// ── Sélecteur de projet, partagé par les boîtes créance/dette/dépense et
//    par le rattachement d'un engagement existant. Même sémantique que le
//    sélecteur de document_create_screen.dart (projets annulés exclus, sauf
//    celui déjà choisi ; « Aucun projet » toujours en tête), mais avec le
//    vocabulaire propre à cet écran (DropdownButton, comme _factureDropdown)
//    plutôt que d'importer un idiome étranger.
//
// `clientId`, quand connu (un engagement entrant généré depuis une facture
// porte le sien), fait remonter les projets de ce client en tête — un
// engagement se rattache presque toujours à un projet de la même contrepartie.
List<Projet> _projetsPourSelecteur(List<Projet> projets, {int? clientId, int? selectionne}) {
  final utilisables = projets.where((p) => !p.annule || p.id == selectionne).toList();
  if (clientId == null) return utilisables;
  final duClient = utilisables.where((p) => p.clientId == clientId).toList();
  final autres = utilisables.where((p) => p.clientId != clientId).toList();
  return [...duClient, ...autres];
}

Widget _projetDropdown(List<Projet> projets, int? valeur, ValueChanged<int?> onChanged) => Container(
  height: 40,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
  child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
    value: valeur,
    isExpanded: true,
    hint: Text('Aucun projet', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
    items: [
      DropdownMenuItem<int?>(value: null, child: Text('Aucun projet', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
      ...projets.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.nom, overflow: TextOverflow.ellipsis))),
    ],
    onChanged: onChanged,
  )),
);

Widget _cell(String text, {int flex = 1, Color color = AppColors.text1, bool bold = false}) => Expanded(
  flex: flex,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
  ),
);

// ── Dîme Tab (recalculée sur le bénéfice mensuel) ─────────
class _DimeTab extends StatelessWidget {
  const _DimeTab();

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = Comptabilite.bilanMensuel(
        state.engagements, state.dimePaidMonths, state.dimePaidDates);
    final totalBenef = rows.fold<double>(0, (s, r) => s + (r.benefice > 0 ? r.benefice : 0));
    final totalDime = rows.fold<double>(0, (s, r) => s + r.dime);
    final totalPaye = rows.where((r) => r.dimePaid).fold<double>(0, (s, r) => s + r.dime);

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'BÉNÉFICE (MOIS +)', value: Fmt.number(totalBenef), unit: 'FCFA'),
        StatCard(label: 'DÎME TOTALE (10%)', value: Fmt.number(totalDime), unit: 'FCFA', red: true),
        StatCard(label: 'DÉJÀ VERSÉ', value: Fmt.number(totalPaye), unit: 'FCFA'),
      ]),
      const SizedBox(height: 20),
      CardBox(padding: EdgeInsets.zero, child: HScrollTable(minWidth: 880, child: Column(children: [
        Container(color: AppColors.bg, child: const Row(children: [
          Expanded(flex: 3, child: ThCell('MOIS')),
          Expanded(flex: 3, child: ThCell('BÉNÉFICE')),
          Expanded(flex: 3, child: ThCell('DÎME (10%)')),
          Expanded(flex: 2, child: ThCell('STATUT')),
          Expanded(flex: 3, child: ThCell('DATE VERSEMENT')),
          SizedBox(width: 56),
        ])),
        const Divider(height: 1, color: AppColors.border),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Aucune activité', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))))
        else
          ...rows.map((r) => Container(
            decoration: BoxDecoration(
              color: (!r.dimePaid && r.dime > 0) ? const Color(0xFFFFFBEB) : Colors.white,
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              _dcell(r.label, flex: 3, bold: true),
              _dcell(Fmt.money(r.benefice), flex: 3, color: r.benefice < 0 ? AppColors.red : AppColors.text1),
              _dcell(Fmt.money(r.dime), flex: 3, color: AppColors.primary, bold: true),
              Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: StatusBadge(status: r.dimePaid ? 'paye' : 'attente'),
              )),
              _dcell(r.dimeDate ?? '—', flex: 3, color: AppColors.text2),
              SizedBox(width: 56, child: (r.dime > 0 && !r.dimePaid)
                ? IconButton(
                    tooltip: 'Marquer versée',
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
                    onPressed: () => state.setDimePaid(r.monthKey, true, date: _fmtDate(DateTime.now())),
                  )
                : (r.dimePaid
                    ? IconButton(
                        tooltip: 'Annuler le versement',
                        icon: const Icon(Icons.undo, size: 16, color: AppColors.text3),
                        onPressed: () => state.setDimePaid(r.monthKey, false),
                      )
                    : const SizedBox())),
            ]),
          )),
      ]))),
    ]);
  }

  Widget _dcell(String text, {int flex = 1, Color color = AppColors.text1, bool bold = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    ),
  );
}

// ── Tâches Tab ────────────────────────────────────────────
class _TachesTab extends StatefulWidget {
  const _TachesTab();

  @override
  State<_TachesTab> createState() => _TachesTabState();
}

class _TachesTabState extends State<_TachesTab> {
  final _ctrl = TextEditingController();
  final _titreCtrl = TextEditingController();
  String _priorite = 'normale';

  static const _priorites = ['haute', 'normale', 'basse'];
  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};
  static const _priorityLabels = {'haute': 'Haute', 'normale': 'Normale', 'basse': 'Basse'};

  @override
  void dispose() {
    _ctrl.dispose();
    _titreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.tasks;
    final done = tasks.where((t) => t.done).length;

    return ResponsiveSplit(
      sideWidth: 300,
      breakpoint: 760,
      main: Column(children: [
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Tâches en cours', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            const Spacer(),
            Text('$done/${tasks.length} terminées', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(value: tasks.isEmpty ? 0 : (done / tasks.length * 100).round(), color: AppColors.primary, height: 6),
          const SizedBox(height: 16),
          ...tasks.map((t) => _TaskItem(task: t)),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucune tâche', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
            ),
        ])),
      ]),

      // Add task form
      side: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nouvelle tâche', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Description de la tâche...',
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        Text('TITRE', style: AppTheme.label),
        const SizedBox(height: 6),
        TextField(
          controller: _titreCtrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          decoration: InputDecoration(
            hintText: 'Ex : Facturation, Relance client...',
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Text('PRIORITÉ', style: AppTheme.label),
        const SizedBox(height: 6),
        Row(children: _priorites.map((p) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _priorite = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _priorite == p ? _priorityColors[p]!.withValues(alpha: 0.12) : AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _priorite == p ? _priorityColors[p]! : AppColors.border),
              ),
              child: Text(_priorityLabels[p]!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _priorite == p ? _priorityColors[p]! : AppColors.text2)),
            ),
          ),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: PrimaryBtn(
          label: 'Ajouter la tâche',
          onTap: () {
            if (_ctrl.text.trim().isNotEmpty) {
              context.read<AppState>().addTask(Task(
                id: DateTime.now().millisecondsSinceEpoch,
                texte: _ctrl.text.trim(),
                titre: _titreCtrl.text.trim(),
                priorite: _priorite,
              ));
              _ctrl.clear();
              _titreCtrl.clear();
            }
          },
        )),
      ])),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  const _TaskItem({required this.task});

  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.read<AppState>().toggleTask(task.id),
          child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: task.done ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: task.done ? AppColors.green : AppColors.border, width: 1.5),
            ),
            child: task.done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.texte, style: GoogleFonts.dmSans(
            fontSize: 13.5, fontWeight: FontWeight.w500,
            color: task.done ? AppColors.text3 : AppColors.text1,
            decoration: task.done ? TextDecoration.lineThrough : null,
          )),
          if (task.titre.isNotEmpty)
            Text(task.titre, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
        ])),
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: _priorityColors[task.priorite] ?? AppColors.text3, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.read<AppState>().deleteTask(task.id),
          child: const Icon(Icons.close, size: 14, color: AppColors.text3),
        ),
      ]),
    );
  }
}

// ── Notes Tab ─────────────────────────────────────────────
class _NotesTab extends StatefulWidget {
  const _NotesTab();

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  Note? _editing;

  // Suppression directe depuis la carte, avec confirmation simple
  void _confirmDeleteNote(Note n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer cette note ?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: Text(
          '« ${n.titre.isEmpty ? 'Sans titre' : n.titre} » sera supprimée définitivement.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteNote(n.id);
              if (_editing?.id == n.id) setState(() => _editing = null);
              Navigator.of(ctx).pop();
            },
            child: Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<AppState>().notes;
    // Notes grid using Wrap — avoids Expanded constraint issues
    final grid = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ...notes.map((n) => SizedBox(
          width: 240,
          height: 180,
          child: _NoteCard(
            note: n,
            onTap: () => setState(() => _editing = n),
            onDelete: () => _confirmDeleteNote(n),
          ),
        )),
        SizedBox(
          width: 240,
          height: 180,
          child: _AddNoteCard(onTap: () => setState(() => _editing = Note(
            id: DateTime.now().millisecondsSinceEpoch,
            titre: '', contenu: '', color: AppColors.blue, date: "Aujourd'hui",
          ))),
        ),
      ],
    );
    if (_editing == null) return grid;
    return ResponsiveSplit(
      sideWidth: 300,
      breakpoint: 760,
      main: grid,
      side: _NoteEditor(
        note: _editing!,
        onSave: (n) {
          context.read<AppState>().saveNote(n);
          setState(() => _editing = null);
        },
        onDelete: () {
          context.read<AppState>().deleteNote(_editing!.id);
          setState(() => _editing = null);
        },
        onClose: () => setState(() => _editing = null),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onTap, required this.onDelete});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? [BoxShadow(color: n.color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Bandeau d'accent coloré en haut de la carte
            Container(height: 3, color: n.color),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.titre.isEmpty ? 'Sans titre' : n.titre, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // Bouton de suppression directe, toujours visible
                  Tooltip(
                    message: 'Supprimer la note',
                    child: InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                // Expanded : le contenu occupe tout l'espace disponible
                // et la date reste collée en bas de la carte
                Expanded(child: Text(n.contenu, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 8),
                Text(n.date, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

class _AddNoteCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddNoteCard({required this.onTap});

  @override
  State<_AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends State<_AddNoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, size: 28, color: _hovered ? AppColors.primary : AppColors.text3),
            const SizedBox(height: 8),
            Text('Nouvelle note', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: _hovered ? AppColors.primary : AppColors.text3)),
          ]),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final Note note;
  final ValueChanged<Note> onSave;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _NoteEditor({required this.note, required this.onSave, required this.onDelete, required this.onClose});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late TextEditingController _titreCtrl;
  late TextEditingController _contenuCtrl;
  late Color _color;

  static const _colors = [AppColors.blue, AppColors.orange, AppColors.emerald, AppColors.purple, AppColors.red];

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController(text: widget.note.titre);
    _contenuCtrl = TextEditingController(text: widget.note.contenu);
    _color = widget.note.color;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _contenuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Éditer la note', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const Spacer(),
        GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, size: 16, color: AppColors.text3)),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: _titreCtrl,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1),
        decoration: InputDecoration(
          hintText: 'Titre de la note',
          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const Divider(color: AppColors.border),
      const SizedBox(height: 8),
      TextField(
        controller: _contenuCtrl,
        maxLines: 8,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Contenu de la note...',
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const SizedBox(height: 12),
      Text('COULEUR', style: AppTheme.label),
      const SizedBox(height: 8),
      Row(children: _colors.map((c) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: _color == c ? AppColors.text1 : Colors.transparent, width: 2),
            ),
          ),
        ),
      )).toList()),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: PrimaryBtn(label: 'Enregistrer', onTap: () {
          final updated = widget.note
            ..titre = _titreCtrl.text
            ..contenu = _contenuCtrl.text
            ..color = _color;
          widget.onSave(updated);
        })),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
          onPressed: widget.onDelete,
          padding: const EdgeInsets.all(8),
        ),
      ]),
    ]));
  }
}
