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

// ─────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────
class DocumentCreateScreen extends StatefulWidget {
  const DocumentCreateScreen({super.key});

  @override
  State<DocumentCreateScreen> createState() => _DocumentCreateScreenState();
}

class _DocumentCreateScreenState extends State<DocumentCreateScreen> {
  String _type = 'proforma';
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

  String _refFor(int idx) => (idx + 1).toString().padLeft(2, '0');

  // ── PDF helper ───────────────────────────────────────
  Future<List<int>> _buildPdf(AppSettings settings) => PdfGenerator.generate(
    settings: settings,
    type: _type,
    client: _clientCtrl.text,
    clientAddr: _clientAddrCtrl.text,
    objet: _objetCtrl.text,
    lines: List.from(_lines),
    tva: settings.tva > 0,
    ht: _ht, tvaAmt: _tvaAmt, ttc: _ttc,
    conditions: settings.conditions,
  );

  // ── Enregistrer ──────────────────────────────────────
  Future<void> _saveDocument(AppState state) async {
    setState(() => _saving = true);
    final now = DateTime.now();
    final d = '${now.day.toString().padLeft(2,'0')}${now.month.toString().padLeft(2,'0')}${now.year.toString().substring(2)}';
    final p = _type == 'proforma' ? 'P' : _type == 'facture' ? 'F' : 'B';
    final count = (state.documents[_type]?.length ?? 0) + 1;
    final numero = '${state.settings.prefix}-$p${count.toString().padLeft(3,'0')}-$d';

    final doc = DocumentItem(
      id: now.millisecondsSinceEpoch,
      numero: numero,
      date: '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}',
      clientId: 0,
      client: _clientCtrl.text.isNotEmpty ? _clientCtrl.text : 'Client non spécifié',
      objet: _objetCtrl.text.isNotEmpty ? _objetCtrl.text : '—',
      montant: _ttc,
      statut: 'cours',
    );
    state.addDocument(_type, doc);
    state.setCreating(false);
  }

  // ── Imprimer ─────────────────────────────────────────
  Future<void> _print(AppSettings settings) async {
    try {
      final bytes = await _buildPdf(settings);
      await PdfGenerator.printDoc(bytes);
    } catch (e) {
      if (mounted) _showError('Erreur impression : $e');
    }
  }

  // ── Télécharger (boîte "Enregistrer sous" → Téléchargements) ─────────
  Future<void> _download(AppSettings settings) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await _buildPdf(settings);
      final path = await PdfGenerator.saveWithDialog(
          bytes: bytes, type: _type);
      if (mounted && path != null) {
        _showSuccess('PDF enregistré :\n$path');
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
    _type = context.read<AppState>().docType;
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
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
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
                Text('Nouveau document', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Créez et prévisualisez votre document en temps réel.',
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

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Form ────────────────────────────────────
              Expanded(child: _FormPanel(
                type: _type,
                onTypeChange: (t) => setState(() => _type = t),
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
              )),
              const SizedBox(width: 20),
              // ── Preview ─────────────────────────────────
              SizedBox(
                width: 530,
                child: _A4Preview(
                  type: _type,
                  settings: state.settings,
                  client: _clientCtrl.text,
                  clientAddr: _clientAddrCtrl.text,
                  objet: _objetCtrl.text,
                  lines: List.from(_lines),
                  tva: _tvaEnabled,
                  ht: _ht, tvaAmt: _tvaAmt, ttc: _ttc,
                  conditions: state.settings.conditions,
                  onPrint: () => _print(state.settings),
                  onDownload: _downloading ? null : () => _download(state.settings),
                ),
              ),
            ]),
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
  final String type;
  final ValueChanged<String> onTypeChange;
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
    required this.type, required this.onTypeChange,
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
        // Type selector
        Row(children: [
          for (final t in [('proforma', 'Proforma'), ('facture', 'Facture'), ('bl', 'Bon de Livraison')])
            Padding(padding: const EdgeInsets.only(right: 8),
              child: _TypeChip(label: t.$2, active: type == t.$1, onTap: () => onTypeChange(t.$1))),
        ]),
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
                        StatusBadge(status: c.status),
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

class _TypeChip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.text2)),
    ),
  );
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

// ─────────────────────────────────────────────────────────
//  A4 Preview — paginated automatiquement
//  • Page 1  : en-tête complet + info boxes + objet + lignes
//  • Pages N : mini en-tête (suite) + lignes
//  • Dernière page : totaux + conditions + signature + pied de page
// ─────────────────────────────────────────────────────────
class _A4Preview extends StatelessWidget {
  final String type, client, clientAddr, objet, conditions;
  final List<LineItem> lines;
  final bool tva;
  final double ht, tvaAmt, ttc;
  final AppSettings settings;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;

  // Capacité max par page (530px de large → hauteur ~750px)
  // Page unique  : header + info boxes + totaux + conditions/signature (~205px de footer)
  static const _singlePageMax = 13;
  // Page 1 multi-pages : header + info boxes, SANS footer → ~170px libérés ≈ +8 lignes
  static const _firstPageMax  = 20;
  // Pages intermédiaires : mini-header seulement
  // Dernière page : mini-header + totaux + conditions/signature (~160px de footer)
  static const _lastPageMax   = 15;
  static const _midPageMax    = 22;

  const _A4Preview({
    required this.type, required this.settings,
    required this.client, required this.clientAddr,
    required this.objet, required this.lines, required this.tva,
    required this.ht, required this.tvaAmt, required this.ttc,
    required this.conditions,
    this.onPrint, this.onDownload,
  });

  String get _typeLabel {
    if (type == 'proforma') return 'FACTURE PROFORMA';
    if (type == 'facture') return 'FACTURE';
    return 'BON DE LIVRAISON';
  }

  String get _numero {
    final n = DateTime.now();
    final d = '${n.day.toString().padLeft(2,'0')}${n.month.toString().padLeft(2,'0')}${n.year.toString().substring(2)}';
    final prefix = type == 'proforma' ? 'P' : type == 'facture' ? 'F' : 'B';
    return '${settings.prefix}-${prefix}001-$d';
  }

  String get _dateStr {
    const months = ['Janvier','Février','Mars','Avril','Mai','Juin',
                    'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} ${n.year}';
  }

  // ── Découpe les lignes en pages ───────────────────────
  List<List<LineItem>> _paginate() {
    if (lines.isEmpty) return [[]];

    // Page unique : tout tient avec le footer (header + info + totaux + conditions)
    if (lines.length <= _singlePageMax) return [List.from(lines)];

    // Multi-pages : au moins 2 pages.
    // Page 1 : sans footer → plus de capacité. On s'assure qu'au moins 1 ligne
    // reste pour la page suivante afin que page 1 ne soit jamais aussi la dernière.
    final pages = <List<LineItem>>[];
    final firstCount = _firstPageMax.clamp(1, lines.length - 1);
    pages.add(lines.sublist(0, firstCount));
    var rem = lines.sublist(firstCount);

    // Pages du milieu (sans footer) puis dernière page (avec footer)
    while (rem.isNotEmpty) {
      // La dernière itération doit respecter _lastPageMax (footer inclus)
      final isLastChunk = rem.length <= _lastPageMax;
      final cap = isLastChunk ? _lastPageMax : _midPageMax;
      final n = rem.length.clamp(0, cap);
      pages.add(rem.sublist(0, n));
      rem = rem.sublist(n);
    }
    return pages;
  }

  // ── Widget de chaque page A4 ──────────────────────────
  Widget _buildPage({
    required List<LineItem> pageLines,
    required bool isFirst,
    required bool isLast,
    required int pageNum,
    required int totalPages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: AspectRatio(
        aspectRatio: 210 / 297,
        child: Column(children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── En-tête ─────────────────────────────
              if (isFirst) ...[
                // En-tête complet (page 1)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CustomPaint(size: const Size(26, 26), painter: _DiamondPainter()),
                    const SizedBox(width: 8),
                    Text('KLR TECH', style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.5)),
                  ]),
                  const Spacer(),
                  Text(_typeLabel, style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('N°  $_numero', style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  Text('Date : $_dateStr', style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.text3)),
                ])),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _InfoBox(
                    label: 'DE :',
                    lines: [settings.company, settings.address, 'BP : ${settings.rc}'],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoBox(
                    label: 'À L\'ATTENTION DE :',
                    lines: [
                      if (client.isNotEmpty) client,
                      if (clientAddr.isNotEmpty) clientAddr,
                      if (client.isEmpty && clientAddr.isEmpty) '—',
                    ],
                    highlight: true,
                  )),
                ]),
                const SizedBox(height: 12),
                if (objet.isNotEmpty) ...[
                  Text('Objet : $objet', style: GoogleFonts.dmSans(
                      fontSize: 9.5, color: AppColors.text2, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                ],
              ] else ...[
                // Mini en-tête de continuation
                Row(children: [
                  CustomPaint(size: const Size(18, 18), painter: _DiamondPainter()),
                  const SizedBox(width: 6),
                  Text('KLR TECH', style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.5)),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Suite — $_typeLabel', style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text2)),
                    Text('N°  $_numero   •   Page $pageNum / $totalPages',
                        style: GoogleFonts.dmSans(fontSize: 8, color: AppColors.text3)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
              ],

              // ── Tableau des lignes ────────────────────
              _PreviewTable(
                lines: pageLines,
                tva: tva,
                ht: ht, tvaAmt: tvaAmt, ttc: ttc,
                showTotals: isLast,
              ),

              // ── Totaux + montant en lettres (dernière page) ─
              if (isLast && ttc > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Arrêté la présente facture à la somme de : ${NumberToWords.convert(ttc)} FRANCS CFA.',
                  style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text1, height: 1.5),
                ),
              ],

              // ── Pousse le bas de page vers le bas ────
              const Spacer(),

              // ── Numéro de page (pages intermédiaires) ─
              if (!isLast)
                Align(
                  alignment: Alignment.center,
                  child: Text('— Page $pageNum / $totalPages —',
                      style: GoogleFonts.dmSans(fontSize: 7.5, color: AppColors.text3)),
                ),

              // ── Conditions + Signature (dernière page) ─
              // IntrinsicHeight → la boîte signature prend la même hauteur
              // que la colonne conditions.
              // Stack(clipBehavior: none) → le label "Signature" sort de 7px
              // au-dessus de la boîte, avec fond blanc qui masque le trait.
              if (isLast)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Conditions de règlement :',
                            style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                        const SizedBox(height: 4),
                        ...conditions.split('\n').where((l) => l.trim().isNotEmpty).map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('• ', style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2)),
                            Expanded(child: Text(l.trim(),
                                style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2, height: 1.4))),
                          ]),
                        )),
                        const SizedBox(height: 8),
                        Text(
                          'Tout produit, sauf mention contraire, bénéficie d\'une période de garantie contre tout vice de '
                          'fabrication (retour atelier sans frais de réparation ou échange standard dans la limite des stocks '
                          'disponibles) soumise à l\'expertise constructeur, à compter de la date de facturation et à condition '
                          'qu\'il soit tenu en bon état et que les étiquettes de code ne soient pas retirées ou déchirées.',
                          style: GoogleFonts.dmSans(fontSize: 7, color: AppColors.text3, height: 1.4),
                        ),
                      ])),
                      const SizedBox(width: 16),
                      // Boîte signature — Padding(top:7) laisse de la place au label
                      Expanded(child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Boîte en pointillés avec border-radius 16
                            Positioned.fill(child: CustomPaint(
                              painter: _DashedRectPainter(),
                            )),
                            // "Signature" centré sur le trait supérieur
                            Positioned(
                              top: -7, left: 0, right: 0,
                              child: Center(
                                child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('Signature', style: GoogleFonts.dmSans(
                                      fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.text3)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
            ]),
          )),

          // ── Pied de page (toutes les pages) ──────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
            color: const Color(0xFFF8F8F8),
            child: Text(
              '${settings.company.toUpperCase()}  |  ABIDJAN, CÔTE D\'IVOIRE  |  '
              'TÉL : +225 07 08 71 45 57  |  EMAIL : klr.tech@gmail.com  |  '
              'RC : ${settings.rc}  |  IF : ${settings.ifNum}',
              style: GoogleFonts.dmSans(fontSize: 6.5, color: AppColors.text3, letterSpacing: 0.4),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _paginate();
    final total = pages.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Toolbar
      Row(children: [
        Text('Aperçu', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const Spacer(),
        if (total > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
            child: Text('$total pages', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(width: 8),
        _ToolIcon(icon: Icons.print_outlined, onTap: onPrint, tooltip: 'Imprimer'),
        const SizedBox(width: 4),
        _ToolIcon(icon: Icons.download_outlined, onTap: onDownload, tooltip: 'Télécharger PDF'),
      ]),
      const SizedBox(height: 10),

      // Pages A4 empilées
      ...pages.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(top: e.key > 0 ? 14 : 0),
        child: _buildPage(
          pageLines: e.value,
          isFirst: e.key == 0,
          isLast: e.key == total - 1,
          pageNum: e.key + 1,
          totalPages: total,
        ),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Dashed rounded-rect painter  (PathMetrics → coins arrondis)
// ─────────────────────────────────────────────────────────
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;
  static const double strokeWidth = 0.8;

  const _DashedRectPainter({
    this.color = AppColors.border,
    this.dashWidth = 4,
    this.dashSpace = 3,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dashWidth).clamp(0.0, m.length)), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace || old.borderRadius != borderRadius;
}

// ─────────────────────────────────────────────────────────
//  Preview sub-widgets
// ─────────────────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final String label;
  final List<String> lines;
  final bool highlight;
  const _InfoBox({required this.label, required this.lines, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: highlight ? AppColors.primary : AppColors.text3, width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w800,
            color: highlight ? AppColors.primary : AppColors.text3, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        ...lines.asMap().entries.map((e) => Text(e.value, style: GoogleFonts.dmSans(
          fontSize: e.key == 0 ? 10 : 8.5,
          fontWeight: e.key == 0 ? FontWeight.w700 : FontWeight.w400,
          color: AppColors.text1, height: 1.5,
        ))),
      ]),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<LineItem> lines;
  final bool tva;
  final double ht, tvaAmt, ttc;
  final bool showTotals;
  const _PreviewTable({required this.lines, required this.tva, required this.ht, required this.tvaAmt, required this.ttc, this.showTotals = true});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header row
      Container(
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: const [
          SizedBox(width: 28, child: _TH('Réf')),
          SizedBox(width: 8),
          Expanded(child: _TH('Désignation')),
          SizedBox(width: 30, child: _TH('Qté', right: true)),
          SizedBox(width: 8),
          SizedBox(width: 70, child: _TH('P.U (FCFA)', right: true)),
          SizedBox(width: 8),
          SizedBox(width: 65, child: _TH('Montant', right: true)),
        ]),
      ),
      // Data rows
      ...lines.asMap().entries.map((e) {
        final l = e.value;
        final even = e.key % 2 == 0;
        return Container(
          color: even ? const Color(0xFFFAFAFA) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 28, child: Text(l.ref, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2))),
            const SizedBox(width: 8),
            Expanded(child: Text(l.designation, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text1, height: 1.3))),
            SizedBox(width: 30, child: Text('${l.qte}', style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2), textAlign: TextAlign.right)),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(Fmt.number(l.pu), style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2), textAlign: TextAlign.right)),
            const SizedBox(width: 8),
            SizedBox(width: 65, child: Text(Fmt.number(l.total), style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.text1), textAlign: TextAlign.right)),
          ]),
        );
      }),
      // Totaux — uniquement sur la dernière page
      if (showTotals) ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: SizedBox(width: 200, child: Column(children: [
          _PTotal(label: 'Sous-total HT', value: Fmt.number(ht)),
          if (tva) _PTotal(label: 'TVA (5%)', value: Fmt.number(tvaAmt)),
          const Divider(height: 8, color: AppColors.border),
          Row(children: [
            Text('TOTAL TTC', style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            Text(Fmt.number(ttc), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
        ]))),
      ],
    ]);
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.dmSans(
      fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
      textAlign: right ? TextAlign.right : TextAlign.left);
}

class _PTotal extends StatelessWidget {
  final String label, value;
  const _PTotal({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2)),
      const Spacer(),
      Text(value, style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
    ]),
  );
}

class _ToolIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _ToolIcon({required this.icon, this.onTap, this.tooltip});
  @override
  State<_ToolIcon> createState() => _ToolIconState();
}

class _ToolIconState extends State<_ToolIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null ? AppColors.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 16,
              color: _hovered && widget.onTap != null ? AppColors.text1 : AppColors.text3),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// ── Diamond logo painter ──────────────────────────────────
class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);
    final inner = Paint()..color = Colors.white.withAlpha(60);
    final ip = Path()
      ..moveTo(size.width / 2, size.height * 0.28)
      ..lineTo(size.width * 0.72, size.height / 2)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(size.width * 0.28, size.height / 2)
      ..close();
    canvas.drawPath(ip, inner);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
