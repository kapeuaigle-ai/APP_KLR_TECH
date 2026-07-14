import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

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
          _SearchBar(),
          const Spacer(),
          _IconBtn(icon: Icons.notifications_outlined, badge: true),
          const SizedBox(width: 4),
          _IconBtn(icon: Icons.help_outline_rounded),
          const SizedBox(width: 12),
          _UserChip(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  const _IconBtn({required this.icon, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, size: 18, color: AppColors.text2),
          onPressed: () {},
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (badge)
          Positioned(
            right: 6, top: 6,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
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
