import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../widgets/responsive.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text('Tableau de Bord', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Aperçu analytique de vos performances financières.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),

            // KPI row (responsive)
            StatGrid(cards: [
              StatCard(label: 'CHIFFRE D\'AFFAIRES', value: '25 000 000', unit: 'FCFA',
                badge: _GreenBadge('+12%')),
              StatCard(label: 'REVENU NET', value: '18 000 000', unit: 'FCFA',
                badge: _GreenBadge('+8.2%')),
              const StatCard(label: 'NOMBRE DE FACTURES', value: '142',
                sub: 'Mise à jour à l\'instant'),
              const StatCard(label: 'DÎME', value: '1 800 000', unit: 'FCFA', red: true),
            ]),
            const SizedBox(height: 20),

            // Charts row (responsive)
            ResponsiveSplit(
              main: _LineChartCard(),
              side: _DonutCard(),
              sideWidth: 320,
              breakpoint: 820,
            ),
            const SizedBox(height: 20),

            // Bottom row (responsive)
            ResponsiveSplit(
              main: _ActivitiesCard(),
              side: _AlertsCard(),
              sideWidth: 320,
              breakpoint: 820,
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenBadge extends StatelessWidget {
  final String text;
  const _GreenBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('↗ $text', style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.green)),
      ]),
    );
  }
}

class _LineChartCard extends StatefulWidget {
  @override
  State<_LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<_LineChartCard> {
  int _year = 2026;

  static const _monthLabels = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  // CA mensuel en millions de FCFA par année
  static const _dataByYear = <int, List<double>>{
    2024: [8.2, 9.1, 10.4, 11.2, 13.5, 14.8, 16.2, 17.1, 18.9, 20.4, 22.1, 23.4],
    2025: [10.3, 11.0, 12.6, 13.1, 14.7, 15.2, 16.8, 18.0, 19.5, 21.2, 22.6, 24.1],
    2026: [12.45, 9.8, 15.6, 11.2, 13.95, 18.0],
  };

  @override
  Widget build(BuildContext context) {
    final values = _dataByYear[_year]!;
    final labels = _monthLabels.take(values.length).toList();
    // Étiquettes d'axe : 6 mois répartis uniformément
    final axisLabels = <String>[];
    final step = (values.length / 6).ceil().clamp(1, 12);
    for (var i = 0; i < values.length; i += step) {
      axisLabels.add(_monthLabels[i].substring(0, 3).toUpperCase());
    }

    return CardBox(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Évolution du CA', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
              Text('Survolez la courbe pour le détail mensuel', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            ])),
            PopupMenuButton<int>(
              tooltip: 'Choisir l\'année',
              offset: const Offset(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              color: Colors.white,
              onSelected: (y) => setState(() => _year = y),
              itemBuilder: (ctx) => _dataByYear.keys.map((y) => PopupMenuItem<int>(
                value: y,
                child: Text('Année $y', style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: y == _year ? FontWeight.w700 : FontWeight.w400,
                  color: y == _year ? AppColors.primary : AppColors.text1,
                )),
              )).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Année $_year', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text1)),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.text2),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: LineAreaChart(
              values: values,
              labels: labels,
              // Données stockées en millions : on les rétablit en entier.
              tooltipFormatter: (v) => Fmt.money(v * 1000000),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: axisLabels.map((m) => Text(m, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.text3))).toList()),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const segments = [
      DonutSegment(pct: 65, color: AppColors.primary, label: 'Payées'),
      DonutSegment(pct: 20, color: Color(0xFF374151), label: 'Impayées'),
      DonutSegment(pct: 15, color: Color(0xFFD1D5DB), label: 'En cours'),
    ];
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition des factures', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const SizedBox(height: 16),
          const Center(child: DonutChart(segments: segments, total: 142)),
          const SizedBox(height: 16),
          ...segments.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(s.label, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF374151)))),
              Text('${s.pct.toInt()}%', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: s.color)),
            ]),
          )),
        ],
      ),
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
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

class _AlertsCard extends StatelessWidget {
  static const _alerts = [
    ('Groupe SAMA', 'J+15', AppColors.red, 'Retard critique sur la facture #4389 (2 450 000 FCFA)'),
    ('AFRI TECH', 'J+3', AppColors.orange, 'Échéance dépassée pour la facture #4412 (800 000 FCFA)'),
  ];

  void _relancer(BuildContext context, String client) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text('Rappel de paiement envoyé à $client.', style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: AppColors.green,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
          ..._alerts.map((al) {
            final (name, badge, color, desc) = al;
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
                  Container(width: 3, color: color),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(desc, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text2, height: 1.4)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _relancer(context, name),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('RELANCER CLIENT', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
