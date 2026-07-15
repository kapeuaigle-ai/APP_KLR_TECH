import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Flexible(child: _SearchBar()),
          const Spacer(),
          const _NotificationsBtn(),
          const SizedBox(width: 4),
          const _HelpBtn(),
          const SizedBox(width: 12),
          _UserChip(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: AppColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notifications : alertes de paiement ───────────────────
class _NotificationsBtn extends StatelessWidget {
  const _NotificationsBtn();

  static const _alerts = [
    ('Groupe SAMA', 'Retard critique — facture #4389 (J+15)', Icons.error_outline_rounded, AppColors.red),
    ('AFRI TECH', 'Échéance dépassée — facture #4412 (J+3)', Icons.warning_amber_rounded, AppColors.orange),
    ('Dîme Juin 2026', 'Versement en attente (1 800 000 FCFA)', Icons.volunteer_activism_outlined, AppColors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PopupMenuButton<int>(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.text2),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 320),
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: Colors.white,
          onSelected: (_) => context.read<AppState>().navigate(NavScreen.suivi),
          itemBuilder: (ctx) => [
            PopupMenuItem<int>(
              enabled: false,
              child: Text('Notifications', style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text1)),
            ),
            ..._alerts.asMap().entries.map((e) => PopupMenuItem<int>(
              value: e.key,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(e.value.$3, size: 16, color: e.value.$4),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.value.$1, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  Text(e.value.$2, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
                ])),
              ]),
            )),
          ],
        ),
        Positioned(
          right: 8, top: 8,
          child: IgnorePointer(
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Aide : à propos de l'application ──────────────────────
class _HelpBtn extends StatelessWidget {
  const _HelpBtn();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Aide',
      icon: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.text2),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('KLR TECH – Gestion', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Application de gestion d\'entreprise — version 1.0.0',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
              const SizedBox(height: 14),
              for (final item in const [
                ('Dashboard', 'Vue d\'ensemble des performances financières'),
                ('Documents', 'Proformas, factures et bons de livraison (PDF)'),
                ('Clients', 'Portefeuille clients et historique'),
                ('Projets / Gantt', 'Suivi Kanban et chronologique des projets'),
                ('Équipes', 'Collaborateurs et départements'),
                ('Suivi', 'Factures, dîme, tâches et notes'),
                ('Rapports', 'Analyses et export PDF'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: RichText(text: TextSpan(children: [
                      TextSpan(text: '${item.$1} — ', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                      TextSpan(text: item.$2, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2)),
                    ]))),
                  ]),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('KL', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text('KLR TECH', style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
        ],
      ),
    );
  }
}
