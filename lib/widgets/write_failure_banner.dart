import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/app_state.dart';

/// Bannière persistante : rendue vide tant que la dernière écriture sur
/// disque a réussi, elle avertit dès que `AppState.derniereEcritureEnEchec`
/// passe à vrai (défaut 1, revue finitions).
///
/// Avant ce correctif, une écriture qui échouait (disque plein, verrou
/// antivirus, droits refusés) disparaissait en silence : `notifyListeners()`
/// avait déjà confirmé la mutation à l'écran avant que l'écriture échoue, et
/// rien ne le disait au manager. Le message dit explicitement quoi faire
/// (libérer de l'espace, fermer le programme qui verrouille le fichier) et
/// propose de relancer l'écriture ; il s'efface tout seul dès qu'une
/// écriture réussit, pour ne pas rester affiché après le retour à la
/// normale.
class WriteFailureBanner extends StatelessWidget {
  const WriteFailureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.derniereEcritureEnEchec) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: AppColors.redBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'La dernière modification n\'a pas pu être enregistrée sur le '
                'disque. Vérifiez l\'espace disque disponible et qu\'aucun autre '
                'programme (antivirus, sauvegarde) ne verrouille le fichier, '
                'puis réessayez.',
                style: GoogleFonts.dmSans(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => context.read<AppState>().retryPersist(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.red,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: Text('Réessayer', style: GoogleFonts.dmSans(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.red,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
