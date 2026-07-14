import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

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
      width: 210,
      color: AppColors.sidebar,
      child: Column(
        children: [
          _Logo(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              children: _navItems.where((item) {
                // Hide "Équipes" in mono-user mode
                if (state.isMonoUser && item.$1 == NavScreen.equipes) return false;
                return true;
              }).map((item) {
                final (screen, label, icon) = item;
                final active = state.screen == screen && !state.creating;
                return _NavItem(
                  screen: screen, label: label, icon: icon, active: active,
                  onTap: () => state.navigate(screen),
                );
              }).toList(),
            ),
          ),
          _UserProfile(),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
  final VoidCallback onTap;

  const _NavItem({required this.screen, required this.label, required this.icon, required this.active, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.active
                ? AppColors.primary.withOpacity(0.12)
                : _hovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.active ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.active ? Colors.white : const Color(0xFF8B92A5)),
              const SizedBox(width: 10),
              Text(widget.label, style: GoogleFonts.dmSans(
                color: widget.active ? Colors.white : const Color(0xFF8B92A5),
                fontSize: 13.5,
                fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('KL', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
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
          const Icon(Icons.logout_rounded, color: Color(0xFF6B7280), size: 14),
        ],
      ),
    );
  }
}
