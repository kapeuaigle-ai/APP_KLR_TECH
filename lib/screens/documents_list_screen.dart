import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/pdf_generator.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/document_preview.dart';
import '../widgets/responsive.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  String _search = '';
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final type = state.docType;
    // Seules les proformas portent un statut (en cours / validée / annulée).
    // Les factures et BL sont générés à la validation d'une proforma.
    final isProforma = type == 'proforma';
    final allDocs = state.documents[type] ?? [];

    final filtered = allDocs.where((d) {
      final matchSearch = _search.isEmpty ||
          d.numero.toLowerCase().contains(_search.toLowerCase()) ||
          d.client.toLowerCase().contains(_search.toLowerCase()) ||
          d.objet.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'tous' || d.statut == _filter;
      return matchSearch && matchFilter;
    }).toList();

    // Compteurs par statut, affichés directement dans les filtres.
    // Un compteur à 0 n'est pas montré (inutile d'encombrer).
    final counts = {
      'tous': allDocs.length,
      'cours': allDocs.where((d) => d.statut == 'cours').length,
      'validee': allDocs.where((d) => d.statut == 'validee').length,
      'annulee': allDocs.where((d) => d.statut == 'annulee').length,
    };
    String chipLabel(String key, String label) {
      final n = counts[key] ?? 0;
      return n > 0 ? '$label ($n)' : label;
    }

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SectionHeader(
              title: 'Documents',
              subtitle: 'Gérez vos proformas, factures et bons de livraison.',
              actions: [
                PrimaryBtn(label: 'Nouvelle Proforma', icon: Icons.add, onTap: () => state.setCreating(true)),
              ],
            ),
            const SizedBox(height: 24),

            // Type tabs
            _TypeTabs(current: type, onChanged: (t) { state.setDocType(t); setState(() { _filter = 'tous'; _search = ''; }); }),
            const SizedBox(height: 20),

            // Barre de recherche. Le nombre de documents par statut est
            // désormais porté par les filtres eux-mêmes, plus par des cartes.
            Align(
              alignment: Alignment.centerLeft,
              child: SearchField(placeholder: 'Rechercher un document...', onChanged: (v) => setState(() => _search = v), maxWidth: 280),
            ),
            const SizedBox(height: 16),

            // Filter chips — seulement pour les proformas (les autres n'ont pas de statut).
            if (isProforma) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in [('tous', 'Tous'), ('cours', 'En cours'), ('validee', 'Validé'), ('annulee', 'Annulé')])
                  AppFilterChip(label: chipLabel(f.$1, f.$2), active: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
              ]),
              const SizedBox(height: 16),
            ],

            // Téléphone : une carte par document (le tableau ferait 1020 px).
            if (isPhone(context))
              if (filtered.isEmpty)
                const CardBox(padding: EdgeInsets.zero, child: EmptyHint('Aucun document trouvé'))
              else
                ...filtered.map((d) => _DocCard(doc: d, type: type))
            else
              CardBox(
                padding: EdgeInsets.zero,
                child: HScrollTable(
                  minWidth: 1020,
                  child: Column(children: [
                    // Table header
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        const Expanded(flex: 3, child: ThCell('NUMÉRO')),
                        const Expanded(flex: 3, child: ThCell('DATE')),
                        const Expanded(flex: 4, child: ThCell('CLIENT')),
                        const Expanded(flex: 4, child: ThCell('OBJET')),
                        const Expanded(flex: 3, child: ThCell('MONTANT')),
                        if (isProforma) const Expanded(flex: 2, child: ThCell('STATUT')),
                        const SizedBox(width: 60),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    if (filtered.isEmpty)
                      const EmptyHint('Aucun document trouvé')
                    else
                      ...filtered.asMap().entries.map((e) => _DocRow(doc: e.value, type: type, isLast: e.key == filtered.length - 1)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _TypeTabs({required this.current, required this.onChanged});

  // (clé, libellé bureau, libellé téléphone)
  static const _tabs = [
    ('proforma', 'Proformas', 'Proformas'),
    ('facture', 'Factures', 'Factures'),
    ('bl', 'Bons de Livraison', 'BL'),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 2))),
      // « Bons de Livraison » pousse la rangée au-delà de 360 px : on la rend
      // défilante. Sur grand écran elle tient et rien ne bouge.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: _tabs.map((t) {
          final active = t.$1 == current;
          return GestureDetector(
            onTap: () => onChanged(t.$1),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2)),
              ),
              // Libellé raccourci sur téléphone, où la place est comptée.
              child: Text(phone ? (t.$3) : t.$2, style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.text2,
              )),
            ),
          );
        }).toList()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Actions d'un document
//
//  Extrait de l'ancien State de la ligne de tableau : générer le PDF,
//  l'imprimer, l'enregistrer, ouvrir le détail ou l'aperçu pleine page ne
//  dépend d'aucun état de widget. Ligne de bureau et carte mobile partagent
//  donc exactement le même comportement.
// ─────────────────────────────────────────────────────────
class _DocActions {
  final DocumentItem doc;
  final String type;
  const _DocActions({required this.doc, required this.type});

  static const _typeLabels = {'proforma': 'Proforma', 'facture': 'Facture', 'bl': 'Bon de livraison'};
  static const _fullTypeLabels = {'proforma': 'Facture Proforma', 'facture': 'Facture', 'bl': 'Bon de livraison'};

  // Montant recalculé depuis les lignes enregistrées du document.
  // Le BL ne porte aucun montant.
  double totals() {
    if (type == 'bl') return 0;
    return doc.lines.fold<double>(0, (sum, l) => sum + l.total);
  }

  // Régénère le PDF du document depuis ses lignes enregistrées.
  Future<List<int>> _buildPdf(BuildContext context) {
    final s = context.read<AppState>().settings;
    return PdfGenerator.generate(
      settings: s,
      type: type,
      numero: doc.numero,
      // Date imprimée = celle saisie par le manager (et non la date interne
      // de création, qui ne sert qu'à la numérotation).
      date: doc.dateAffichee,
      client: doc.client,
      clientAddr: doc.clientAddr,
      objet: doc.objet,
      lines: doc.lines,
      montant: totals(),
      conditions: s.conditions,
    );
  }

  // ── Aperçu du document en pleine page ──────────────────
  void showFullDocument(BuildContext context) {
    final s = context.read<AppState>().settings;
    const typeLabels = _fullTypeLabels;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // En-tête de la fenêtre
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${typeLabels[type] ?? type}  ·  ${doc.numero}',
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
                  const SizedBox(height: 2),
                  Text(doc.client, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                ])),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close, size: 18, color: AppColors.text2),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Document A4 défilant
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: doc.lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text(
                          'Ce document a été créé avant l\'enregistrement du détail\ndes lignes : son contenu ne peut pas être reconstitué.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3, height: 1.5),
                        )),
                      )
                    : DocumentPreview(
                        type: type,
                        numero: doc.numero,
                        settings: s,
                        date: doc.dateAffichee,
                        client: doc.client,
                        clientAddr: doc.clientAddr,
                        objet: doc.objet,
                        lines: doc.lines,
                        montant: totals(),
                        conditions: s.conditions,
                        showToolbar: false,
                      ),
              ),
            ),
            // Actions
            if (doc.lines.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  // Seule la proforma se modifie : facture et BL en sont dérivés
                  // automatiquement à la validation.
                  //
                  // Une proforma déjà VALIDÉE ne s'ouvre plus en édition : sa
                  // facture, son BL et sa créance sont figés sur son contenu
                  // (défaut critique, revue Lot D) — la modifier ici les
                  // désynchroniserait silencieusement. Le bouton reste visible
                  // (pas de contrôle mort) mais explique pourquoi au lieu de
                  // naviguer ; « Dévalider », dans la fiche détail, est
                  // l'échappatoire tant qu'aucun règlement n'est enregistré.
                  if (type == 'proforma')
                    TextButton.icon(
                      onPressed: () {
                        if (doc.statut == 'validee') {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text(
                              'Proforma validée : la facture et le BL déjà émis en '
                              'dépendent, elle ne peut plus être modifiée. Utilisez '
                              '« Dévalider » (tant qu\'aucun règlement n\'est '
                              'enregistré) pour la corriger.',
                              style: TextStyle(fontSize: 13),
                            ),
                            backgroundColor: AppColors.orange,
                            duration: const Duration(seconds: 6),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            margin: const EdgeInsets.all(16),
                          ));
                          return;
                        }
                        Navigator.of(ctx).pop();
                        context.read<AppState>().startEditProforma(doc);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.text2),
                      label: Text('Modifier', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                    ),
                  TextButton.icon(
                    onPressed: () => printPdf(context),
                    icon: const Icon(Icons.print_outlined, size: 16, color: AppColors.text2),
                    label: Text('Imprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  ),
                  TextButton.icon(
                    onPressed: () => downloadPdf(context),
                    icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.primary),
                    label: Text('Télécharger PDF', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> printPdf(BuildContext context) async {
    try {
      await PdfGenerator.printDoc(await _buildPdf(context));
    } catch (e) {
      if (context.mounted) _pdfError(context, e);
    }
  }

  Future<void> downloadPdf(BuildContext context) async {
    try {
      final path = await PdfGenerator.saveWithDialog(
          bytes: await _buildPdf(context), type: type, numero: doc.numero);
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF enregistré :\n$path', style: const TextStyle(fontSize: 13)),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted) _pdfError(context, e);
    }
  }

  void _pdfError(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Erreur PDF : $e', style: const TextStyle(fontSize: 13)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void showDetails(BuildContext context) {
        const typeLabels = _typeLabels;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Expanded(child: Text(doc.numero, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary))),
          if (type == 'proforma') StatusBadge(status: doc.statut),
        ]),
        content: SizedBox(
          width: dialogWidth(ctx, 380),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final item in [
              ('Type', typeLabels[type] ?? type),
              ('Date', doc.date),
              ('Client', doc.client),
              ('Objet', doc.objet),
              ('Montant', doc.montant > 0 ? Fmt.money(doc.montant) : '—'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 90, child: Text(item.$1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
                  Expanded(child: Text(item.$2, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1))),
                ]),
              ),
            // Changement de statut : uniquement pour les proformas. Valider
            // une proforma génère la facture et le BL ; factures et BL n'ont
            // pas de statut propre.
            //
            // Une fois VALIDÉE, ce bloc bascule : les trois boutons rapides
            // cours/validée/annulée disparaissent — en repartir vers 'cours'
            // ou 'annulée' par cette voie laisserait la facture, le BL et la
            // créance déjà générés orphelins (compounding du défaut critique,
            // revue Lot D ; `AppState.setDocumentStatus` le refuse de toute
            // façon, mais ne plus le PROPOSER évite de faire croire que ça
            // marche). Seule « Dévalider » sait défaire proprement, et
            // seulement tant qu'aucun règlement n'a bougé sur la créance.
            if (type == 'proforma') ...[
              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              if (doc.statut == 'validee')
                _StatutValideeSection(doc: doc, outerContext: context)
              else ...[
                Text('CHANGER LE STATUT', style: AppTheme.label),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Valider une proforma génère automatiquement la facture et le bon de livraison avec le même numéro.',
                    style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3, height: 1.4),
                  ),
                ),
                Row(children: [
                  for (final s in [('cours', 'En cours', AppColors.orange), ('validee', 'Validée', AppColors.green), ('annulee', 'Annulée', AppColors.text2)])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final appState = context.read<AppState>();
                          if (s.$1 == 'validee') {
                            final generated = appState.validateProforma(doc.id);
                            if (generated) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Facture et Bon de livraison ${doc.numero} générés.',
                                    style: const TextStyle(fontSize: 13)),
                                backgroundColor: AppColors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                margin: const EdgeInsets.all(16),
                              ));
                            }
                          } else {
                            appState.setDocumentStatus(type, doc.id, s.$1);
                          }
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: doc.statut == s.$1 ? s.$3.withValues(alpha: 0.12) : AppColors.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: doc.statut == s.$1 ? s.$3 : AppColors.border),
                          ),
                          child: Text(s.$2, style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: doc.statut == s.$1 ? s.$3 : AppColors.text2)),
                        ),
                      ),
                    ),
                ]),
              ],
            ],
          ]),
        ),
        actions: [
          TextButton.icon(
            onPressed: () { Navigator.of(ctx).pop(); showFullDocument(context); },
            icon: const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
            label: Text('Voir le document', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
          ),
        ],
      ),
    );
  }

}

// ── Bloc « proforma validée » de la fiche détail ──────────
//
// Remplace les boutons rapides CHANGER LE STATUT une fois la proforma
// validée : sa facture, son BL et sa créance sont figés, il n'y a plus de
// changement de statut « rapide » qui tienne (voir showDetails). Explique le
// verrou, puis propose « Dévalider » — sauf si un règlement existe déjà sur
// la créance générée, auquel cas l'argent a réellement bougé et il n'y a plus
// d'échappatoire (`AppState.peutDevaliderProforma`).
class _StatutValideeSection extends StatelessWidget {
  final DocumentItem doc;
  // Contexte de l'écran (PAS celui, éphémère, de la boîte de dialogue) : sert
  // à ouvrir la confirmation de dévalidation APRÈS avoir fermé cette fiche —
  // même schéma que `showFullDocument(context)` plus haut dans ce fichier.
  final BuildContext outerContext;
  const _StatutValideeSection({required this.doc, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final peut = state.peutDevaliderProforma(doc.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PROFORMA VALIDÉE', style: AppTheme.label),
      const SizedBox(height: 8),
      Text(
        'La facture et le bon de livraison ont été générés avec le même numéro, '
        'et la créance correspondante figure en comptabilité : cette proforma ne '
        'peut plus être modifiée ni changer de statut directement.',
        style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3, height: 1.4),
      ),
      const SizedBox(height: 10),
      if (!peut)
        Text(
          'Dévalidation impossible : un règlement a déjà été enregistré sur la '
          'créance associée. L\'argent a bougé, ce document ne peut plus être '
          'défait — la correction se fait ailleurs (avoir, ajustement en '
          'comptabilité).',
          style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.red, height: 1.4),
        )
      else
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // ferme cette fiche détail
            _confirmerDevalidationProforma(outerContext, state, doc);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.red),
            ),
            child: Text('Dévalider', style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.red)),
          ),
        ),
    ]);
  }
}

/// Dévalider une proforma retire la facture, le BL et la créance qu'elle a
/// générés, et la ramène à « en cours ». Bouton non affiché si un règlement
/// existe déjà (voir `_StatutValideeSection`), donc pas besoin de revérifier
/// ici — mais `AppState.devaliderProforma` referait le contrôle de toute
/// façon si jamais cet appel venait d'ailleurs. Même cérémonie que
/// `_confirmerSuppressionProjet` dans projets_screen.dart : la confirmation
/// nomme concrètement ce qui va disparaître.
void _confirmerDevalidationProforma(BuildContext context, AppState state, DocumentItem doc) {
  final gen = state.docsGeneresPourProforma(doc);
  final parts = <String>[
    if (gen.facture != null) 'la facture ${gen.facture!.numero}',
    if (gen.bl != null) 'le bon de livraison ${gen.bl!.numero}',
    if (gen.engagement != null) 'la créance de ${Fmt.money(gen.engagement!.montant)}',
  ];
  final message = parts.isEmpty
      ? 'Aucune facture, aucun BL ni aucune créance n\'ont été retrouvés pour '
        'cette proforma : elle repassera simplement en cours.'
      : '${parts.join(', ')} seront supprimés. La proforma « ${doc.numero} » '
        'repassera en cours.';

  showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Dévalider cette proforma ?', style: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        TextButton(
          onPressed: () {
            state.devaliderProforma(doc.id);
            Navigator.of(dctx).pop();
          },
          child: Text('Dévalider', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
        ),
      ],
    ),
  );
}

// ── Carte document (téléphone) ────────────────────────────
class _DocCard extends StatelessWidget {
  final DocumentItem doc;
  final String type;
  const _DocCard({required this.doc, required this.type});

  @override
  Widget build(BuildContext context) {
    final actions = _DocActions(doc: doc, type: type);
    final isProforma = type == 'proforma';

    // Bande de couleur reprenant le statut : le repère le plus utile d'un
    // coup d'œil dans une liste de proformas.
    final accent = !isProforma ? null : switch (doc.statut) {
      'validee' => AppColors.green,
      'annulee' => AppColors.text3,
      _ => AppColors.orange,
    };

    return ListCard(
      accent: accent,
      title: Text(doc.numero, style: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary,
      )),
      subtitle: Text(doc.client, style: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text1,
      ), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isProforma ? StatusBadge(status: doc.statut) : null,
      fields: [
        ('DATE', CardValue(doc.date)),
        if (doc.objet.isNotEmpty) ('OBJET', CardValue(doc.objet)),
        if (type != 'bl')
          ('MONTANT', CardValue(doc.montant > 0 ? Fmt.money(doc.montant) : '—', bold: true)),
      ],
      // Toute la carte ouvre le détail : plus facile à viser qu'une icône.
      onTap: () => actions.showDetails(context),
    );
  }
}

class _DocRow extends StatefulWidget {
  final DocumentItem doc;
  final String type;
  final bool isLast;
  const _DocRow({required this.doc, required this.type, required this.isLast});

  @override
  State<_DocRow> createState() => _DocRowState();
}

class _DocRowState extends State<_DocRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final actions = _DocActions(doc: doc, type: widget.type);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFFAFAFB) : AppColors.surface,
          border: widget.isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
          borderRadius: widget.isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(doc.numero, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.date, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.client, maxLines: 1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.objet, maxLines: 1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.montant > 0 ? Fmt.money(doc.montant) : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          if (widget.type == 'proforma')
            Expanded(flex: 2, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StatusBadge(status: doc.statut),
            )),
          SizedBox(width: 60, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              tooltip: 'Voir le document',
              icon: const Icon(Icons.remove_red_eye_outlined, size: 15, color: AppColors.text3),
              onPressed: () => actions.showDetails(context),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ])),
        ]),
      ),
    );
  }
}
