import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Période bornée, avec un libellé lisible.
class Periode {
  final DateTime debut, fin;
  final String label;
  const Periode({required this.debut, required this.fin, required this.label});

  /// Raccourcis proposés au manager. `reference` permet de tester sans
  /// dépendre de l'horloge.
  static Periode ceMois([DateTime? reference]) {
    final n = reference ?? DateTime.now();
    return Periode(
      debut: DateTime(n.year, n.month, 1),
      fin: DateTime(n.year, n.month + 1, 0),
      label: 'Ce mois',
    );
  }

  static Periode moisDernier([DateTime? reference]) {
    final n = reference ?? DateTime.now();
    return Periode(
      debut: DateTime(n.year, n.month - 1, 1),
      fin: DateTime(n.year, n.month, 0),
      label: 'Mois dernier',
    );
  }

  static Periode troisMois([DateTime? reference]) {
    final n = reference ?? DateTime.now();
    return Periode(
      debut: DateTime(n.year, n.month - 2, 1),
      fin: DateTime(n.year, n.month + 1, 0),
      label: '3 derniers mois',
    );
  }

  static Periode cetteAnnee([DateTime? reference]) {
    final n = reference ?? DateTime.now();
    return Periode(
      debut: DateTime(n.year, 1, 1),
      fin: DateTime(n.year, 12, 31),
      label: 'Cette année',
    );
  }

  static String _jour(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Intervalle affiché à l'utilisateur.
  String get intervalle => '${_jour(debut)} → ${_jour(fin)}';

  Periode copieAvecLabel(String l) => Periode(debut: debut, fin: fin, label: l);
}

/// Sélecteur de période : quatre raccourcis et un choix personnalisé.
/// Le libellé de la période retenue et son intervalle exact restent visibles,
/// pour qu'on sache toujours sur quoi porte le rapport affiché.
class PeriodeSelector extends StatelessWidget {
  final Periode selection;
  final ValueChanged<Periode> onChanged;

  const PeriodeSelector({
    super.key,
    required this.selection,
    required this.onChanged,
  });

  static const _personnalise = 'Personnalisée';

  Future<void> _choisirPersonnalisee(BuildContext context) async {
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: selection.debut, end: selection.fin),
      helpText: 'Choisir la période du rapport',
      saveText: 'Valider',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (plage == null) return;
    onChanged(Periode(debut: plage.start, fin: plage.end, label: _personnalise));
  }

  @override
  Widget build(BuildContext context) {
    final raccourcis = [
      Periode.ceMois(),
      Periode.moisDernier(),
      Periode.troisMois(),
      Periode.cetteAnnee(),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Période du rapport', style: GoogleFonts.dmSans(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const Spacer(),
          // Intervalle exact : la valeur qui sera réellement utilisée.
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.redBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(selection.intervalle,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          )),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in raccourcis)
            _Chip(
              label: p.label,
              actif: selection.label == p.label,
              onTap: () => onChanged(p),
            ),
          _Chip(
            label: _personnalise,
            actif: selection.label == _personnalise,
            icone: Icons.tune_rounded,
            onTap: () => _choisirPersonnalisee(context),
          ),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool actif;
  final IconData? icone;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.actif, required this.onTap, this.icone});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: actif ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: actif ? AppColors.primary : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: actif ? Colors.white : AppColors.text2),
              const SizedBox(width: 6),
            ],
            Text(label, style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: actif ? Colors.white : AppColors.text2,
            )),
          ]),
        ),
      ),
    );
  }
}
