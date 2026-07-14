import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/data.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';

class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rapports', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Analyses financières, clients et projets.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              SecondaryBtn(label: 'Exporter PDF', icon: Icons.download_outlined, onTap: () {}),
            ]),
            const SizedBox(height: 24),

            AppTabBar(tabs: const ['Financier', 'Clients', 'Projets'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 20),

            if (_tab == 0) const _FinancierTab()
            else if (_tab == 1) const _ClientsTab()
            else const _ProjetsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Financier Tab ─────────────────────────────────────────
class _FinancierTab extends StatelessWidget {
  const _FinancierTab();

  @override
  Widget build(BuildContext context) {
    final dime = SampleData.dimeHistory;
    final totalRevenu = dime.fold<double>(0, (s, d) => s + d.revenu);
    final totalDime = dime.fold<double>(0, (s, d) => s + d.dime);

    return Column(children: [
      Row(children: [
        Expanded(child: StatCard(label: 'CA ANNUEL 2026', value: '81,0', unit: 'M FCFA',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('↗ +12%', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'REVENU TOTAL', value: Fmt.millions(totalRevenu), unit: 'FCFA')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'DÎME TOTALE', value: Fmt.millions(totalDime), unit: 'FCFA', red: true)),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'TAUX RECOUVREMENT', value: '87', unit: '%',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('Bon', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
      ]),
      const SizedBox(height: 20),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: CardBox(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Évolution mensuelle du CA', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            Text('Revenus mensuels 2026 (en millions FCFA)', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: BarLineChart(
              barValues: dime.map((d) => d.revenu / 1000000).toList(),
              lineValues: dime.map((d) => d.dime / 100000).toList(),
              labels: dime.map((d) => d.mois.substring(0, 3)).toList(),
            )),
            const SizedBox(height: 8),
            Row(children: [
              _Legend(color: const Color(0xFF374151), label: 'Revenu'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.primary, label: 'Dîme (×10)'),
            ]),
          ]),
        )),
        const SizedBox(width: 16),
        SizedBox(width: 300, child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Répartition par statut', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const SizedBox(height: 16),
          const Center(child: DonutChart(segments: [
            DonutSegment(pct: 65, color: AppColors.primary, label: 'Payées'),
            DonutSegment(pct: 20, color: Color(0xFF374151), label: 'Impayées'),
            DonutSegment(pct: 15, color: Color(0xFFD1D5DB), label: 'En cours'),
          ], total: 142)),
          const SizedBox(height: 16),
          for (final s in [('Factures payées', '65%', AppColors.primary), ('Impayées', '20%', const Color(0xFF374151)), ('En cours', '15%', Color(0xFFD1D5DB))])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.$1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
                Text(s.$2, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: s.$3)),
              ]),
            ),
        ]))),
      ]),
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
    final clients = SampleData.clients;
    final totalCA = clients.fold<double>(0, (s, c) => s + c.totalFacture);

    return Column(children: [
      Row(children: [
        Expanded(child: StatCard(label: 'TOTAL CLIENTS', value: '${clients.length}', sub: 'Entreprises partenaires')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'CLIENTS ACTIFS', value: '${clients.where((c) => c.status == 'actif').length}')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'CA CUMULÉ', value: Fmt.millions(totalCA), unit: 'FCFA')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'CA MOY./CLIENT', value: Fmt.millions(totalCA / clients.length), unit: 'FCFA')),
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
                final pct = (c.totalFacture / totalCA * 100).round();
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
      Row(children: [
        Expanded(child: StatCard(label: 'TOTAL PROJETS', value: '${_projets.length}')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'EN COURS', value: '$inProgress')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'TERMINÉS', value: '$done',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('${(done / _projets.length * 100).round()}%', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'TAUX COMPLÉTION', value: '${(_projets.fold<int>(0, (s, p) => s + p.$3) / _projets.length).round()}', unit: '%')),
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
