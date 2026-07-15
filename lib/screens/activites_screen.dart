import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/data.dart';
import '../widgets/common.dart';

class ActivitesScreen extends StatefulWidget {
  const ActivitesScreen({super.key});

  @override
  State<ActivitesScreen> createState() => _ActivitesScreenState();
}

class _ActivitesScreenState extends State<ActivitesScreen> {
  String _filter = 'tous';

  static const _types = [
    ('tous', 'Tous'),
    ('facture', 'Factures'),
    ('paiement', 'Paiements'),
    ('projet', 'Projets'),
    ('client', 'Clients'),
    ('document', 'Documents'),
    ('equipe', 'Équipe'),
  ];

  static const _typeIcons = {
    'facture': Icons.description_outlined,
    'paiement': Icons.credit_card_outlined,
    'projet': Icons.dashboard_customize_outlined,
    'client': Icons.person_outline_rounded,
    'document': Icons.folder_outlined,
    'equipe': Icons.group_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final activities = SampleData.activities;
    final filtered = _filter == 'tous' ? activities : activities.where((a) => a.type == _filter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activités', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Historique complet des actions effectuées.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),

            // Filter chips
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(spacing: 4, runSpacing: 4, children: _types.map((t) =>
                AppFilterChip(label: t.$2, active: _filter == t.$1, onTap: () => setState(() => _filter = t.$1)),
              ).toList()),
            ),
            const SizedBox(height: 20),

            // Activity feed
            CardBox(
              child: Column(children: filtered.asMap().entries.map((e) {
                final a = e.value;
                final isLast = e.key == filtered.length - 1;
                final icon = _typeIcons[a.type] ?? Icons.circle_outlined;

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Timeline dot + line
                      Column(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: a.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 16, color: a.color),
                        ),
                        if (!isLast) Container(width: 1, height: 20, margin: const EdgeInsets.only(top: 4), color: AppColors.border),
                      ]),
                      const SizedBox(width: 14),

                      // Content
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.titre, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
                        const SizedBox(height: 3),
                        Text(a.desc, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                        const SizedBox(height: 6),
                        Row(children: [
                          AvatarCircle(initials: a.initiales, color: a.color, size: 20, fontSize: 8),
                          const SizedBox(width: 6),
                          Text(a.auteur, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.text2)),
                          const Spacer(),
                          const Icon(Icons.access_time_rounded, size: 12, color: AppColors.text3),
                          const SizedBox(width: 4),
                          Text(a.time, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
                        ]),
                      ])),
                    ]),
                  ),
                ]);
              }).toList()),
            ),

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(children: [
                    const Icon(Icons.history_rounded, size: 40, color: AppColors.text3),
                    const SizedBox(height: 12),
                    Text('Aucune activité pour ce filtre', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
