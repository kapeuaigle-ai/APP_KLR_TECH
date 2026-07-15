import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';

class Sidebar extends StatelessWidget {
  /// Mode compact (icônes seules) pour les écrans étroits.
  final bool compact;
  const Sidebar({super.key, this.compact = false});

  static const _navItems = [
    (NavScreen.dashboard, 'Dashboard', Icons.grid_view_rounded),
    (NavScreen.documents, 'Documents', Icons.description_outlined),
    (NavScreen.clients, 'Clients', Icons.person_outline_rounded),
    (NavScreen.projets, 'Projets', Icons.dashboard_customize_outlined),
    (NavScreen.equipes, 'Équipes', Icons.group_outlined),
    (NavScreen.suivi, 'Suivi', Icons.check_box_outlined),
    (NavScreen.activites, 'Activités', Icons.show_chart_rounded),
    (NavScreen.rapports, 'Rapports', Icons.bar_chart_rounded),
    (NavScreen.parametres, 'Paramètres', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      width: compact ? 64 : 210,
      color: AppColors.sidebar,
      child: Column(
        children: [
          _Logo(compact: compact),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: _navItems.map((item) {
                final (screen, label, icon) = item;
                // Gantt est accessible depuis Projets : le met en surbrillance aussi
                final active = (state.screen == screen ||
                        (screen == NavScreen.projets && state.screen == NavScreen.gantt)) &&
                    !state.creating;
                return _NavItem(
                  screen: screen, label: label, icon: icon, active: active,
                  compact: compact,
                  onTap: () => state.navigate(screen),
                );
              }).toList(),
            ),
          ),
          _UserProfile(compact: compact),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool compact;
  const _Logo({this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: CustomPaint(size: const Size(30, 30), painter: _DiamondPainter()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Row(
        children: [
          CustomPaint(size: const Size(32, 32), painter: _DiamondPainter()),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KLR TECH', style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.4,
              )),
              Text('Gestion', style: GoogleFonts.dmSans(
                color: AppColors.text2, fontSize: 10, letterSpacing: 1.2,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    final path = Path()
      ..moveTo(size.width / 2, 2)
      ..lineTo(size.width - 2, size.height / 2)
      ..lineTo(size.width / 2, size.height - 2)
      ..lineTo(2, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);
    final inner = Paint()..color = Colors.white.withOpacity(0.25);
    final innerPath = Path()
      ..moveTo(size.width / 2, size.height * 0.28)
      ..lineTo(size.width * 0.72, size.height / 2)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(size.width * 0.28, size.height / 2)
      ..close();
    canvas.drawPath(innerPath, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatefulWidget {
  final NavScreen screen;
  final String label;
  final IconData icon;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({
    required this.screen, required this.label, required this.icon,
    required this.active, required this.onTap, this.compact = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 4 : 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.active
                ? AppColors.primary.withOpacity(0.12)
                : _hovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // Barre d'accent (marqueur d'onglet actif)
              if (!widget.compact) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3, height: 16,
                  decoration: BoxDecoration(
                    color: widget.active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Icon(widget.icon, size: 16, color: widget.active ? Colors.white : const Color(0xFF8B92A5)),
              if (!widget.compact) ...[
                const SizedBox(width: 10),
                Text(widget.label, style: GoogleFonts.dmSans(
                  color: widget.active ? Colors.white : const Color(0xFF8B92A5),
                  fontSize: 13.5,
                  fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                )),
              ],
            ],
          ),
        ),
      ),
    );
    if (widget.compact) {
      return Tooltip(message: widget.label, child: item);
    }
    return item;
  }
}

class _UserProfile extends StatelessWidget {
  final bool compact;
  const _UserProfile({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 34, height: 34,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('KL', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
        ),
        child: Tooltip(message: 'Kapeu Aigle — Directeur Tech', child: avatar),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kapeu Aigle', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text('Directeur Tech', style: GoogleFonts.dmSans(color: AppColors.text2, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
