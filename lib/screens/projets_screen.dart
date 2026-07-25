import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

// ── Drag payload ──────────────────────────────────────────
class _DragData {
  final ProjectCard card;
  final int fromCol;
  const _DragData(this.card, this.fromCol);
}

// ── Screen ────────────────────────────────────────────────
class ProjetsScreen extends StatefulWidget {
  const ProjetsScreen({super.key});

  @override
  State<ProjetsScreen> createState() => _ProjetsScreenState();
}

class _ProjetsScreenState extends State<ProjetsScreen> {
  // Mutable column list enabling drag-and-drop reordering
  late List<_KanbanCol> _columns;

  @override
  void initState() {
    super.initState();
    _columns = [
      _KanbanCol(title: 'À faire', color: AppColors.text3, cards: [
        ProjectCard(tag: 'Design', title: 'Refonte interface mobile', desc: "Mise à jour de l'UI selon les nouvelles guidelines", date: '15 Mai', assignees: ['AK', 'MD'], subtasks: '2/5', attachments: 3, tags: ['Design', 'UX']),
        ProjectCard(tag: 'Dev', title: 'Module CRM clients', desc: 'Développement du CRM interne', date: '20 Mai', assignees: ['AB', 'JT'], subtasks: '0/8', tags: ['Backend', 'API']),
      ]),
      _KanbanCol(title: 'En cours', color: AppColors.blue, cards: [
        ProjectCard(tag: 'Dev', title: 'API OAuth2 Connecteurs', desc: 'Développement API Connecteurs pour plateformes tierces', date: '10 Mai', assignees: ['AB', 'KL'], subtasks: '4/6', attachments: 2, progress: 67, tags: ['API', 'Sécurité']),
        ProjectCard(tag: 'Infra', title: 'Migration cloud AWS', desc: 'Migrer les serveurs vers AWS EC2', date: '30 Mai', assignees: ['JT'], subtasks: '1/4', progress: 25, tags: ['Cloud']),
      ]),
      _KanbanCol(title: 'En révision', color: AppColors.orange, cards: [
        ProjectCard(tag: 'Design', title: 'Charte graphique 2026', desc: 'Validation des nouvelles couleurs et typographies', date: '5 Mai', assignees: ['AK', 'KL'], subtasks: '6/6', attachments: 8, progress: 100, tags: ['Branding']),
      ]),
      _KanbanCol(title: 'Terminé', color: AppColors.green, cards: [
        ProjectCard(tag: 'Dev', title: 'Dashboard analytics v2', desc: 'Nouveau tableau de bord avec graphiques temps réel', date: '28 Avr', assignees: ['AB', 'AK', 'MD'], subtasks: '12/12', attachments: 5, progress: 100, tags: ['Frontend']),
        ProjectCard(tag: 'Admin', title: 'Audit sécurité Q1', desc: 'Audit complet de la sécurité réseau', date: '20 Avr', assignees: ['KL'], subtasks: '8/8', progress: 100, tags: ['Sécurité']),
      ]),
    ];
  }

  void _moveCard(_DragData data, int toCol) {
    setState(() {
      _columns[data.fromCol].cards.remove(data.card);
      _columns[toCol].cards.add(data.card);
    });
  }

  // ── Dialogue "Nouveau projet" ───────────────────────────
  void _showAddProjectDialog(int colIndex) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String tag = 'Dev';

    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
      filled: true, fillColor: AppColors.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Nouveau projet — ${_columns[colIndex].title}',
            style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TITRE *', style: AppTheme.label),
            const SizedBox(height: 6),
            TextField(controller: titleCtrl, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1), decoration: deco('Nom du projet')),
            const SizedBox(height: 12),
            Text('DESCRIPTION', style: AppTheme.label),
            const SizedBox(height: 6),
            TextField(controller: descCtrl, maxLines: 2, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1), decoration: deco('Description courte')),
            const SizedBox(height: 12),
            Text('CATÉGORIE', style: AppTheme.label),
            const SizedBox(height: 6),
            Row(children: [
              for (final t in ['Dev', 'Design', 'Infra', 'Admin'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setDialogState(() => tag = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tag == t ? AppColors.primary.withValues(alpha: 0.1) : AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tag == t ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(t, style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: tag == t ? AppColors.primary : AppColors.text2)),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          PrimaryBtn(
            label: 'Créer',
            icon: Icons.add,
            onTap: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              setState(() {
                _columns[colIndex].cards.add(ProjectCard(
                  tag: tag,
                  title: title,
                  desc: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  assignees: const ['KL'],
                  subtasks: '0/0',
                ));
              });
              Navigator.of(ctx).pop();
            },
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Projets', style: AppTheme.h1),
              const SizedBox(height: 3),
              Text('Tableau Kanban de suivi de vos projets.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            ])),
            SecondaryBtn(label: 'Gantt', icon: Icons.bar_chart_rounded,
                onTap: () => context.read<AppState>().navigate(NavScreen.gantt)),
            const SizedBox(width: 12),
            PrimaryBtn(label: 'Nouveau projet', icon: Icons.add, onTap: () => _showAddProjectDialog(0)),
          ]),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _columns.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _KanbanColumnWidget(
                    col: e.value,
                    colIndex: e.key,
                    onDrop: (data) => _moveCard(data, e.key),
                    onAdd: () => _showAddProjectDialog(e.key),
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────
class _KanbanCol {
  final String title;
  final Color color;
  final List<ProjectCard> cards;
  _KanbanCol({required this.title, required this.color, required this.cards});
}

// ── Column widget with DragTarget ─────────────────────────
class _KanbanColumnWidget extends StatefulWidget {
  final _KanbanCol col;
  final int colIndex;
  final ValueChanged<_DragData> onDrop;
  final VoidCallback onAdd;
  const _KanbanColumnWidget({required this.col, required this.colIndex, required this.onDrop, required this.onAdd});

  @override
  State<_KanbanColumnWidget> createState() => _KanbanColumnWidgetState();
}

class _KanbanColumnWidgetState extends State<_KanbanColumnWidget> {
  bool _isOver = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) => details.data.fromCol != widget.colIndex,
      onAcceptWithDetails: (details) {
        setState(() => _isOver = false);
        widget.onDrop(details.data);
      },
      onLeave: (_) => setState(() => _isOver = false),
      onMove: (_) => setState(() => _isOver = true),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty || _isOver;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 280,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovering ? widget.col.color.withAlpha(15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovering ? widget.col.color.withAlpha(80) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.col.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(widget.col.title, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                    child: Text('${widget.col.cards.length}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2)),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Ajouter un projet dans « ${widget.col.title} »',
                    child: InkWell(
                      onTap: widget.onAdd,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.add, size: 16, color: AppColors.text2),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Cards — each wrapped in Draggable
              ...widget.col.cards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DraggableCard(card: card, colIndex: widget.colIndex),
              )),

              // Drop hint when empty and hovering
              if (widget.col.cards.isEmpty && hovering)
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.col.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.col.color.withAlpha(60), style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text('Déposer ici', style: GoogleFonts.dmSans(fontSize: 13, color: widget.col.color, fontWeight: FontWeight.w500)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Draggable card ────────────────────────────────────────
class _DraggableCard extends StatefulWidget {
  final ProjectCard card;
  final int colIndex;
  const _DraggableCard({required this.card, required this.colIndex});

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard> {
  bool _hovered = false;

  static const _tagColors = {
    'Dev': AppColors.blue, 'Design': AppColors.orange, 'Infra': AppColors.teal, 'Admin': AppColors.purple,
  };
  static const _tagBg = {
    'Dev': AppColors.blueBg, 'Design': AppColors.orangeBg, 'Infra': Color(0xFFECFEFF), 'Admin': AppColors.purpleBg,
  };

  Widget _buildCard({bool isPreview = false}) {
    final card = widget.card;
    final tagColor = _tagColors[card.tag] ?? AppColors.text2;
    final tagBg = _tagBg[card.tag] ?? AppColors.grayBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPreview ? Colors.white : (_hovered ? const Color(0xFFFAFAFB) : Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPreview ? AppColors.primary.withAlpha(120) : AppColors.border),
        boxShadow: isPreview
            ? [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 16, offset: const Offset(0, 6))]
            : _hovered
                ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (card.tag != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6)),
            child: Text(card.tag!, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: tagColor)),
          ),
          const SizedBox(height: 8),
        ],
        Text(card.title, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
        if (card.desc != null) ...[
          const SizedBox(height: 4),
          Text(card.desc!, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (card.progress != null) ...[
          const SizedBox(height: 10),
          ProgressBar(value: card.progress!, color: card.progress == 100 ? AppColors.green : AppColors.primary),
        ],
        const SizedBox(height: 10),
        Row(children: [
          ...card.assignees.take(3).toList().asMap().entries.map((e) => Transform.translate(
            offset: Offset(-e.key * 6.0, 0),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: [AppColors.primary, AppColors.blue, AppColors.purple, AppColors.emerald, AppColors.orange][e.key % 5],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(e.value, style: GoogleFonts.dmSans(fontSize: 7.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          )),
          const Spacer(),
          if (card.subtasks != null) ...[
            const Icon(Icons.check_box_outlined, size: 12, color: AppColors.text3),
            const SizedBox(width: 3),
            Text(card.subtasks!, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
            const SizedBox(width: 8),
          ],
          if (card.date != null) ...[
            const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.text3),
            const SizedBox(width: 3),
            Text(card.date!, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
          ],
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<_DragData>(
      data: _DragData(widget.card, widget.colIndex),
      onDragEnd: (_) => setState(() {}),
      feedback: SizedBox(width: 260, child: Material(color: Colors.transparent, child: _buildCard(isPreview: true))),
      childWhenDragging: Opacity(opacity: 0.35, child: _buildCard()),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: _buildCard(),
      ),
    );
  }
}
