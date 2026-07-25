import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'responsive.dart';

// ── Status Badge ─────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, BadgeCfg>? config;
  const StatusBadge({super.key, required this.status, this.config});

  static const _doc = {
    'cours':   BadgeCfg(AppColors.orange,   AppColors.orangeBg, 'En cours'),
    'validee': BadgeCfg(AppColors.green,    AppColors.greenBg,  'Validée'),
    'annulee': BadgeCfg(AppColors.text2,    AppColors.grayBg,   'Annulée'),
    'paye':    BadgeCfg(AppColors.green,    AppColors.greenBg,  'Payé'),
    'attente': BadgeCfg(AppColors.orange,   AppColors.orangeBg, 'En attente'),
    'retard':  BadgeCfg(AppColors.red,      AppColors.redBg,    'En retard'),
    'actif':   BadgeCfg(AppColors.green,    AppColors.greenBg,  'Actif'),
    'mission': BadgeCfg(AppColors.blue,     AppColors.blueBg,   'En mission'),
    'conge':   BadgeCfg(AppColors.orange,   AppColors.orangeBg, 'En congé'),
    'termine': BadgeCfg(AppColors.green,    AppColors.greenBg,  'Terminé'),
    'planifie':BadgeCfg(AppColors.blue,     AppColors.blueBg,   'Planifié'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = (config ?? _doc)[status] ?? const BadgeCfg(AppColors.text2, AppColors.grayBg, '—');
    // FittedBox : le libellé reste toujours sur une seule ligne,
    // quitte à se réduire légèrement dans une colonne étroite.
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(20)),
          child: Text(cfg.label, maxLines: 1, style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w600, color: cfg.color,
          )),
        ),
      ),
    );
  }
}

class BadgeCfg {
  final Color color, bg;
  final String label;
  const BadgeCfg(this.color, this.bg, this.label);
}

// ── Avatar Circle ─────────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final double fontSize;
  const AvatarCircle({super.key, required this.initials, required this.color, this.size = 36, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: GoogleFonts.dmSans(
        color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700,
      )),
    );
  }
}

// ── Progress Bar ──────────────────────────────────────────
class ProgressBar extends StatelessWidget {
  final int value;
  final Color? color;
  final double height;
  const ProgressBar({super.key, required this.value, this.color, this.height = 5});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (value >= 100 ? AppColors.green : value > 0 ? AppColors.blue : AppColors.grayBg);
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.grayBg, borderRadius: BorderRadius.circular(99)),
      child: FractionallySizedBox(
        widthFactor: value / 100,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99)),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Widget? badge;
  final bool red;
  const StatCard({super.key, required this.label, required this.value, this.unit, this.sub, this.badge, this.red = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: red ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: red ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre + badge coloré sur la même ligne ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(label, style: GoogleFonts.dmSans(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                color: red ? Colors.white.withValues(alpha: 0.65) : AppColors.text3,
                letterSpacing: 0.8,
              ))),
              ?badge,
            ],
          ),
          const SizedBox(height: 10),
          // ── Valeur principale en bas ─────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: GoogleFonts.dmSans(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: red ? Colors.white : AppColors.text1,
                  letterSpacing: -0.5,
                )),
              )),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit!, style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: red ? Colors.white.withValues(alpha: 0.65) : AppColors.text3,
                  )),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(sub!, style: GoogleFonts.dmSans(fontSize: 12, color: red ? Colors.white.withValues(alpha: 0.65) : AppColors.text3)),
          ],
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.h1),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

// ── Card Container ────────────────────────────────────────
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  const CardBox({super.key, required this.child, this.padding, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// ── Primary Button ────────────────────────────────────────
class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const PrimaryBtn({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 6)],
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Secondary Button ──────────────────────────────────────
class SecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const SecondaryBtn({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text1,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: AppColors.text2), const SizedBox(width: 6)],
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text2)),
        ],
      ),
    );
  }
}

// ── Search Field ──────────────────────────────────────────
class SearchField extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String> onChanged;
  final double maxWidth;
  const SearchField({super.key, required this.placeholder, required this.onChanged, this.maxWidth = 340});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: AppColors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
              decoration: InputDecoration(
                hintText: placeholder,
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

// ── Tab bar ───────────────────────────────────────────────
class AppTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  const AppTabBar({super.key, required this.tabs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: tabs.asMap().entries.map((e) {
        final active = e.key == selected;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: Container(
            // Onglets un peu plus serrés sur téléphone : les cinq onglets du
            // Suivi restent atteignables sans trop défiler.
            padding: EdgeInsets.symmetric(
              horizontal: isPhone(context) ? 14 : 20,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(e.value, style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.primary : AppColors.text2,
            )),
          ),
        );
      }).toList(),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 2)),
      ),
      // Défilement horizontal : les cinq onglets du Suivi débordaient d'un
      // écran de 360 px et levaient une exception de rendu. Sur grand écran
      // la rangée tient d'elle-même et rien ne défile.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: row,
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const AppFilterChip({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: active ? Colors.white : AppColors.text2,
        )),
      ),
    );
  }
}

// ── Table header cell ─────────────────────────────────────
class ThCell extends StatelessWidget {
  final String label;
  const ThCell(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Text(label, style: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.text3, letterSpacing: 0.8,
      )),
    );
  }
}
