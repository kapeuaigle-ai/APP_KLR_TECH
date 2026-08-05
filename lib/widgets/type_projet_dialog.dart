import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'common.dart';
import 'responsive.dart';

/// Boîte de création / édition d'un type de projet — partagée entre
/// Paramètres (§ TYPES DE PROJET, l'endroit « officiel ») et la boîte
/// « Nouveau projet » (§ chip « + Nouveau type »), qui l'ouvre quand le
/// manager ne trouve pas le type qu'il cherche sans quitter son geste en
/// cours. Une seule implémentation : deux formulaires de création de type
/// auraient fini par diverger, comme l'a déjà appris cette base de code sur
/// une autre règle dupliquée.
///
/// `onCreated` n'est appelé que pour une création (jamais une édition) et
/// reçoit le type fraîchement ajouté — c'est ce qui permet à l'appelant de
/// le sélectionner immédiatement sans connaître l'algorithme de dérivation
/// de l'id.
void ouvrirFormulaireType(
  BuildContext context,
  AppState state, {
  TypeProjet? existing,
  ValueChanged<TypeProjet>? onCreated,
}) {
  final libelleCtrl = TextEditingController(text: existing?.libelle ?? '');
  ModeAvancement mode = existing?.mode ?? ModeAvancement.quantites;
  Color couleur = existing?.couleur ?? couleursTypeProjet.first;
  var erreur = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(existing == null ? 'Ajouter un type' : 'Modifier le type',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: dialogWidth(ctx, 380),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _champTexte(label: 'LIBELLÉ *', ctrl: libelleCtrl),
            const SizedBox(height: 14),
            Text('MODE D\'AVANCEMENT', style: AppTheme.label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: ModeAvancement.values.map((m) => GestureDetector(
              onTap: () => setLocal(() => mode = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mode == m ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: mode == m ? AppColors.primary : AppColors.border),
                ),
                child: Text(m.libelle, style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: mode == m ? AppColors.primary : AppColors.text2)),
              ),
            )).toList()),
            const SizedBox(height: 6),
            Text(mode.explication,
                style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3, height: 1.4)),
            const SizedBox(height: 14),
            Text('COULEUR', style: AppTheme.label),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 10, children: couleursTypeProjet.map((c) => GestureDetector(
              onTap: () => setLocal(() => couleur = c),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle,
                  border: Border.all(
                    color: couleur == c ? AppColors.text1 : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )).toList()),
            if (erreur) ...[
              const SizedBox(height: 12),
              Text('Renseignez un libellé.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(
          label: existing == null ? 'Ajouter' : 'Enregistrer',
          icon: existing == null ? Icons.add : Icons.check,
          onTap: () {
            final libelle = libelleCtrl.text.trim();
            if (libelle.isEmpty) { setLocal(() => erreur = true); return; }
            if (existing == null) {
              final id = _idDepuisLibelle(
                  libelle, state.settings.typesProjet.map((t) => t.id).toSet());
              final nouveau = TypeProjet(
                id: id, libelle: libelle, mode: mode, couleur: couleur,
              );
              state.ajouterTypeProjet(nouveau);
              Navigator.of(ctx).pop();
              onCreated?.call(nouveau);
            } else if (mode != existing.mode) {
              // Le mode a changé : ça recalcule l'avancement de tous les
              // projets de ce type, donc confirmation avant d'appliquer
              // (§ défaut 3 de la revue finale). Le dialogue d'édition
              // reste ouvert tant que rien n'est confirmé.
              _confirmerChangementMode(ctx, state, existing, mode, () {
                state.majTypeProjet(existing
                  ..libelle = libelle
                  ..mode = mode
                  ..couleur = couleur);
                Navigator.of(ctx).pop();
              });
            } else {
              state.majTypeProjet(existing
                ..libelle = libelle
                ..mode = mode
                ..couleur = couleur);
              Navigator.of(ctx).pop();
            }
          },
        ),
      ],
    )),
  );
}

/// Couleurs proposées pour un type de projet — la même palette, qu'on
/// crée depuis Paramètres ou depuis la boîte « Nouveau projet ».
const couleursTypeProjet = [
  AppColors.primary, AppColors.blue, AppColors.green, AppColors.orange,
  AppColors.purple, AppColors.teal, AppColors.emerald, AppColors.indigo,
];

/// Changer le mode d'avancement d'un type recalcule instantanément
/// l'avancement — et donc la colonne Kanban — de tous ses projets. Même
/// ampleur que la suppression, mais avec moins de cérémonie jusqu'ici.
/// N'apparaît que si le mode a réellement changé : changer le libellé ou la
/// couleur seul reste immédiat, pour ne pas gêner le cas courant.
void _confirmerChangementMode(BuildContext context, AppState state,
    TypeProjet existing, ModeAvancement nouveauMode, VoidCallback onConfirme) {
  final affectes = state.projets.where((p) => p.typeId == existing.id).length;

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Changer le mode d\'avancement ?', style: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: Text(
        affectes == 0
            ? 'Aucun projet n\'utilise actuellement « ${existing.libelle} » : rien ne sera recalculé.'
            : '$affectes ${affectes > 1 ? 'projets utilisent' : 'projet utilise'} '
              '« ${existing.libelle} ». ${affectes > 1 ? 'Leur' : 'Son'} avancement, mesuré par '
              '« ${existing.mode.libelle} », sera désormais mesuré par « ${nouveauMode.libelle} ».',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirme();
          },
          child: Text('Confirmer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ],
    ),
  );
}

/// Dérive un identifiant stable d'un libellé : minuscules, sans accents ni
/// espaces, avec un suffixe numérique en cas de collision.
String _idDepuisLibelle(String libelle, Set<String> existants) {
  const avecAccents = 'àáâãäåèéêëìíîïòóôõöùúûüýÿçñ';
  const sansAccents = 'aaaaaaeeeeiiiiooooouuuuyycn';
  var base = libelle.toLowerCase();
  for (var i = 0; i < avecAccents.length; i++) {
    base = base.replaceAll(avecAccents[i], sansAccents[i]);
  }
  base = base.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  if (base.isEmpty) base = 'type';

  if (!existants.contains(base)) return base;
  var i = 2;
  while (existants.contains('$base$i')) {
    i++;
  }
  return '$base$i';
}

/// Champ libellé décoré — même présentation que `_SettingField` de
/// parametres_screen.dart, reproduite ici pour ne pas dépendre d'une classe
/// privée d'un autre fichier. Pure présentation, aucune règle métier.
Widget _champTexte({required String label, required TextEditingController ctrl}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.label),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
      decoration: InputDecoration(
        filled: true, fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    ),
  ]);
}
