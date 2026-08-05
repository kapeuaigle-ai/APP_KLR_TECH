import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/avancement.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

/// Kanban des projets, en lecture seule.
///
/// La colonne d'une carte se déduit de son avancement physique et financier
/// (`Avancement.calculer(...).statut`) — jamais saisie à la main. Un projet
/// qui stockerait sa colonne pourrait mentir ; un projet calculé ne le peut
/// pas. Conséquence assumée : plus de glisser-déposer.
class ProjetsScreen extends StatefulWidget {
  const ProjetsScreen({super.key});

  @override
  State<ProjetsScreen> createState() => _ProjetsScreenState();
}

class _ProjetsScreenState extends State<ProjetsScreen> {
  /// Un projet annulé n'a pas sa place dans une colonne du Kanban (aucune
  /// des quatre ne correspond à `StatutProjet.annule`), mais doit rester
  /// atteignable — sinon l'annulation équivaut à une suppression muette.
  /// Ce filtre bascule entre le tableau normal et une liste unique des
  /// projets annulés, à défaut d'une cinquième colonne qui n'aurait aucun
  /// sens dans un flux de travail.
  bool _showAnnules = false;

  /// Une colonne par statut, hors `annule` : un projet annulé disparaît
  /// simplement du tableau plutôt que d'occuper une colonne dédiée.
  static const _colonnes = [
    StatutProjet.aDemarrer,
    StatutProjet.enCours,
    StatutProjet.termineNonPaye,
    StatutProjet.termine,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final projetsAnnules = state.projets.where((p) => p.annule).toList();
    final projets = _showAnnules
        ? projetsAnnules
        : state.projets.where((p) => !p.annule).toList();
    final avancements = {
      for (final p in projets) p.id: state.avancementProjet(p.id),
    };

    final parColonne = <StatutProjet, List<Projet>>{
      for (final s in _colonnes) s: <Projet>[],
    };
    if (!_showAnnules) {
      for (final p in projets) {
        parColonne[avancements[p.id]!.statut]?.add(p);
      }
    }

    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Projets',
            subtitle: 'Tableau Kanban en lecture seule : la colonne se '
                'déduit de l\'avancement réalisé / encaissé.',
            actions: [
              // Toujours visible, même à 0 : c'est la seule porte d'entrée
              // vers les projets annulés — les cacher au compteur nul les
              // rendrait à nouveau introuvables.
              AppFilterChip(
                label: 'Annulés (${projetsAnnules.length})',
                active: _showAnnules,
                onTap: () => setState(() => _showAnnules = !_showAnnules),
              ),
              SecondaryBtn(label: 'Gantt', icon: Icons.bar_chart_rounded,
                  onTap: () => context.read<AppState>().navigate(NavScreen.gantt)),
              PrimaryBtn(label: 'Nouveau projet', icon: Icons.add,
                  onTap: () => _ouvrirFormulaireProjet(context, state)),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: projets.isEmpty
                ? Center(child: CardBox(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      _showAnnules ? 'Aucun projet annulé.' : 'Aucun projet enregistré.',
                      style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3),
                    ),
                  ))
                : _showAnnules
                    ? SingleChildScrollView(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: projets.map((p) => _ProjetCard(
                            projet: p,
                            avancement: avancements[p.id]!,
                          )).toList(),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _colonnes.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: _KanbanColonne(
                              statut: s,
                              projets: parColonne[s]!,
                              avancements: avancements,
                            ),
                          )).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Colonne (déduite, pas de DragTarget)
// ─────────────────────────────────────────────────────────
class _KanbanColonne extends StatelessWidget {
  final StatutProjet statut;
  final List<Projet> projets;
  final Map<int, Avancement> avancements;
  const _KanbanColonne({required this.statut, required this.projets, required this.avancements});

  static const _couleurs = {
    StatutProjet.aDemarrer: AppColors.text3,
    StatutProjet.enCours: AppColors.blue,
    StatutProjet.termineNonPaye: AppColors.orange,
    StatutProjet.termine: AppColors.green,
  };

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurs[statut] ?? AppColors.text3;
    return Container(
      // Clé par statut : c'est par elle qu'un test cible le `Scrollable`
      // d'une colonne précise parmi les quatre (§ défilement par colonne).
      key: ValueKey('colonne-${statut.name}'),
      width: 280,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              // `Flexible` et non `Expanded` : le titre ne prend que la place
              // qu'il lui faut, et le compteur le suit immédiatement. Avec
              // `Expanded` il occupait les 280 px de la colonne et repoussait
              // le compteur contre le bord droit, loin du titre qu'il compte.
              Flexible(child: Text(statut.libelle,
                  style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                child: Text('${projets.length}',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // La colonne défile verticalement pour son propre compte : avec
          // neuf cartes dans « En cours » et trois visibles à l'écran, rien
          // d'autre ne rendait les six suivantes atteignables. `Expanded`
          // ici est valide parce que le `Row` parent (dans une
          // `SingleChildScrollView` horizontale, elle-même dans l'`Expanded`
          // de l'écran) transmet déjà une hauteur bornée à chaque colonne —
          // sans quoi `Expanded` lèverait une exception de hauteur infinie.
          // L'en-tête ci-dessus reste hors de ce `SingleChildScrollView` :
          // il ne défile jamais, contrairement aux cartes.
          Expanded(
            child: projets.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Aucun projet',
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: projets.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProjetCard(projet: p, avancement: avancements[p.id]!),
                      )).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Carte projet — lecture seule, pas de Draggable
// ─────────────────────────────────────────────────────────
class _ProjetCard extends StatelessWidget {
  final Projet projet;
  final Avancement avancement;
  const _ProjetCard({required this.projet, required this.avancement});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Relancer n'a de sens que s'il reste réellement quelque chose à
    // percevoir, ET que le moment de réclamer est venu : soit l'échéance du
    // projet est passée — c'est le motif même de « En révision » — soit une
    // créance est elle-même échue alors que le projet, lui, tient encore ses
    // délais. Un projet Terminé a tout encaissé (`resteAPercevoir` est
    // faux) : il ne doit jamais proposer de relance.
    final resteAPercevoir = state.engagementsDuProjet(projet.id)
        .any((e) => e.estEntrant && !e.annule && !e.solde);
    final aRelancer = resteAPercevoir &&
        (avancement.finDepassee || avancement.enRetardPaiement);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _ouvrirFicheProjet(context, projet),
      child: Container(
        width: 264,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(projet.nom, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(projet.client.isEmpty ? 'Projet interne' : projet.client,
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            ])),
            // Les actions vivent directement sur la carte : le manager n'a
            // pas à ouvrir la fiche pour relancer un client, reporter une
            // échéance, corriger un champ ou annuler. « Supprimer » reste
            // volontairement absent d'ici — irréversible, il reste sur la
            // fiche derrière sa confirmation (§ garde-fou).
            PopupMenuButton<String>(
              tooltip: 'Actions',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.text3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              color: Colors.white,
              onSelected: (action) {
                switch (action) {
                  case 'relancer':
                    state.navigate(NavScreen.suivi);
                  case 'reporter':
                    _reporterEcheance(context, state, projet);
                  case 'modifier':
                    _ouvrirFormulaireProjet(context, state, existing: projet);
                  case 'annuler':
                    state.annulerProjet(projet.id);
                  case 'reactiver':
                    state.reactiverProjet(projet.id);
                }
              },
              // Un projet annulé n'a plus de client à relancer ni d'échéance
              // à reporter, et « Annuler le projet » y serait un geste sans
              // effet visible — le manager cliquerait sans rien voir changer
              // et douterait que l'app ait enregistré quoi que ce soit. La
              // carte suit donc la même distinction que la fiche (§ !annule) :
              // seuls Réactiver et Modifier restent pertinents. « Supprimer »
              // reste absent d'ici dans les deux cas — irréversible, il reste
              // sur la fiche derrière sa confirmation (§ garde-fou).
              itemBuilder: (_) => projet.annule
                  ? [
                      PopupMenuItem(value: 'reactiver', child: Row(children: [
                        const Icon(Icons.undo, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Réactiver', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                      PopupMenuItem(value: 'modifier', child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Modifier', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                    ]
                  : [
                      if (aRelancer)
                        PopupMenuItem(value: 'relancer', child: Row(children: [
                          const Icon(Icons.call_outlined, size: 15, color: AppColors.text3),
                          const SizedBox(width: 8),
                          Text('Relancer le client', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                        ])),
                      PopupMenuItem(value: 'reporter', child: Row(children: [
                        const Icon(Icons.event_repeat_outlined, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Reporter l\'échéance', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                      PopupMenuItem(value: 'modifier', child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Modifier', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                      PopupMenuItem(value: 'annuler', child: Row(children: [
                        const Icon(Icons.block, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Annuler le projet', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                    ],
            ),
          ]),
          // Rien démarré et l'échéance est passée : le seul rappel que reçoit
          // le manager, puisque la colonne ne bouge pas (§ règle 3 avant
          // règle 4 — un projet jamais lancé peut n'avoir aucun client à
          // renégocier). N'apparaît que sur « À démarrer » : ailleurs,
          // « En révision » *est* déjà le signal.
          if (avancement.statut == StatutProjet.aDemarrer && avancement.finDepassee) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Échéance atteinte',
                    style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _LigneAvancement(label: 'Réalisé', fraction: avancement.physique, couleur: AppColors.primary),
          const SizedBox(height: 8),
          _LigneAvancement(label: 'Encaissé', fraction: avancement.financier, couleur: AppColors.blue),
          const SizedBox(height: 12),
          Row(children: [
            Text('Attendu', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
            const Spacer(),
            Text(Fmt.money(avancement.montantAttendu),
                style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('Reste dû', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
            const Spacer(),
            Text(Fmt.money(avancement.montantRestant),
                style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700,
                    color: avancement.enRetardPaiement ? AppColors.red : AppColors.text1)),
          ]),
        ]),
      ),
    );
  }
}

class _LigneAvancement extends StatelessWidget {
  final String label;
  final double fraction;
  final Color couleur;
  const _LigneAvancement({required this.label, required this.fraction, required this.couleur});

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
        const Spacer(),
        Text('$pct %', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2)),
      ]),
      const SizedBox(height: 4),
      ProgressBar(value: pct, color: couleur),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Boîte de saisie : décoration commune aux champs
// ─────────────────────────────────────────────────────────
InputDecoration _deco(BuildContext context, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
  filled: true, fillColor: AppColors.bg,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  isDense: true,
);

// ─────────────────────────────────────────────────────────
//  Action « Reporter l'échéance » — depuis le menu de la carte
// ─────────────────────────────────────────────────────────
/// `firstDate: projet.debut` empêche déjà, dans le calendrier lui-même, de
/// choisir une date antérieure au début — `AppState.reporterEcheance`
/// refuse quand même la même règle en profondeur (`Projet.periodeValide`),
/// au cas où cette action serait un jour appelée autrement que d'ici.
Future<void> _reporterEcheance(BuildContext context, AppState state, Projet projet) async {
  final d = await showDatePicker(
    context: context,
    initialDate: projet.finPrevue,
    firstDate: projet.debut,
    lastDate: DateTime(2100),
  );
  if (d != null) state.reporterEcheance(projet.id, d);
}

Widget _champDate(BuildContext context, String label, DateTime valeur, ValueChanged<DateTime> onPicked) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.label),
    const SizedBox(height: 6),
    GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
            context: context, initialDate: valeur, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (d != null) onPicked(d);
      },
      child: Container(
        height: 40,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.text3),
          const SizedBox(width: 8),
          Text(Fmt.jour(valeur), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
        ]),
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────
//  Boîte « Nouveau projet » / édition des champs de base
// ─────────────────────────────────────────────────────────
void _ouvrirFormulaireProjet(BuildContext context, AppState state, {Projet? existing}) {
  final nomCtrl = TextEditingController(text: existing?.nom ?? '');
  int? clientId = existing?.clientId;
  String client = existing?.client ?? '';
  String typeId = existing?.typeId ?? state.settings.typesProjet.first.id;
  DateTime debut = existing?.debut ?? DateTime.now();
  DateTime finPrevue = existing?.finPrevue ?? DateTime.now().add(const Duration(days: 30));
  var erreur = false;
  var erreurDates = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(existing == null ? 'Nouveau projet' : 'Modifier le projet',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: dialogWidth(ctx, 440),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOM DU PROJET *', style: AppTheme.label),
            const SizedBox(height: 6),
            TextField(controller: nomCtrl, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
                decoration: _deco(ctx, 'Ex : Fourniture matériel — ACME')),
            const SizedBox(height: 12),
            Text('CLIENT', style: AppTheme.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              initialValue: clientId,
              decoration: _deco(ctx, 'Projet interne'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Projet interne')),
                ...state.clients.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setLocal(() {
                clientId = v;
                final m = state.clients.where((c) => c.id == v);
                client = m.isEmpty ? '' : m.first.name;
              }),
            ),
            const SizedBox(height: 12),
            Text('TYPE', style: AppTheme.label),
            const SizedBox(height: 6),
            // Les types du manager — définis dans les Paramètres, jamais
            // une liste figée dans le code (§ 5.4 de la conception).
            Wrap(spacing: 8, runSpacing: 8, children: state.settings.typesProjet.map((t) => GestureDetector(
              onTap: () => setLocal(() => typeId = t.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeId == t.id ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeId == t.id ? AppColors.primary : AppColors.border),
                ),
                child: Text(t.libelle, style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: typeId == t.id ? AppColors.primary : AppColors.text2)),
              ),
            )).toList()),
            const SizedBox(height: 8),
            // Comment son avancement sera mesuré, avant qu'il ne valide —
            // pour que le choix du type ne soit jamais un pari (§ 11).
            Builder(builder: (_) {
              final m = state.settings.typesProjet.where((t) => t.id == typeId);
              final mode = m.isEmpty ? null : m.first.mode;
              if (mode == null) return const SizedBox.shrink();
              return Text(mode.explication,
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3));
            }),
            // Sur un projet existant, la reclassification reste permise —
            // mais un jalon déjà coché ou une quantité déjà livrée changerait
            // de mode d'avancement sans un mot (§ défaut 4 de la revue
            // finale). L'avertissement ne remplace jamais le champ : il
            // prévient juste avant l'enregistrement.
            if (existing != null)
              Builder(builder: (_) {
                final ancien = state.typeProjet(existing.typeId)?.mode;
                final m = state.settings.typesProjet.where((t) => t.id == typeId);
                final nouveau = m.isEmpty ? null : m.first.mode;
                if (ancien == null || nouveau == null || ancien == nouveau) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Ce projet était mesuré par « ${ancien.libelle} » : ${ancien.explication} '
                        'Avec ce type, il sera désormais mesuré par « ${nouveau.libelle} » : ${nouveau.explication}',
                        style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text2, height: 1.4),
                      )),
                    ]),
                  ),
                );
              }),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _champDate(ctx, 'DÉBUT', debut, (d) => setLocal(() => debut = d))),
              const SizedBox(width: 12),
              Expanded(child: _champDate(ctx, 'FIN PRÉVUE', finPrevue, (d) => setLocal(() => finPrevue = d))),
            ]),
            if (erreur) ...[
              const SizedBox(height: 12),
              Text('Renseignez un nom de projet.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red)),
            ],
            if (erreurDates) ...[
              const SizedBox(height: 12),
              Text('La fin prévue ne peut pas être antérieure au début.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(
          label: existing == null ? 'Créer' : 'Enregistrer',
          icon: existing == null ? Icons.add : Icons.check,
          onTap: () {
            final nom = nomCtrl.text.trim();
            if (nom.isEmpty) { setLocal(() => erreur = true); return; }
            // Même règle que Projet.periodeValide (§ défaut 4) : une durée
            // négative rendrait le Gantt et tous les retards incohérents.
            if (finPrevue.isBefore(debut)) { setLocal(() => erreurDates = true); return; }
            if (existing == null) {
              state.addProjet(Projet(
                id: DateTime.now().millisecondsSinceEpoch,
                nom: nom, typeId: typeId, clientId: clientId, client: client,
                debut: debut, finPrevue: finPrevue,
              ));
            } else {
              state.updateProjet(existing
                ..nom = nom
                ..typeId = typeId
                ..clientId = clientId
                ..client = client
                ..debut = debut
                ..finPrevue = finPrevue);
            }
            Navigator.of(ctx).pop();
          },
        ),
      ],
    )),
  );
}

// ─────────────────────────────────────────────────────────
//  Fiche projet — avancement détaillé, ouverte depuis la carte
// ─────────────────────────────────────────────────────────
void _ouvrirFicheProjet(BuildContext context, Projet projet) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth(ctx, 520), maxHeight: 640),
        child: Consumer<AppState>(builder: (ctx, state, _) {
          // Le projet a pu être supprimé pendant que la fiche était ouverte.
          final vivant = state.projets.any((p) => p.id == projet.id);
          if (!vivant) return const SizedBox(width: 400, height: 100);
          final avancement = state.avancementProjet(projet.id);
          final mode = state.modeDuProjet(projet);

          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(projet.nom, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                  const SizedBox(height: 2),
                  Text(projet.client.isEmpty ? 'Projet interne' : projet.client,
                      style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                ])),
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.text2),
                  onPressed: () => _ouvrirFormulaireProjet(ctx, state, existing: projet),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.text2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  color: Colors.white,
                  onSelected: (action) {
                    switch (action) {
                      case 'annuler':
                        state.annulerProjet(projet.id);
                      case 'reactiver':
                        state.reactiverProjet(projet.id);
                      case 'supprimer':
                        _confirmerSuppressionProjet(ctx, state, projet);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!projet.annule)
                      PopupMenuItem(value: 'annuler', child: Row(children: [
                        const Icon(Icons.block, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Annuler le projet', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ]))
                    else
                      PopupMenuItem(value: 'reactiver', child: Row(children: [
                        const Icon(Icons.undo, size: 15, color: AppColors.text3),
                        const SizedBox(width: 8),
                        Text('Réactiver', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                      ])),
                    PopupMenuItem(value: 'supprimer', child: Row(children: [
                      const Icon(Icons.delete_outline, size: 15, color: AppColors.red),
                      const SizedBox(width: 8),
                      Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
                    ])),
                  ],
                ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(avancement.statut.libelle,
                      style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text2)),
                ),
                // Un `typeId` orphelin (type supprimé, restauration d'une
                // sauvegarde plus ancienne) fait retomber `modeDuProjet` sur
                // `quantites` en silence — le manager doit au moins le savoir.
                if (state.typeProjet(projet.typeId) == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Le type de ce projet n\'existe plus : son avancement est '
                    'mesuré par défaut sur les quantités livrées.',
                    style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.orange, height: 1.4),
                  ),
                ],
                const SizedBox(height: 16),
                _LigneAvancement(label: 'Réalisé', fraction: avancement.physique, couleur: AppColors.primary),
                const SizedBox(height: 12),
                _LigneAvancement(label: 'Encaissé', fraction: avancement.financier, couleur: AppColors.blue),
                const SizedBox(height: 16),
                _ligneMontant('Montant attendu', avancement.montantAttendu),
                _ligneMontant('Encaissé', avancement.montantEncaisse),
                _ligneMontant('Reste dû', avancement.montantRestant),
                _ligneMontant('Décaissé', avancement.montantDepense),
                _LigneMarge(marge: avancement.marge),

                // ── Avancement, selon le mode du type de projet ─────
                // Chaque mode a sa propre façon de saisir l'avancement ;
                // n'en montrer qu'une évite qu'un manager voie, par exemple,
                // un champ de quantité livrée sur un contrat de maintenance.
                _SectionSuivi(projet: projet, mode: mode, state: state),
              ]),
            )),
          ]);
        }),
      ),
    ),
  );
}

/// Supprimer un projet ne supprime ni ses documents ni ses engagements —
/// `AppState.deleteProjet` les délie seulement (`projetId` remis à `null`).
/// La confirmation le dit concrètement, avec les comptes : un manager qui
/// supprime un projet portant une facture ne doit pas croire qu'elle
/// disparaît avec lui. Même cérémonie que `_confirmDeleteClient` dans
/// clients_screen.dart et `_confirmerSuppressionType` dans
/// parametres_screen.dart.
void _confirmerSuppressionProjet(BuildContext context, AppState state, Projet projet) {
  final docs = state.documents.values
      .expand((liste) => liste)
      .where((d) => d.projetId == projet.id)
      .length;
  final engs = state.engagementsDuProjet(projet.id).length;

  final String message;
  if (docs == 0 && engs == 0) {
    message = 'Ce projet n\'a aucun document ni engagement rattaché. '
        '« ${projet.nom} » sera supprimé.';
  } else {
    final parts = <String>[
      if (docs > 0) '$docs ${docs > 1 ? 'documents' : 'document'}',
      if (engs > 0) '$engs ${engs > 1 ? 'engagements' : 'engagement'}',
    ];
    final pluriel = (docs + engs) > 1;
    message = '${parts.join(' et ')} ${pluriel ? 'sont rattachés' : 'est rattaché'} '
        'à « ${projet.nom} ». ${pluriel ? 'Ils' : 'Il'} ne '
        '${pluriel ? 'seront' : 'sera'} pas supprimés — seulement détachés de ce projet.';
  }

  showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Supprimer ce projet ?', style: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        TextButton(
          onPressed: () {
            state.deleteProjet(projet.id);
            Navigator.of(dctx).pop(); // ferme la confirmation
            Navigator.of(context).pop(); // ferme aussi la fiche : le projet n'existe plus
          },
          child: Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
        ),
      ],
    ),
  );
}

Widget _ligneMontant(String label, double montant) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
    const Spacer(),
    Text(Fmt.money(montant), style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
  ]),
);

/// Marge du projet — encaissé moins décaissé, tel que calculé par
/// `Avancement.marge`. Jamais recalculée ici : cash-basis, sur les
/// règlements réels uniquement. Rouge dès qu'elle est négative, pour que le
/// manager la repère sans avoir à lire le chiffre.
class _LigneMarge extends StatelessWidget {
  final double marge;
  const _LigneMarge({required this.marge});

  @override
  Widget build(BuildContext context) {
    final negative = marge < 0;
    final couleur = negative ? AppColors.red : AppColors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(children: [
        Text('Marge', style: GoogleFonts.dmSans(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text2)),
        const Spacer(),
        Flexible(child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(Fmt.money(marge),
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: couleur)),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Section « avancement » de la fiche projet — une présentation par mode.
//  Montrer les quatre à la fois laisserait croire au manager qu'il peut
//  saisir des quantités livrées sur un contrat de maintenance ; le mode du
//  type choisi tranche pour lui.
// ─────────────────────────────────────────────────────────
class _SectionSuivi extends StatelessWidget {
  final Projet projet;
  final ModeAvancement mode;
  final AppState state;
  const _SectionSuivi({required this.projet, required this.mode, required this.state});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case ModeAvancement.quantites:
        // La proforma est la source de vérité du livré (§ 5.2 de la
        // conception) : c'est elle qu'on modifie ici, jamais la facture ni
        // le BL, déjà figés à la validation. Le BL imprimé continue
        // d'afficher les quantités commandées (§ 12).
        final proformas = state.proformasDuProjet(projet.id);
        if (proformas.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text('QUANTITÉS LIVRÉES', style: AppTheme.label),
            const SizedBox(height: 8),
            for (final p in proformas)
              for (var i = 0; i < p.lines.length; i++)
                _LigneLivraisonRow(
                  key: ValueKey('${p.id}-$i'),
                  proformaId: p.id, index: i, ligne: p.lines[i],
                ),
          ]),
        );

      case ModeAvancement.jalons:
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            _SectionJalons(projet: projet, state: state),
          ]),
        );

      case ModeAvancement.duree:
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text('AVANCEMENT', style: AppTheme.label),
            const SizedBox(height: 8),
            Text(
              'L\'avancement suit le calendrier : il progresse '
              'automatiquement du début à la fin prévue, sans saisie.',
              style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3),
            ),
          ]),
        );

      case ModeAvancement.manuel:
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            _SectionManuel(projet: projet, state: state),
          ]),
        );
    }
  }
}

// ── Mode jalons : liste éditable, chaque jalon coché fait avancer la
//    pondération portée par son poids (§ 6.1).
class _SectionJalons extends StatelessWidget {
  final Projet projet;
  final AppState state;
  const _SectionJalons({required this.projet, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('JALONS', style: AppTheme.label),
        const Spacer(),
        SecondaryBtn(
          label: 'Ajouter un jalon', icon: Icons.add,
          onTap: () => _ouvrirFormulaireJalon(context, state, projet),
        ),
      ]),
      const SizedBox(height: 8),
      if (projet.jalons.isEmpty)
        Text('Aucun jalon défini.',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))
      else
        for (var i = 0; i < projet.jalons.length; i++)
          _JalonRow(key: ValueKey('jalon-${projet.id}-$i'),
              projet: projet, index: i, jalon: projet.jalons[i], state: state),
    ]);
  }
}

class _JalonRow extends StatelessWidget {
  final Projet projet;
  final int index;
  final Jalon jalon;
  final AppState state;
  const _JalonRow({super.key, required this.projet, required this.index,
      required this.jalon, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Checkbox(
          value: jalon.fait,
          activeColor: AppColors.primary,
          onChanged: (v) => state.marquerJalon(
              projet.id, index, v == true ? DateTime.now() : null),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(jalon.nom, style: GoogleFonts.dmSans(fontSize: 12.5,
              fontWeight: FontWeight.w600, color: AppColors.text1)),
          Text(
            'Prévu le ${Fmt.jour(jalon.prevue)} — poids '
            '${jalon.poids == jalon.poids.roundToDouble() ? jalon.poids.toStringAsFixed(0) : jalon.poids.toString()}',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3),
          ),
        ])),
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.text3),
          onPressed: () => state.supprimerJalon(projet.id, index),
        ),
      ]),
    );
  }
}

void _ouvrirFormulaireJalon(BuildContext context, AppState state, Projet projet) {
  final nomCtrl = TextEditingController();
  final poidsCtrl = TextEditingController(text: '1');
  DateTime prevue = DateTime.now();
  var erreur = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Ajouter un jalon', style: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: dialogWidth(ctx, 360),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOM *', style: AppTheme.label),
            const SizedBox(height: 6),
            TextField(controller: nomCtrl, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
                decoration: _deco(ctx, 'Ex : Étude technique')),
            const SizedBox(height: 12),
            _champDate(ctx, 'DATE PRÉVUE', prevue, (d) => setLocal(() => prevue = d)),
            const SizedBox(height: 12),
            Text('POIDS', style: AppTheme.label),
            const SizedBox(height: 6),
            TextField(controller: poidsCtrl, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
                decoration: _deco(ctx, '1')),
            if (erreur) ...[
              const SizedBox(height: 12),
              Text('Renseignez un nom de jalon.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(
          label: 'Ajouter', icon: Icons.add,
          onTap: () {
            final nom = nomCtrl.text.trim();
            if (nom.isEmpty) { setLocal(() => erreur = true); return; }
            final poids = double.tryParse(poidsCtrl.text) ?? 1;
            state.ajouterJalon(projet.id, Jalon(nom: nom, prevue: prevue, poids: poids));
            Navigator.of(ctx).pop();
          },
        ),
      ],
    )),
  );
}

// ── Mode manuel : un curseur, rien d'autre. Aucun contrôle possible sur la
//    valeur saisie (§ 6.1) — c'est le mode le moins fiable, assumé comme tel.
class _SectionManuel extends StatelessWidget {
  final Projet projet;
  final AppState state;
  const _SectionManuel({required this.projet, required this.state});

  @override
  Widget build(BuildContext context) {
    final valeur = projet.avancementManuel.clamp(0.0, 1.0);
    final pct = (valeur * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('AVANCEMENT', style: AppTheme.label),
        const Spacer(),
        Text('$pct %', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
      ]),
      Slider(
        value: valeur,
        activeColor: AppColors.primary,
        onChanged: (v) => state.setAvancementManuel(projet.id, v),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Une ligne de saisie de quantité livrée, dans la fiche projet.
//  StatefulWidget avec son propre contrôleur : sans lui, chaque frappe
//  ferait perdre le curseur au prochain rebuild (même défaut que les lignes
//  de facturation dans document_create_screen.dart).
// ─────────────────────────────────────────────────────────
class _LigneLivraisonRow extends StatefulWidget {
  final int proformaId;
  final int index;
  final LineItem ligne;
  const _LigneLivraisonRow({
    super.key, required this.proformaId, required this.index, required this.ligne,
  });

  @override
  State<_LigneLivraisonRow> createState() => _LigneLivraisonRowState();
}

class _LigneLivraisonRowState extends State<_LigneLivraisonRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.ligne.qteLivree.toString());
  }

  @override
  void didUpdateWidget(covariant _LigneLivraisonRow old) {
    super.didUpdateWidget(old);
    // Se resynchronise si la quantité a changé ailleurs (ex. une autre
    // fenêtre, ou l'écrêtage appliqué par `setQuantiteLivree`).
    if (old.ligne.qteLivree != widget.ligne.qteLivree) {
      _ctrl.text = widget.ligne.qteLivree.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _valider() {
    final v = int.tryParse(_ctrl.text) ?? 0;
    context.read<AppState>().setQuantiteLivree(widget.proformaId, widget.index, v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(
            widget.ligne.designation.isEmpty ? widget.ligne.ref : widget.ligne.designation,
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text1),
            overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text1),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              filled: true, fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onSubmitted: (_) => _valider(),
            onEditingComplete: _valider,
            onTapOutside: (_) => _valider(),
          ),
        ),
        const SizedBox(width: 6),
        Text('/ ${widget.ligne.qte}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
      ]),
    );
  }
}
