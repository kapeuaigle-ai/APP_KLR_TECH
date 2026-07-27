import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../core/comptabilite.dart';
import '../core/utils.dart';
import '../core/pdf_generator.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../widgets/periode_selector.dart';
import '../widgets/responsive.dart';

class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  int _tab = 0;
  bool _exporting = false;
  Periode _periode = Periode.ceMois();

  /// Rapport recalculé à chaque build : l'écran et le PDF téléchargé montrent
  /// donc toujours exactement les mêmes chiffres.
  RapportPeriode _rapport(AppState state) => Comptabilite.rapport(
        debut: _periode.debut,
        fin: _periode.fin,
        factures: state.documents['facture'] ?? [],
        expenses: state.expenses,
        engagements: state.engagements,
      );

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final state = context.read<AppState>();
    try {
      final bytes = await PdfGenerator.generateRapport(
        settings: state.settings,
        rapport: _rapport(state),
      );
      final path = await PdfGenerator.saveRapport(bytes);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rapport PDF enregistré :\n$path', style: const TextStyle(fontSize: 13)),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'export : $e', style: const TextStyle(fontSize: 13)),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Rapports',
              subtitle: 'Analyses financières, clients et projets.',
              actions: [
                PrimaryBtn(
                  label: _exporting ? 'Export en cours...' : 'Télécharger le rapport',
                  icon: Icons.download_outlined,
                  onTap: _exporting ? null : _exportPdf,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Le sélecteur pilote à la fois l'affichage et le PDF téléchargé.
            PeriodeSelector(
              selection: _periode,
              onChanged: (p) => setState(() => _periode = p),
            ),
            const SizedBox(height: 20),

            AppTabBar(tabs: const ['Financier', 'Clients', 'Projets'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 20),

            if (_tab == 0) _FinancierTab(rapport: _rapport(context.watch<AppState>()))
            else if (_tab == 1) const _ClientsTab()
            else const _ProjetsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Financier Tab ─────────────────────────────────────────
/// Tout est calculé sur la période choisie, à partir des données réelles de
/// l'application : ce que l'écran affiche est exactement ce que contient le
/// PDF téléchargé.
class _FinancierTab extends StatelessWidget {
  final RapportPeriode rapport;
  const _FinancierTab({required this.rapport});

  static const _palette = [
    AppColors.primary, Color(0xFF374151), AppColors.orange,
    AppColors.blue, AppColors.teal, Color(0xFFD1D5DB),
  ];

  @override
  Widget build(BuildContext context) {
    final categories = rapport.depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'ENCAISSEMENTS', value: Fmt.number(rapport.revenu), unit: 'FCFA'),
        StatCard(label: 'DÉCAISSEMENTS', value: Fmt.number(rapport.depenses), unit: 'FCFA'),
        StatCard(
          label: 'BÉNÉFICE', value: Fmt.number(rapport.benefice), unit: 'FCFA',
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rapport.benefice >= 0 ? AppColors.greenBg : AppColors.redBg,
              borderRadius: BorderRadius.circular(20)),
            child: Text(rapport.benefice >= 0 ? 'Positif' : 'Négatif',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                    color: rapport.benefice >= 0 ? AppColors.green : AppColors.red)),
          ),
        ),
        StatCard(label: 'DÎME (10%)', value: Fmt.number(rapport.dime), unit: 'FCFA', red: true),
      ]),
      const SizedBox(height: 20),

      if (rapport.estVide)
        CardBox(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            const Icon(Icons.insights_outlined, size: 40, color: AppColors.text3),
            const SizedBox(height: 12),
            Text('Aucun mouvement sur cette période',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text2)),
            const SizedBox(height: 4),
            Text('Choisis une autre période, ou enregistre des encaissements et des dépenses.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          ]),
        ))
      else ...[
        ResponsiveSplit(
          sideWidth: 300,
          breakpoint: 820,
          main: CardBox(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Évolution mensuelle', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
              Text('Encaissements et bénéfice, en milliers de FCFA',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
              const SizedBox(height: 16),
              if (rapport.mois.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('Pas assez de données pour un graphique',
                      style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))),
                )
              else ...[
                SizedBox(height: 180, child: BarLineChart(
                  barValues: rapport.mois.map((m) => m.revenuHt / 1000).toList(),
                  lineValues: rapport.mois.map((m) => m.benefice / 1000).toList(),
                  labels: rapport.mois.map((m) => m.label.split(' ').first.substring(0, 3)).toList(),
                )),
                const SizedBox(height: 8),
                Row(children: [
                  _Legend(color: const Color(0xFF374151), label: 'Encaissé'),
                  const SizedBox(width: 16),
                  _Legend(color: AppColors.primary, label: 'Bénéfice'),
                ]),
              ],
            ]),
          ),
          side: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dépenses par catégorie', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucune dépense sur la période',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3))),
              )
            else ...[
              Center(child: DonutChart(
                segments: [
                  for (final (i, c) in categories.take(6).indexed)
                    DonutSegment(
                      pct: rapport.depenses > 0 ? c.value / rapport.depenses * 100 : 0,
                      color: _palette[i % _palette.length],
                      label: c.key,
                    ),
                ],
                total: categories.length,
              )),
              const SizedBox(height: 16),
              for (final (i, c) in categories.take(6).indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(
                        color: _palette[i % _palette.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.key, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
                    Text(Fmt.money(c.value), style: GoogleFonts.dmSans(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  ]),
                ),
            ],
          ])),
        ),
        const SizedBox(height: 20),

        // Détail des mouvements : la matière du rapport téléchargé.
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Mouvements de la période',
                style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1))),
            Text('${rapport.mouvements.length}',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text3)),
          ]),
          const SizedBox(height: 4),
          Text('Créances en cours (restant dû) : ${Fmt.money(rapport.creancesEnCours)}',
              style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          const SizedBox(height: 12),
          for (final m in rapport.mouvements.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(m.entree ? Icons.south_west_rounded : Icons.north_east_rounded,
                    size: 15, color: m.entree ? AppColors.green : AppColors.red),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.libelle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                  Text('${Fmt.jour(m.date)} · ${m.detail}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
                ])),
                const SizedBox(width: 8),
                Text('${m.entree ? '+' : '−'} ${Fmt.money(m.montant)}',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                        color: m.entree ? AppColors.green : AppColors.red)),
              ]),
            ),
          if (rapport.mouvements.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('… et ${rapport.mouvements.length - 20} autres — tous figurent dans le PDF.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            ),
        ])),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text2)),
    ]);
  }
}

// ── Clients Tab ───────────────────────────────────────────
class _ClientsTab extends StatelessWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<AppState>().clients;
    final totalCA = clients.fold<double>(0, (s, c) => s + c.totalFacture);

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'TOTAL CLIENTS', value: '${clients.length}', sub: 'Entreprises partenaires'),
        StatCard(label: 'CA CUMULÉ', value: Fmt.number(totalCA), unit: 'FCFA'),
        StatCard(label: 'CA MOY./CLIENT', value: Fmt.number(clients.isEmpty ? 0 : totalCA / clients.length), unit: 'FCFA'),
      ]),
      const SizedBox(height: 20),

      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top clients par CA', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        ...() {
              final sorted = clients.where((c) => c.totalFacture > 0).toList()
                ..sort((a, b) => b.totalFacture.compareTo(a.totalFacture));
              final top = sorted.take(5).toList();
              return top.map((c) {
                final pct = totalCA > 0 ? (c.totalFacture / totalCA * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      AvatarCircle(initials: c.initials, color: c.color, size: 28, fontSize: 10),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1), overflow: TextOverflow.ellipsis)),
                      Text(Fmt.money(c.totalFacture), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
                      const SizedBox(width: 8),
                      SizedBox(width: 40, child: Text('$pct%', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3), textAlign: TextAlign.right)),
                    ]),
                    const SizedBox(height: 6),
                    ProgressBar(value: pct, color: c.color, height: 6),
                  ]),
                );
              }).toList();
            }(),
      ])),
    ]);
  }
}

// ── Projets Tab ───────────────────────────────────────────
class _ProjetsTab extends StatelessWidget {
  const _ProjetsTab();

  static final _projets = [
    ('Dashboard Analytics v2', AppColors.primary, 100, 'Terminé', 'AB, AK, MD'),
    ('API OAuth2 Connecteurs', AppColors.blue, 67, 'En cours', 'AB, KL'),
    ('Charte graphique 2026', AppColors.orange, 100, 'Terminé', 'AK'),
    ('Migration cloud AWS', AppColors.teal, 25, 'En cours', 'JT'),
    ('Module CRM clients', AppColors.purple, 0, 'À faire', 'AB, JT'),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _projets.where((p) => p.$4 == 'Terminé').length;
    final inProgress = _projets.where((p) => p.$4 == 'En cours').length;

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'TOTAL PROJETS', value: '${_projets.length}'),
        StatCard(label: 'EN COURS', value: '$inProgress'),
        StatCard(label: 'TERMINÉS', value: '$done',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('${(done / _projets.length * 100).round()}%', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)))),
        StatCard(label: 'TAUX COMPLÉTION', value: '${(_projets.fold<int>(0, (s, p) => s + p.$3) / _projets.length).round()}', unit: '%'),
      ]),
      const SizedBox(height: 20),

      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Avancement des projets', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        ..._projets.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$2, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(p.$1, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1))),
              StatusBadge(status: p.$4 == 'Terminé' ? 'termine' : p.$4 == 'En cours' ? 'cours' : 'attente'),
              const SizedBox(width: 12),
              Text('${p.$3}%', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: p.$2)),
            ]),
            const SizedBox(height: 6),
            ProgressBar(value: p.$3, color: p.$2, height: 8),
            const SizedBox(height: 3),
            Text('Équipe : ${p.$5}', style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
          ]),
        )),
      ])),
    ]);
  }
}
