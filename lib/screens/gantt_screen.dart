import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/avancement.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

/// Vue chronologique des projets réels : deux barres par projet — physique
/// (réalisé) et financier (encaissé) — sur un axe calculé depuis leurs vraies
/// dates. Aucune donnée codée en dur : sans projet enregistré, l'écran le dit
/// plutôt que d'afficher une maquette.
class GanttScreen extends StatelessWidget {
  const GanttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final projets = state.projets.where((p) => !p.annule).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));

    if (projets.isEmpty) {
      return Padding(
        padding: pagePadding(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Gantt',
              subtitle: 'Vue chronologique des projets.'),
          const SizedBox(height: 24),
          CardBox(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text(
              'Aucun projet enregistré.',
              style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3),
            )),
          ),
        ]),
      );
    }

    // Axe : du premier début au dernier fin prévue, arrondi au mois.
    final debut = DateTime(projets.first.debut.year, projets.first.debut.month);
    var finMax = projets.first.finPrevue;
    for (final p in projets) {
      if (p.finPrevue.isAfter(finMax)) finMax = p.finPrevue;
    }
    final fin = DateTime(finMax.year, finMax.month + 1, 0);
    final nbMois = (fin.year - debut.year) * 12 + fin.month - debut.month + 1;

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            title: 'Gantt',
            subtitle: 'Vue chronologique des projets. '
                'Barre pleine = réalisé, barre claire = encaissé.',
            actions: [
              if (!isPhone(context))
                SecondaryBtn(label: 'Kanban', icon: Icons.view_kanban_outlined,
                    onTap: () => context.read<AppState>().navigate(NavScreen.projets)),
            ],
          ),
          const SizedBox(height: 24),
          CardBox(
            padding: const EdgeInsets.all(20),
            child: HScrollTable(
              minWidth: 700,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const SizedBox(width: 220),
                  ...List.generate(nbMois, (i) {
                    final m = DateTime(debut.year, debut.month + i);
                    return Expanded(child: Text(
                      _moisCourt(m),
                      style: GoogleFonts.dmSans(fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.text3),
                      textAlign: TextAlign.center));
                  }),
                ]),
                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                ...projets.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _GanttRow(
                    projet: p,
                    avancement: state.avancementProjet(p.id, now: now),
                    mode: state.modeDuProjet(p),
                    axeDebut: debut, nbMois: nbMois),
                )),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  static const _moisAbrev = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

  static String _moisCourt(DateTime d) => '${_moisAbrev[d.month]} ${d.year % 100}';
}

/// Position d'une date sur l'axe, en mois décimaux depuis `axeDebut`.
double _positionMois(DateTime axeDebut, DateTime d) {
  final moisEntiers = (d.year - axeDebut.year) * 12 + (d.month - axeDebut.month);
  final joursDuMois = DateTime(d.year, d.month + 1, 0).day;
  final fraction = (d.day - 1) / joursDuMois;
  return moisEntiers + fraction;
}

/// Une ligne du Gantt : le nom du projet, puis sur l'axe des mois, la plage
/// de dates du projet portant deux barres empilées — le physique (réalisé) en
/// couleur pleine, le financier (encaissé) juste en dessous, en teinte
/// claire. Le nom passe en rouge en cas de retard de livraison, une pastille
/// orange signale un retard de paiement.
class _GanttRow extends StatelessWidget {
  final Projet projet;
  final Avancement avancement;
  final ModeAvancement mode;
  final DateTime axeDebut;
  final int nbMois;
  const _GanttRow({
    required this.projet, required this.avancement, required this.mode,
    required this.axeDebut, required this.nbMois,
  });

  @override
  Widget build(BuildContext context) {
    final pctPhysique = (avancement.physique * 100).round();
    final pctFinancier = (avancement.financier * 100).round();

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 220, child: Row(children: [
        Expanded(child: Text(projet.nom,
            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600,
                color: avancement.enRetardLivraison ? AppColors.red : AppColors.text1),
            overflow: TextOverflow.ellipsis)),
        if (avancement.enRetardPaiement) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Retard de paiement',
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            ),
          ),
        ],
      ])),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final unitW = constraints.maxWidth / nbMois;
        final posDebut = _positionMois(axeDebut, projet.debut);
        final posFin = _positionMois(axeDebut, projet.finPrevue);
        final barLeft = posDebut * unitW;
        final barWidth = max((posFin - posDebut) * unitW, 24.0);

        return SizedBox(height: 40, child: Stack(children: [
          // Grille de fond
          ...List.generate(nbMois, (i) => Positioned(
            left: i * unitW,
            top: 0, bottom: 0, width: 1,
            child: Container(color: AppColors.border),
          )),

          // Barre physique (réalisé) — pleine couleur, en haut.
          Positioned(
            left: barLeft + 2, top: 2,
            width: barWidth, height: 15,
            child: _Barre(
              pct: pctPhysique,
              couleurFond: AppColors.primary.withValues(alpha: 0.15),
              couleurRemplissage: AppColors.primary,
              label: pctPhysique > 0 ? '$pctPhysique %' : '',
            ),
          ),

          // Barre financière (encaissé) — teinte claire, en dessous.
          Positioned(
            left: barLeft + 2, top: 21,
            width: barWidth, height: 15,
            child: _Barre(
              pct: pctFinancier,
              couleurFond: AppColors.blue.withValues(alpha: 0.12),
              couleurRemplissage: AppColors.blue.withValues(alpha: 0.55),
              label: pctFinancier > 0 ? '$pctFinancier %' : '',
            ),
          ),

          // Repères de jalons : losange plein si réalisé, creux sinon. Ne
          // s'affichent que pour le mode jalons — sur les autres modes, un
          // projet n'a d'ailleurs aucun jalon à montrer. La clé permet de les
          // cibler en test sans dépendre du rendu graphique.
          if (mode == ModeAvancement.jalons)
            ...projet.jalons.asMap().entries.map((e) {
              final j = e.value;
              final pos = _positionMois(axeDebut, j.prevue) * unitW;
              return Positioned(
                key: ValueKey('jalon-${projet.id}-${e.key}'),
                left: pos - 5, top: 1, width: 10, height: 10,
                child: Tooltip(
                  message: '${j.nom} — ${j.fait ? 'réalisé' : 'prévu'} '
                      'le ${Fmt.jour(j.realisee ?? j.prevue)}',
                  child: Transform.rotate(
                    angle: 0.785, // 45° : un carré tourné se lit comme un losange
                    child: Container(decoration: BoxDecoration(
                      color: j.fait ? AppColors.primary : Colors.white,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    )),
                  ),
                ),
              );
            }),
        ]));
      })),
    ]);
  }
}

/// Une barre de progression unique : fond clair, remplissage proportionnel,
/// pourcentage centré.
class _Barre extends StatelessWidget {
  final int pct;
  final Color couleurFond;
  final Color couleurRemplissage;
  final String label;
  const _Barre({
    required this.pct, required this.couleurFond,
    required this.couleurRemplissage, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final largeurRemplissage = max(
          constraints.maxWidth * (pct / 100), pct > 0 ? 12.0 : 0.0);
      return Stack(children: [
        Container(
          decoration: BoxDecoration(color: couleurFond, borderRadius: BorderRadius.circular(5)),
        ),
        Container(
          width: largeurRemplissage,
          decoration: BoxDecoration(color: couleurRemplissage, borderRadius: BorderRadius.circular(5)),
        ),
        SizedBox.expand(child: Center(child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)))),
      ]);
    });
  }
}
