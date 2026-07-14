import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';

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

            // KPI row
            Row(children: [
              Expanded(child: StatCard(label: 'CHIFFRE D\'AFFAIRES', value: '25 000 000', unit: 'FCFA',
                badge: _GreenBadge('+12%'))),
              const SizedBox(width: 16),
              Expanded(child: StatCard(label: 'REVENU NET', value: '18 000 000', unit: 'FCFA',
                badge: _GreenBadge('+8.2%'))),
              const SizedBox(width: 16),
              Expanded(child: StatCard(label: 'NOMBRE DE FACTURES', value: '142',
                sub: 'Mise à jour à l\'instant')),
              const SizedBox(width: 16),
              Expanded(child: StatCard(label: 'DÎME', value: '1 800 000', unit: 'FCFA', red: true)),
            ]),
            const SizedBox(height: 20),

            // Charts row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _LineChartCard()),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _DonutCard()),
            ]),
            const SizedBox(height: 20),

            // Bottom row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _ActivitiesCard()),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _AlertsCard()),
            ]),
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

class _LineChartCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['JAN', 'MAR', 'MAI', 'JUIL', 'SEPT', 'NOV'];
    return CardBox(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Évolution du CA', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
              Text('Performance annuelle comparée', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Text('Année 2024', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text1)),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.text2),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: LineAreaChart(values: const [8.2, 9.1, 10.4, 11.2, 13.5, 14.8, 16.2, 17.1, 18.9, 20.4, 22.1]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((m) => Text(m, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.text3))).toList()),
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
  static const _activities = [
    (Icons.description_outlined, 'Facture #4420 générée', 'Client: Global Logistics Ltd', 'Il y a 2h'),
    (Icons.credit_card_outlined, 'Paiement reçu – 1 200 000 FCFA', 'Via Virement Bancaire', 'Il y a 5h'),
    (Icons.person_outline_rounded, 'Nouveau client ajouté', 'Société Sahel Innov', 'Hier, 16:45'),
    (Icons.email_outlined, 'Rappel envoyé (Délai dépassé)', 'Facture #4402 · Tech Corp', 'Hier, 10:20'),
  ];

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dernières activités', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const SizedBox(height: 16),
          ..._activities.asMap().entries.map((e) {
            final (icon, title, sub, time) = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: e.key < _activities.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))) : null,
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 16, color: AppColors.text3),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
                  Text(sub, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
                ])),
                Text(time, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFB),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  top: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                  left: BorderSide(color: color, width: 3),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(badge, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(desc, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text2, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('RELANCER CLIENT', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Center(child: Text('Voir toutes les alertes', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
        ],
      ),
    );
  }
}
