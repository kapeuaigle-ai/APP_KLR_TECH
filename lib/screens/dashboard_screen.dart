import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/avancement.dart';
import '../core/comptabilite.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../widgets/responsive.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Chiffres du mois affiché — EXACTEMENT ceux que montre par défaut
    // l'onglet Comptabilité (Suivi) : lui aussi part de `state.moisCourant`.
    // Même fonction, mêmes bornes : le tableau de bord ne peut donc plus les
    // contredire, contrairement aux quatre valeurs figées qu'il affichait
    // auparavant (défaut critique E1, Lot E).
    final (debutMois, finMois) = Comptabilite.bornesMois(state.moisCourant);
    final rapportMois = Comptabilite.rapport(
        debut: debutMois, fin: finMois, engagements: state.engagements);

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text('Tableau de Bord', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Chiffres du mois en cours : ${Comptabilite.monthLabel(state.moisCourant)}.',
                style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),

            // KPI row (responsive) — mêmes quatre libellés que l'onglet
            // Comptabilité, pour que la valeur affichée ne puisse jamais
            // s'en écarter.
            StatGrid(cards: [
              StatCard(label: 'REVENU ENCAISSÉ', value: Fmt.number(rapportMois.revenu), unit: 'FCFA'),
              StatCard(label: 'DÉPENSES', value: Fmt.number(rapportMois.depenses), unit: 'FCFA'),
              StatCard(label: 'BÉNÉFICE', value: Fmt.number(rapportMois.benefice), unit: 'FCFA',
                  red: rapportMois.benefice < 0),
              StatCard(label: 'DÎME (10%)', value: Fmt.number(rapportMois.dime), unit: 'FCFA', red: true),
            ]),
            const SizedBox(height: 20),

            // Charts row (responsive)
            const ResponsiveSplit(
              main: _LineChartCard(),
              side: _DonutCard(),
              sideWidth: 320,
              breakpoint: 820,
            ),
            const SizedBox(height: 20),

            // Bottom row (responsive)
            const ResponsiveSplit(
              main: _ActivitiesCard(),
              side: _AlertsCard(),
              sideWidth: 320,
              breakpoint: 820,
            ),
            const SizedBox(height: 20),

            // Trésorerie prévisionnelle : ce qui doit rentrer, et quand.
            // Impossible avant la Phase 1 — voir Avancement.tresoreriePrevisionnelle.
            const _TresorerieCard(),
          ],
        ),
      ),
    );
  }
}

// ── Évolution du revenu encaissé ──────────────────────────
/// Les 6 derniers mois (mois courant inclus), à zéro là où rien n'a encore
/// bougé plutôt qu'absents : un tableau de bord qui saute des mois se lirait
/// comme une panne plutôt que comme une réelle absence d'activité. Aucune
/// donnée n'est inventée — c'est le même calcul que `_ComptaTab`, rejoué mois
/// par mois.
class _LineChartCard extends StatelessWidget {
  const _LineChartCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = Comptabilite.bilanMensuel(state.engagements, const {}, const {});

    final now = DateTime.now();
    final labels = <String>[];
    final values = <double>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      final key = Comptabilite.monthKeyFromDate(d);
      final row = Comptabilite.ligneMois(key, rows);
      labels.add(Comptabilite.monthLabel(key).split(' ').first.substring(0, 3).toUpperCase());
      values.add(row?.revenu ?? 0);
    }

    return CardBox(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution du revenu encaissé', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          Text('Encaissements des 6 derniers mois', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: Center(child: Text('Aucun encaissement enregistré pour l\'instant',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))),
            )
          else ...[
            SizedBox(
              height: 160,
              child: LineAreaChart(
                values: values,
                labels: labels,
                tooltipFormatter: Fmt.money,
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels.map((m) => Text(m, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.text3))).toList()),
          ],
        ],
      ),
    );
  }
}

// ── Dépenses par catégorie (mois en cours) ────────────────
/// Même source que l'onglet Rapports (`Comptabilite.rapport`), restreinte au
/// mois en cours plutôt qu'à une période choisie : le tableau de bord n'a pas
/// de sélecteur de période, il montre l'instant présent.
class _DonutCard extends StatelessWidget {
  const _DonutCard();

  static const _palette = [
    AppColors.primary, AppColors.slate, AppColors.orange,
    AppColors.blue, AppColors.teal, Color(0xFFD1D5DB),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final (debutMois, finMois) = Comptabilite.bornesMois(state.moisCourant);
    final rapportMois = Comptabilite.rapport(
        debut: debutMois, fin: finMois, engagements: state.engagements);
    final categories = rapportMois.depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dépenses par catégorie', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          Text('Mois en cours', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Aucune dépense ce mois-ci',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))),
            )
          else ...[
            Center(child: DonutChart(
              segments: [
                for (final (i, c) in categories.take(6).indexed)
                  DonutSegment(
                    pct: rapportMois.depenses > 0 ? c.value / rapportMois.depenses * 100 : 0,
                    color: _palette[i % _palette.length],
                    label: c.key,
                  ),
              ],
              total: categories.length,
            )),
            const SizedBox(height: 16),
            for (final (i, c) in categories.take(6).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                      color: _palette[i % _palette.length], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.key, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
                  Text(Fmt.money(c.value), style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard();

  // Icône par type d'activité (aligné sur l'écran Activités).
  static const _icons = {
    'comptabilite': Icons.account_balance_wallet_outlined,
    'facture': Icons.description_outlined,
    'paiement': Icons.credit_card_outlined,
    'client': Icons.person_outline_rounded,
    'document': Icons.folder_outlined,
  };

  @override
  Widget build(BuildContext context) {
    // Les 5 dernières entrées du vrai fil d'activité.
    final activities = context.watch<AppState>().activities.take(5).toList();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Dernières activités', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1))),
            InkWell(
              onTap: () => context.read<AppState>().navigate(NavScreen.activites),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text('Tout voir', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Aucune activité pour le moment',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
            )
          else
            ...activities.asMap().entries.map((e) {
              final a = e.value;
              final icon = _icons[a.type] ?? Icons.circle_outlined;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: e.key < activities.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: a.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 16, color: a.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.titre, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
                    if (a.desc.isNotEmpty)
                      Text(a.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
                  ])),
                  Text(a.time, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

// ── Trésorerie prévisionnelle ────────────────────────────
/// Ce qui doit rentrer, et quand : le reste dû de chaque engagement entrant
/// non soldé. Impossible avant la Phase 1 — `facture.encaissee` était un
/// booléen sans échéance, et une créance saisie à la main n'était liée à
/// rien. `Engagement` porte les deux depuis l'unification.
class _TresorerieCard extends StatelessWidget {
  const _TresorerieCard();

  @override
  Widget build(BuildContext context) {
    final engagements = context.watch<AppState>().engagements;
    final echeances = Avancement.tresoreriePrevisionnelle(
        engagements, now: DateTime.now());
    final total = echeances.fold(0.0, (s, e) => s + e.montant);
    final aAfficher = echeances.take(5).toList();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('À encaisser', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          ]),
          const SizedBox(height: 16),
          if (aAfficher.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Rien à encaisser pour le moment',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
            )
          else ...[
            for (var i = 0; i < aAfficher.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < aAfficher.length - 1
                      ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
                      : null,
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(aAfficher[i].tiers, style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                    Text(
                      aAfficher[i].enRetard
                          ? 'Échéance dépassée le ${Fmt.jour(aAfficher[i].echeance)}'
                          : 'Échéance le ${Fmt.jour(aAfficher[i].echeance)}',
                      style: GoogleFonts.dmSans(fontSize: 12,
                          color: aAfficher[i].enRetard ? AppColors.red : AppColors.text3),
                    ),
                  ])),
                  Text(Fmt.money(aAfficher[i].montant), style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: aAfficher[i].enRetard ? AppColors.red : AppColors.text1)),
                ]),
              ),
            const Divider(height: 24, color: AppColors.border),
            Row(children: [
              Text('Total attendu', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text2)),
              const Spacer(),
              Flexible(child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(Fmt.money(total), style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
              )),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Alertes de paiement ───────────────────────────────────
/// Dérivées de `Avancement.alertesPaiement` — les échéances entrantes déjà
/// dépassées — jamais de noms de clients ni de montants inventés (défaut
/// critique E2, Lot E). Le bouton n'affirme plus avoir envoyé un rappel qu'il
/// n'a pas envoyé : il ouvre l'onglet Engagements de Suivi, où la relance se
/// fait réellement.
class _AlertsCard extends StatelessWidget {
  const _AlertsCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final alertes = Avancement.alertesPaiement(state.engagements, now: now).take(3).toList();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.orange),
            const SizedBox(width: 8),
            Text('Alertes de paiement', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          ]),
          const SizedBox(height: 16),
          if (alertes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Aucune échéance en retard',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
            )
          else
            ...alertes.map((al) {
              final jours = al.joursRetard(now);
              final couleur = jours >= 7 ? AppColors.red : AppColors.orange;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: couleur),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(al.tiers, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: couleur.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('J+$jours', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: couleur)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          al.documentNumero != null
                              ? 'Échéance dépassée pour ${al.documentNumero} (${Fmt.money(al.montant)})'
                              : 'Échéance dépassée (${Fmt.money(al.montant)})',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text2, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => context.read<AppState>().navigate(NavScreen.suivi),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('VOIR DANS SUIVI', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                            ]),
                          ),
                        ),
                      ]),
                    )),
                  ],
                )),
              );
            }),
          const SizedBox(height: 4),
          Center(child: InkWell(
            onTap: () => context.read<AppState>().navigate(NavScreen.suivi),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Voir toutes les alertes', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          )),
        ],
      ),
    );
  }
}
