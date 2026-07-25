import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import 'klr_logo.dart';

// ─────────────────────────────────────────────────────────
//  Navigation téléphone
//
//  La sidebar de bureau est remplacée par une barre du bas (les quatre
//  écrans du quotidien) et une feuille « Plus » (le reste). L'état de
//  navigation reste celui d'AppState : seul le rendu change.
//
//  L'écran Projets (Kanban) n'apparaît pas : quatre colonnes en
//  glisser-déposer ne se transposent pas au doigt. Gantt, qui n'était
//  atteignable que depuis Projets, passe donc dans « Plus ».
// ─────────────────────────────────────────────────────────

/// Les quatre destinations de la barre du bas, dans l'ordre.
const _bottomItems = <(NavScreen, String, IconData)>[
  (NavScreen.dashboard, 'Bord',    Icons.grid_view_rounded),
  (NavScreen.documents, 'Docs',    Icons.description_outlined),
  (NavScreen.clients,   'Clients', Icons.person_outline_rounded),
  (NavScreen.suivi,     'Suivi',   Icons.check_box_outlined),
];

/// Les destinations reléguées dans la feuille « Plus ».
const _moreItems = <(NavScreen, String, IconData)>[
  (NavScreen.gantt,      'Gantt',      Icons.bar_chart_rounded),
  (NavScreen.activites,  'Activités',  Icons.show_chart_rounded),
  (NavScreen.rapports,   'Rapports',   Icons.insert_chart_outlined_rounded),
  (NavScreen.parametres, 'Paramètres', Icons.settings_outlined),
];

/// Écrans inaccessibles sur téléphone. Si l'état pointe dessus quand la
/// fenêtre rétrécit, la coquille redirige plutôt que d'afficher un écran
/// dont on ne peut plus sortir par la navigation.
bool isPhoneUnreachable(NavScreen screen) => screen == NavScreen.projets;

/// Coquille téléphone : barre haute compacte, contenu, barre du bas.
class MobileShell extends StatelessWidget {
  final Widget child;
  const MobileShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Index de l'onglet actif, ou null si l'écran courant vit dans « Plus ».
    final current = _bottomItems.indexWhere((i) => i.$1 == state.screen);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const _MobileAppBar(),
      body: child,
      bottomNavigationBar: _BottomBar(
        currentIndex: current,
        onSelect: (i) => state.navigate(_bottomItems[i].$1),
        onMore: () => _showMoreSheet(context, state),
      ),
    );
  }
}

// ── Barre haute ───────────────────────────────────────────
class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleSpacing: 16,
      title: Row(children: [
        const KlrLogo(height: 26, markOnly: true),
        const SizedBox(width: 10),
        Text('KLR TECH', style: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1,
          letterSpacing: 0.3,
        )),
      ]),
      actions: [
        IconButton(
          tooltip: 'Rechercher',
          icon: const Icon(Icons.search, size: 21, color: AppColors.text2),
          onPressed: () => _showSearchSheet(context),
        ),
        _NotificationsAction(),
        IconButton(
          tooltip: 'Se déconnecter',
          icon: const Icon(Icons.logout_rounded, size: 19, color: AppColors.text2),
          onPressed: () => context.read<AppState>().logout(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Cloche de notifications : mêmes alertes que l'en-tête de bureau, mais
/// dans une feuille basse plutôt qu'un menu contextuel (plus lisible et
/// plus facile à viser au pouce).
class _NotificationsAction extends StatelessWidget {
  static const _alerts = [
    ('Groupe SAMA', 'Retard critique — facture #4389 (J+15)', Icons.error_outline_rounded, AppColors.red),
    ('AFRI TECH', 'Échéance dépassée — facture #4412 (J+3)', Icons.warning_amber_rounded, AppColors.orange),
    ('Dîme Juin 2026', 'Versement en attente (1 800 000 FCFA)', Icons.volunteer_activism_outlined, AppColors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_outlined, size: 21, color: AppColors.text2),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const _SheetGrip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  Text('Notifications', style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              ..._alerts.map((a) => ListTile(
                leading: Icon(a.$3, size: 20, color: a.$4),
                title: Text(a.$1, style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
                subtitle: Text(a.$2, style: GoogleFonts.dmSans(
                  fontSize: 12.5, color: AppColors.text3)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.read<AppState>().navigate(NavScreen.suivi);
                },
              )),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
      Positioned(
        right: 10, top: 10,
        child: IgnorePointer(
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Recherche ─────────────────────────────────────────────
/// La recherche de l'en-tête de bureau n'a pas la place de rester visible :
/// elle devient une feuille dédiée. Comme sur bureau, le champ n'est pas
/// encore relié à une recherche globale — chaque écran a la sienne.
void _showSearchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      // Remonte la feuille au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SheetGrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: TextField(
              autofocus: true,
              style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.text1),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: GoogleFonts.dmSans(fontSize: 15, color: AppColors.text3),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.text3),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ── Feuille « Plus » ──────────────────────────────────────
void _showMoreSheet(BuildContext context, AppState state) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const _SheetGrip(),
        ..._moreItems.map((item) {
          final (screen, label, icon) = item;
          final active = state.screen == screen;
          return ListTile(
            leading: Icon(icon, size: 21,
                color: active ? AppColors.primary : AppColors.text2),
            title: Text(label, style: GoogleFonts.dmSans(
              fontSize: 14.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.primary : AppColors.text1,
            )),
            trailing: active
                ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                : null,
            onTap: () {
              Navigator.of(ctx).pop();
              state.navigate(screen);
            },
          );
        }),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// Petite poignée grise en haut des feuilles basses : indique qu'on peut
/// les faire glisser pour les refermer.
class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Barre du bas ──────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  /// Index de l'onglet actif, ou -1 quand l'écran courant vit dans « Plus »
  /// (auquel cas c'est « Plus » qui est mis en avant).
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onMore;

  const _BottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final onMoreScreen = currentIndex < 0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            for (var i = 0; i < _bottomItems.length; i++)
              Expanded(child: _BarButton(
                label: _bottomItems[i].$2,
                icon: _bottomItems[i].$3,
                active: i == currentIndex,
                onTap: () => onSelect(i),
              )),
            Expanded(child: _BarButton(
              label: 'Plus',
              icon: Icons.more_horiz_rounded,
              active: onMoreScreen,
              onTap: onMore,
            )),
          ]),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _BarButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.text3;
    return InkWell(
      onTap: onTap,
      // Toute la hauteur de 58 px est cliquable : bien au-delà des 48 px
      // recommandés pour une cible tactile.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          )),
        ],
      ),
    );
  }
}
