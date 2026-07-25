import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../core/pdf_generator.dart';
import '../widgets/common.dart';
import '../widgets/document_preview.dart';
import '../widgets/responsive.dart';

// ─────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────
class DocumentCreateScreen extends StatefulWidget {
  const DocumentCreateScreen({super.key});

  @override
  State<DocumentCreateScreen> createState() => _DocumentCreateScreenState();
}

class _DocumentCreateScreenState extends State<DocumentCreateScreen> {
  // Seule la proforma se crée ici : la facture et le BL sont générés
  // automatiquement à la validation de la proforma (voir AppState).
  static const _type = 'proforma';
  final _clientCtrl    = TextEditingController();
  final _clientAddrCtrl = TextEditingController();
  final _objetCtrl     = TextEditingController();
  final List<LineItem> _lines = [];

  double get _ht      => _lines.fold(0, (s, l) => s + l.total);
  double get _tvaAmt  => _tvaEnabled ? _ht * 0.05 : 0;
  double get _ttc     => _ht + _tvaAmt;
  bool   get _tvaEnabled => context.read<AppState>().settings.tva > 0;

  bool _saving = false;
  bool _downloading = false;

  // Numéro/date/id verrouillés à la 1ʳᵉ génération : les téléchargements ou
  // impressions suivants réutilisent (et mettent à jour) le même document, au
  // lieu d'en créer un nouveau et de « brûler » un numéro à chaque fois.
  String? _committedNumero;
  String? _committedDate;
  int? _docId;

  String _refFor(int idx) => (idx + 1).toString().padLeft(2, '0');

  // Numéro affiché : celui déjà verrouillé s'il existe, sinon le prochain
  // disponible (compteur du jour, repart à 01 chaque jour). La facture et le BL
  // en sont dérivés à la validation (voir DocNumero).
  String _numeroFor(AppState state) =>
      _committedNumero ??
      DocNumero.next(state.settings.prefix, _type, state.documents['proforma'] ?? [], DateTime.now());

  // Fige numéro + date + id pour la session (sans encore enregistrer), pour que
  // le PDF et l'enregistrement portent le même numéro.
  void _lockNumero(AppState state) {
    if (_committedNumero != null) return;
    final now = DateTime.now();
    _docId = now.millisecondsSinceEpoch;
    _committedDate = Fmt.jour(now);
    _committedNumero =
        DocNumero.next(state.settings.prefix, _type, state.documents['proforma'] ?? [], now);
  }

  // Enregistre (ou met à jour) la proforma dans l'app avec le contenu courant.
  // C'est ce qui fait avancer le compteur du jour : le prochain document ce
  // jour-là prendra le numéro suivant.
  void _commit(AppState state) {
    _lockNumero(state);
    state.saveOrUpdateProforma(DocumentItem(
      id: _docId!,
      numero: _committedNumero!,
      date: _committedDate!,
      clientId: 0,
      client: _clientCtrl.text.isNotEmpty ? _clientCtrl.text : 'Client non spécifié',
      clientAddr: _clientAddrCtrl.text,
      objet: _objetCtrl.text.isNotEmpty ? _objetCtrl.text : '—',
      montant: _ttc,
      statut: 'cours',
      lines: _lines
          .where((l) => l.designation.trim().isNotEmpty)
          .map((l) => LineItem(ref: l.ref, designation: l.designation, qte: l.qte, pu: l.pu))
          .toList(),
    ));
  }

  // ── PDF helper ───────────────────────────────────────
  Future<List<int>> _buildPdf(AppState state) => PdfGenerator.generate(
    settings: state.settings,
    type: _type,
    numero: _numeroFor(state),
    client: _clientCtrl.text,
    clientAddr: _clientAddrCtrl.text,
    objet: _objetCtrl.text,
    lines: List.from(_lines),
    tva: state.settings.tva > 0,
    ht: _ht, tvaAmt: _tvaAmt, ttc: _ttc,
    conditions: state.settings.conditions,
  );

  // ── Enregistrer ──────────────────────────────────────
  Future<void> _saveDocument(AppState state) async {
    setState(() => _saving = true);
    _commit(state);
    state.setCreating(false);
  }

  // ── Imprimer ─────────────────────────────────────────
  Future<void> _print(AppState state) async {
    try {
      _lockNumero(state);
      final bytes = await _buildPdf(state);
      await PdfGenerator.printDoc(bytes);
      _commit(state); // imprimé = document enregistré
    } catch (e) {
      if (mounted) _showError('Erreur impression : $e');
    }
  }

  // ── Télécharger (boîte "Enregistrer sous" → Téléchargements) ─────────
  Future<void> _download(AppState state) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      _lockNumero(state);
      final bytes = await _buildPdf(state);
      final path = await PdfGenerator.saveWithDialog(
          bytes: bytes, type: _type, numero: _committedNumero!);
      if (path != null) {
        _commit(state); // le PDF a bien été enregistré → on consigne le document
        if (mounted) _showSuccess('PDF enregistré :\n$path');
      }
    } catch (e) {
      if (mounted) _showError('Erreur téléchargement : $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: AppColors.green,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: AppColors.red,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void initState() {
    super.initState();
    _lines.add(LineItem(ref: '01', designation: '', qte: 1, pu: 0));
    _clientCtrl.addListener(_rebuild);
    _clientAddrCtrl.addListener(_rebuild);
    _objetCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _clientCtrl.dispose();
    _clientAddrCtrl.dispose();
    _objetCtrl.dispose();
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(LineItem(ref: _refFor(_lines.length), designation: '', qte: 1, pu: 0)));
  }

  void _removeLine(int i) {
    if (_lines.length > 1) {
      setState(() {
        _lines.removeAt(i);
        for (var j = 0; j < _lines.length; j++) {
          _lines[j].ref = _refFor(j);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1340),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Row(children: [
              GestureDetector(
                onTap: () => state.setCreating(false),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.text2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nouvelle Proforma', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Remplissez la proforma : la facture et le BL seront générés à sa validation.',
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              SecondaryBtn(label: 'Annuler', onTap: () => state.setCreating(false)),
              const SizedBox(width: 12),
              PrimaryBtn(
                label: _saving ? 'Enregistrement...' : 'Enregistrer',
                icon: Icons.save_outlined,
                onTap: _saving ? null : () => _saveDocument(state),
              ),
            ]),
            const SizedBox(height: 24),

            // L'aperçu reste à droite et rétrécit avec l'écran (l'A4 est en
            // AspectRatio) ; il ne passe dessous que sur écran étroit.
            LayoutBuilder(builder: (context, constraints) => ResponsiveSplit(
              sideWidth: math.min(530, constraints.maxWidth * 0.44),
              breakpoint: 700,
              spacing: 20,
              // ── Form ────────────────────────────────────
              main: _FormPanel(
                clientCtrl: _clientCtrl,
                clientAddrCtrl: _clientAddrCtrl,
                objetCtrl: _objetCtrl,
                lines: _lines,
                onAddLine: _addLine,
                onRemoveLine: _removeLine,
                ht: _ht, tvaAmt: _tvaAmt, ttc: _ttc,
                tva: _tvaEnabled,
                onLineChanged: () => setState(() {}),
                clients: state.clients,
                onClientSelected: (c) {
                  _clientCtrl.text = c.name;
                  if (c.address.isNotEmpty) _clientAddrCtrl.text = c.address;
                  setState(() {});
                },
              ),
              // ── Preview ─────────────────────────────────
              side: DocumentPreview(
                type: _type,
                numero: _numeroFor(state),
                settings: state.settings,
                client: _clientCtrl.text,
                clientAddr: _clientAddrCtrl.text,
                objet: _objetCtrl.text,
                lines: List.from(_lines),
                tva: _tvaEnabled,
                ht: _ht, tvaAmt: _tvaAmt, ttc: _ttc,
                conditions: state.settings.conditions,
                onPrint: () => _print(state),
                onDownload: _downloading ? null : () => _download(state),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Form Panel  (TVA & conditions removed — managed in Paramètres)
// ─────────────────────────────────────────────────────────
class _FormPanel extends StatelessWidget {
  final TextEditingController clientCtrl, clientAddrCtrl, objetCtrl;
  final List<LineItem> lines;
  final VoidCallback onAddLine;
  final ValueChanged<int> onRemoveLine;
  final bool tva;
  final double ht, tvaAmt, ttc;
  final VoidCallback onLineChanged;
  final List<Client> clients;
  final ValueChanged<Client> onClientSelected;

  const _FormPanel({
    required this.clientCtrl, required this.clientAddrCtrl,
    required this.objetCtrl,
    required this.lines, required this.onAddLine, required this.onRemoveLine,
    required this.tva,
    required this.ht, required this.tvaAmt, required this.ttc,
    required this.onLineChanged, required this.clients,
    required this.onClientSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Infos générales ──────────────────────────────
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informations générales',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 14),
        // Client autocomplete — auto-fills address
        _ClientAutocomplete(
          controller: clientCtrl,
          clients: clients,
          onSelected: onClientSelected,
        ),
        const SizedBox(height: 10),
        _LabelField(label: 'ADRESSE CLIENT', controller: clientAddrCtrl, hint: 'Adresse du client', maxLines: 2),
        const SizedBox(height: 10),
        _LabelField(label: 'OBJET', controller: objetCtrl, hint: 'Objet du document'),
      ])),
      const SizedBox(height: 14),

      // ── Lignes de facturation ────────────────────────
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lignes de facturation',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 14),
        // En-tête + lignes : défilement horizontal si le panneau est trop
        // étroit (zoom élevé, petite fenêtre) plutôt que d'écraser la colonne
        // Désignation.
        HScrollTable(
          minWidth: 470,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const SizedBox(width: 44, child: _ColHead('N°')),
              const SizedBox(width: 8),
              const Expanded(child: _ColHead('DÉSIGNATION')),
              const SizedBox(width: 8),
              const SizedBox(width: 50, child: _ColHead('QTÉ')),
              const SizedBox(width: 8),
              const SizedBox(width: 96, child: _ColHead('P.U. (FCFA)')),
              const SizedBox(width: 8),
              const SizedBox(width: 96, child: _ColHead('MONTANT')),
              const SizedBox(width: 28),
            ]),
            const SizedBox(height: 6),
            ...lines.asMap().entries.map((e) => _LineRow(
              key: ValueKey(e.key),
              line: e.value,
              onRemove: () => onRemoveLine(e.key),
              onChanged: onLineChanged,
            )),
          ]),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onAddLine,
          child: Row(children: [
            const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Ajouter une ligne',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 14),
        const Divider(color: AppColors.border),
        const SizedBox(height: 10),
        _TotalRow(label: 'SOUS-TOTAL HT', value: Fmt.money(ht)),
        if (tva) ...[const SizedBox(height: 5), _TotalRow(label: 'TVA (5%)', value: Fmt.money(tvaAmt))],
        const SizedBox(height: 5),
        _TotalRow(label: 'TOTAL TTC', value: Fmt.money(ttc), bold: true),
      ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Client Autocomplete
// ─────────────────────────────────────────────────────────
class _ClientAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<Client> clients;
  final ValueChanged<Client> onSelected;

  const _ClientAutocomplete({
    required this.controller,
    required this.clients,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CLIENT', style: GoogleFonts.dmSans(
          fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Autocomplete<Client>(
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) return const [];
          return clients.where((c) =>
              c.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        displayStringForOption: (c) => c.name,
        onSelected: onSelected,
        fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmit) {
          if (fieldCtrl.text != controller.text && controller.text.isNotEmpty) {
            fieldCtrl.text = controller.text;
          }
          fieldCtrl.addListener(() {
            if (fieldCtrl.text != controller.text) controller.text = fieldCtrl.text;
          });
          return TextField(
            controller: fieldCtrl,
            focusNode: focusNode,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
            decoration: _inputDeco('Nom du client...'),
          );
        },
        optionsViewBuilder: (ctx, onSelected2, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final c = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected2(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        AvatarCircle(initials: c.initials, color: c.color, size: 28, fontSize: 10),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                          Text(c.email, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
                          if (c.address.isNotEmpty)
                            Text(c.address, style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.text3),
                                overflow: TextOverflow.ellipsis),
                        ])),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Small helpers
// ─────────────────────────────────────────────────────────
InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
  filled: true, fillColor: AppColors.bg,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  isDense: true,
);

class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.dmSans(
      fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.6));
}

class _LabelField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final int maxLines;
  const _LabelField({required this.label, required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.8)),
    const SizedBox(height: 6),
    TextField(controller: controller, maxLines: maxLines,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1), decoration: _inputDeco(hint)),
  ]);
}

class _TotalRow extends StatelessWidget {
  final String label, value; final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: bold ? AppColors.text1 : AppColors.text2, letterSpacing: 0.4)),
    const Spacer(),
    Text(value, style: GoogleFonts.dmSans(
        fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: bold ? AppColors.primary : AppColors.text1)),
  ]);
}

// ─────────────────────────────────────────────────────────
//  Line Row (StatefulWidget — own controllers prevent cursor reset)
// ─────────────────────────────────────────────────────────
class _LineRow extends StatefulWidget {
  final LineItem line;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _LineRow({super.key, required this.line, required this.onRemove, required this.onChanged});

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  late TextEditingController _desCtrl, _qteCtrl, _puCtrl;

  @override
  void initState() {
    super.initState();
    _desCtrl = TextEditingController(text: widget.line.designation);
    _qteCtrl = TextEditingController(text: widget.line.qte.toString());
    _puCtrl  = TextEditingController(text: widget.line.pu > 0 ? widget.line.pu.toStringAsFixed(0) : '');
  }

  @override
  void didUpdateWidget(_LineRow old) {
    super.didUpdateWidget(old);
    if (old.line.ref != widget.line.ref) setState(() {});
  }

  @override
  void dispose() { _desCtrl.dispose(); _qteCtrl.dispose(); _puCtrl.dispose(); super.dispose(); }

  Widget _cell(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 8), child: child);

  TextField _tf(TextEditingController ctrl, {String hint = '', bool numeric = false, required ValueChanged<String> onChanged}) => TextField(
    controller: ctrl, onChanged: onChanged,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return _cell(Row(children: [
      SizedBox(width: 44, child: Container(
        height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
        child: Text(line.ref, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text2)),
      )),
      const SizedBox(width: 8),
      Expanded(child: _tf(_desCtrl, hint: 'Désignation du produit/service',
          onChanged: (v) { line.designation = v; widget.onChanged(); })),
      const SizedBox(width: 8),
      SizedBox(width: 50, child: _tf(_qteCtrl, numeric: true,
          onChanged: (v) { line.qte = int.tryParse(v) ?? 1; widget.onChanged(); })),
      const SizedBox(width: 8),
      SizedBox(width: 96, child: _tf(_puCtrl, hint: '0', numeric: true,
          onChanged: (v) { line.pu = double.tryParse(v) ?? 0; widget.onChanged(); })),
      const SizedBox(width: 8),
      SizedBox(width: 96, child: Container(
        height: 36, alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
        child: Text(Fmt.number(line.total),
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
      )),
      const SizedBox(width: 8),
      GestureDetector(onTap: widget.onRemove, child: const Icon(Icons.close, size: 16, color: AppColors.text3)),
    ]));
  }
}
