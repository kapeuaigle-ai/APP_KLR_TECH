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

/// Types de projet proposés à la création. En phase 2, `typeId` n'influence
/// encore rien (le mode d'avancement est toujours `quantites`) : la liste
/// deviendra paramétrable en phase 3 (`AppSettings.typesProjet`).
const _typesProjet = [
  ('fourniture', 'Fourniture de matériel'),
  ('installation', 'Installation / déploiement'),
  ('maintenance', 'Maintenance / contrat'),
  ('interne', 'Projet interne'),
];

/// Kanban des projets, en lecture seule.
///
/// La colonne d'une carte se déduit de son avancement physique et financier
/// (`Avancement.calculer(...).statut`) — jamais saisie à la main. Un projet
/// qui stockerait sa colonne pourrait mentir ; un projet calculé ne le peut
/// pas. Conséquence assumée : plus de glisser-déposer.
class ProjetsScreen extends StatelessWidget {
  const ProjetsScreen({super.key});

  /// Une colonne par statut, hors `annule` : un projet annulé disparaît
  /// simplement du tableau plutôt que d'occuper une colonne dédiée.
  static const _colonnes = [
    StatutProjet.aDemarrer,
    StatutProjet.enCours,
    StatutProjet.livreNonPaye,
    StatutProjet.solde,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final projets = state.projets.where((p) => !p.annule).toList();
    final avancements = {
      for (final p in projets) p.id: state.avancementProjet(p.id),
    };

    final parColonne = <StatutProjet, List<Projet>>{
      for (final s in _colonnes) s: <Projet>[],
    };
    for (final p in projets) {
      parColonne[avancements[p.id]!.statut]?.add(p);
    }

    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Projets',
            subtitle: 'Tableau Kanban en lecture seule : la colonne se '
                'déduit de l\'avancement livré / encaissé.',
            actions: [
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
                      'Aucun projet enregistré.',
                      style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3),
                    ),
                  ))
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
    StatutProjet.livreNonPaye: AppColors.orange,
    StatutProjet.solde: AppColors.green,
  };

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurs[statut] ?? AppColors.text3;
    return Container(
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
              Expanded(child: Text(statut.libelle,
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
          if (projets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Aucun projet',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            )
          else
            ...projets.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProjetCard(projet: p, avancement: avancements[p.id]!),
            )),
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
          Text(projet.nom, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(projet.client.isEmpty ? 'Projet interne' : projet.client,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 12),
          _LigneAvancement(label: 'Livré', fraction: avancement.physique, couleur: AppColors.primary),
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
  String typeId = existing?.typeId ?? _typesProjet.first.$1;
  DateTime debut = existing?.debut ?? DateTime.now();
  DateTime finPrevue = existing?.finPrevue ?? DateTime.now().add(const Duration(days: 30));
  var erreur = false;

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
            Wrap(spacing: 8, runSpacing: 8, children: _typesProjet.map((t) => GestureDetector(
              onTap: () => setLocal(() => typeId = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeId == t.$1 ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeId == t.$1 ? AppColors.primary : AppColors.border),
                ),
                child: Text(t.$2, style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: typeId == t.$1 ? AppColors.primary : AppColors.text2)),
              ),
            )).toList()),
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
                const SizedBox(height: 16),
                _LigneAvancement(label: 'Livré', fraction: avancement.physique, couleur: AppColors.primary),
                const SizedBox(height: 12),
                _LigneAvancement(label: 'Encaissé', fraction: avancement.financier, couleur: AppColors.blue),
                const SizedBox(height: 16),
                _ligneMontant('Montant attendu', avancement.montantAttendu),
                _ligneMontant('Encaissé', avancement.montantEncaisse),
                _ligneMontant('Reste dû', avancement.montantRestant),

                // ── Livraison ──────────────────────────────
                // La proforma est la source de vérité du livré (§ 5.2 de la
                // conception) : c'est elle qu'on modifie ici, jamais la
                // facture ni le BL, déjà figés à la validation. Le BL imprimé
                // continue d'afficher les quantités commandées (§ 12).
                if (state.proformasDuProjet(projet.id).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  Text('QUANTITÉS LIVRÉES', style: AppTheme.label),
                  const SizedBox(height: 8),
                  for (final p in state.proformasDuProjet(projet.id))
                    for (var i = 0; i < p.lines.length; i++)
                      _LigneLivraisonRow(
                        key: ValueKey('${p.id}-$i'),
                        proformaId: p.id, index: i, ligne: p.lines[i],
                      ),
                ],
              ]),
            )),
          ]);
        }),
      ),
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
