import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/data.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suivi', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Factures, dîme, tâches et notes internes.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),
            AppTabBar(
              tabs: const ['Factures & Crédits', 'Dîme', 'Tâches', 'Notes'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 20),
            if (_tab == 0) const _FacturesTab()
            else if (_tab == 1) const _DimeTab()
            else if (_tab == 2) const _TachesTab()
            else const _NotesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Factures Tab ──────────────────────────────────────────
class _FacturesTab extends StatelessWidget {
  const _FacturesTab();

  @override
  Widget build(BuildContext context) {
    final factures = SampleData.factureHistory;
    final totalPaye = factures.where((f) => f.statut == 'paye').fold<double>(0, (s, f) => s + f.montant);
    final totalAttente = factures.where((f) => f.statut == 'cours').fold<double>(0, (s, f) => s + f.montant);
    final totalRetard = factures.where((f) => f.statut == 'retard').fold<double>(0, (s, f) => s + f.montant);

    return Column(children: [
      Row(children: [
        Expanded(child: StatCard(label: 'ENCAISSÉ', value: Fmt.millions(totalPaye), unit: 'FCFA',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('Payé', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'EN ATTENTE', value: Fmt.millions(totalAttente), unit: 'FCFA')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'EN RETARD', value: Fmt.millions(totalRetard), unit: 'FCFA', red: true)),
      ]),
      const SizedBox(height: 20),

      CardBox(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            color: AppColors.bg,
            child: const Row(children: [
              Expanded(flex: 3, child: ThCell('N° FACTURE')),
              Expanded(flex: 4, child: ThCell('CLIENT')),
              Expanded(flex: 3, child: ThCell('MONTANT')),
              Expanded(flex: 2, child: ThCell('STATUT')),
              Expanded(flex: 3, child: ThCell('ÉCHÉANCE')),
              SizedBox(width: 60),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...factures.asMap().entries.map((e) {
            final f = e.value;
            final isLast = e.key == factures.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text(f.num, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                )),
                Expanded(flex: 4, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(f.client, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                )),
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(Fmt.money(f.montant), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                )),
                Expanded(flex: 2, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StatusBadge(status: f.statut),
                )),
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(f.echeance, style: GoogleFonts.dmSans(fontSize: 13, color: f.statut == 'retard' ? AppColors.red : AppColors.text2)),
                )),
                SizedBox(width: 60, child: IconButton(
                  icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
                  onPressed: () {},
                  padding: const EdgeInsets.all(6),
                )),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }
}

// ── Dîme Tab ──────────────────────────────────────────────
class _DimeTab extends StatelessWidget {
  const _DimeTab();

  @override
  Widget build(BuildContext context) {
    final history = SampleData.dimeHistory;
    final totalRevenu = history.fold<double>(0, (s, d) => s + d.revenu);
    final totalDime = history.fold<double>(0, (s, d) => s + d.dime);
    final totalPaye = history.where((d) => d.statut == 'paye').fold<double>(0, (s, d) => s + d.dime);

    return Column(children: [
      Row(children: [
        Expanded(child: StatCard(label: 'REVENU TOTAL (2026)', value: Fmt.millions(totalRevenu), unit: 'FCFA')),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'DÎME TOTALE (10%)', value: Fmt.millions(totalDime), unit: 'FCFA', red: true)),
        const SizedBox(width: 16),
        Expanded(child: StatCard(label: 'DÉJÀ VERSÉ', value: Fmt.millions(totalPaye), unit: 'FCFA',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('Payé', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
      ]),
      const SizedBox(height: 20),

      CardBox(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            color: AppColors.bg,
            child: const Row(children: [
              Expanded(flex: 3, child: ThCell('MOIS')),
              Expanded(flex: 3, child: ThCell('REVENU NET')),
              Expanded(flex: 3, child: ThCell('DÎME (10%)')),
              Expanded(flex: 2, child: ThCell('STATUT')),
              Expanded(flex: 3, child: ThCell('DATE VERSEMENT')),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...history.asMap().entries.map((e) {
            final d = e.value;
            final isLast = e.key == history.length - 1;
            return Container(
              decoration: BoxDecoration(
                color: d.statut == 'attente' ? const Color(0xFFFFFBEB) : Colors.white,
                border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(children: [
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text(d.mois, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                )),
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(Fmt.money(d.revenu), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                )),
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(Fmt.money(d.dime), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                )),
                Expanded(flex: 2, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StatusBadge(status: d.statut),
                )),
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(d.date ?? '—', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
                )),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }
}

// ── Tâches Tab ────────────────────────────────────────────
class _TachesTab extends StatefulWidget {
  const _TachesTab();

  @override
  State<_TachesTab> createState() => _TachesTabState();
}

class _TachesTabState extends State<_TachesTab> {
  final _ctrl = TextEditingController();
  String _assignee = 'Koffi Lambert';
  String _priorite = 'normale';

  static const _members = ['Koffi Lambert', 'Sara El Mansouri', 'Moussa Diallo', 'Amine Benjelloun'];
  static const _priorites = ['haute', 'normale', 'basse'];
  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};
  static const _priorityLabels = {'haute': 'Haute', 'normale': 'Normale', 'basse': 'Basse'};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.tasks;
    final done = tasks.where((t) => t.done).length;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Task list
      Expanded(child: Column(children: [
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Tâches en cours', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            const Spacer(),
            Text('$done/${tasks.length} terminées', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(value: tasks.isEmpty ? 0 : (done / tasks.length * 100).round(), color: AppColors.primary, height: 6),
          const SizedBox(height: 16),
          ...tasks.map((t) => _TaskItem(task: t)),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucune tâche', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
            ),
        ])),
      ])),
      const SizedBox(width: 16),

      // Add task form
      SizedBox(width: 300, child: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nouvelle tâche', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Description de la tâche...',
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        Text('ASSIGNÉ À', style: AppTheme.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _assignee,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          items: _members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _assignee = v!),
        ),
        const SizedBox(height: 12),
        Text('PRIORITÉ', style: AppTheme.label),
        const SizedBox(height: 6),
        Row(children: _priorites.map((p) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _priorite = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _priorite == p ? _priorityColors[p]!.withOpacity(0.12) : AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _priorite == p ? _priorityColors[p]! : AppColors.border),
              ),
              child: Text(_priorityLabels[p]!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _priorite == p ? _priorityColors[p]! : AppColors.text2)),
            ),
          ),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: PrimaryBtn(
          label: 'Ajouter la tâche',
          onTap: () {
            if (_ctrl.text.trim().isNotEmpty) {
              context.read<AppState>().addTask(Task(
                id: DateTime.now().millisecondsSinceEpoch,
                texte: _ctrl.text.trim(),
                assignee: _assignee,
                priorite: _priorite,
              ));
              _ctrl.clear();
            }
          },
        )),
      ]))),
    ]);
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  const _TaskItem({required this.task});

  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.read<AppState>().toggleTask(task.id),
          child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: task.done ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: task.done ? AppColors.green : AppColors.border, width: 1.5),
            ),
            child: task.done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.texte, style: GoogleFonts.dmSans(
            fontSize: 13.5, fontWeight: FontWeight.w500,
            color: task.done ? AppColors.text3 : AppColors.text1,
            decoration: task.done ? TextDecoration.lineThrough : null,
          )),
          Text(task.assignee, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
        ])),
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: _priorityColors[task.priorite] ?? AppColors.text3, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.read<AppState>().deleteTask(task.id),
          child: const Icon(Icons.close, size: 14, color: AppColors.text3),
        ),
      ]),
    );
  }
}

// ── Notes Tab ─────────────────────────────────────────────
class _NotesTab extends StatefulWidget {
  const _NotesTab();

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  Note? _editing;

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<AppState>().notes;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Notes grid using Wrap — avoids Expanded constraint issues
      Expanded(child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ...notes.map((n) => SizedBox(
            width: 240,
            height: 180,
            child: _NoteCard(note: n, onTap: () => setState(() => _editing = n)),
          )),
          SizedBox(
            width: 240,
            height: 180,
            child: _AddNoteCard(onTap: () => setState(() => _editing = Note(
              id: DateTime.now().millisecondsSinceEpoch,
              titre: '', contenu: '', color: AppColors.blue, date: "Aujourd'hui",
            ))),
          ),
        ],
      )),
      if (_editing != null) ...[
        const SizedBox(width: 16),
        SizedBox(width: 300, child: _NoteEditor(
          note: _editing!,
          onSave: (n) {
            context.read<AppState>().saveNote(n);
            setState(() => _editing = null);
          },
          onDelete: () {
            context.read<AppState>().deleteNote(_editing!.id);
            setState(() => _editing = null);
          },
          onClose: () => setState(() => _editing = null),
        )),
      ],
    ]);
  }
}

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteCard({required this.note, required this.onTap});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              top: BorderSide(color: n.color, width: 3),
              left: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
            boxShadow: _hovered ? [BoxShadow(color: n.color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.titre.isEmpty ? 'Sans titre' : n.titre, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Expanded : le contenu occupe tout l'espace disponible
            // et la date reste collée en bas de la carte
            Expanded(child: Text(n.contenu, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 8),
            Text(n.date, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
          ]),
        ),
      ),
    );
  }
}

class _AddNoteCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddNoteCard({required this.onTap});

  @override
  State<_AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends State<_AddNoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, size: 28, color: _hovered ? AppColors.primary : AppColors.text3),
            const SizedBox(height: 8),
            Text('Nouvelle note', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: _hovered ? AppColors.primary : AppColors.text3)),
          ]),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final Note note;
  final ValueChanged<Note> onSave;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _NoteEditor({required this.note, required this.onSave, required this.onDelete, required this.onClose});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late TextEditingController _titreCtrl;
  late TextEditingController _contenuCtrl;
  late Color _color;

  static const _colors = [AppColors.blue, AppColors.orange, AppColors.emerald, AppColors.purple, AppColors.red];

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController(text: widget.note.titre);
    _contenuCtrl = TextEditingController(text: widget.note.contenu);
    _color = widget.note.color;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _contenuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Éditer la note', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const Spacer(),
        GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, size: 16, color: AppColors.text3)),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: _titreCtrl,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1),
        decoration: InputDecoration(
          hintText: 'Titre de la note',
          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const Divider(color: AppColors.border),
      const SizedBox(height: 8),
      TextField(
        controller: _contenuCtrl,
        maxLines: 8,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Contenu de la note...',
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const SizedBox(height: 12),
      Text('COULEUR', style: AppTheme.label),
      const SizedBox(height: 8),
      Row(children: _colors.map((c) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: _color == c ? AppColors.text1 : Colors.transparent, width: 2),
            ),
          ),
        ),
      )).toList()),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: PrimaryBtn(label: 'Enregistrer', onTap: () {
          final updated = widget.note
            ..titre = _titreCtrl.text
            ..contenu = _contenuCtrl.text
            ..color = _color;
          widget.onSave(updated);
        })),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
          onPressed: widget.onDelete,
          padding: const EdgeInsets.all(8),
        ),
      ]),
    ]));
  }
}
