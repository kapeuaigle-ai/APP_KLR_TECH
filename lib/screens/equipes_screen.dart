import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/data.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class EquipesScreen extends StatefulWidget {
  const EquipesScreen({super.key});

  @override
  State<EquipesScreen> createState() => _EquipesScreenState();
}

class _EquipesScreenState extends State<EquipesScreen> {
  int _tab = 0;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Équipes', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Gérez vos collaborateurs et départements.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              PrimaryBtn(label: 'Ajouter membre', icon: Icons.add, onTap: () => _showAddMemberDialog(context)),
            ]),
            const SizedBox(height: 24),

            AppTabBar(tabs: const ['Membres', 'Départements'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 20),

            if (_tab == 0) _MembresTab(search: _search, onSearch: (v) => setState(() => _search = v))
            else const _DepartementsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Dialogue Ajouter un membre ────────────────────────────
void _showAddMemberDialog(BuildContext context) {
  final nomCtrl = TextEditingController();
  final roleCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String dept = SampleData.departments.first.nom;
  String statut = 'actif';

  const colors = [AppColors.blue, AppColors.purple, AppColors.emerald, AppColors.orange, AppColors.teal, AppColors.red];

  String initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

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

  Widget field(String label, TextEditingController ctrl, String hint) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.label),
      const SizedBox(height: 6),
      TextField(controller: ctrl, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1), decoration: deco(hint)),
    ]);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Ajouter un membre', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            field('NOM COMPLET *', nomCtrl, 'Ex : Aya Kouassi'),
            const SizedBox(height: 12),
            field('RÔLE *', roleCtrl, 'Ex : Développeur Frontend'),
            const SizedBox(height: 12),
            field('EMAIL', emailCtrl, 'email@klrtech.ci'),
            const SizedBox(height: 12),
            field('TÉLÉPHONE', phoneCtrl, '+225 ...'),
            const SizedBox(height: 12),
            Text('DÉPARTEMENT', style: AppTheme.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: dept,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
              decoration: deco(''),
              dropdownColor: Colors.white,
              items: SampleData.departments.map((d) => DropdownMenuItem(value: d.nom, child: Text(d.nom))).toList(),
              onChanged: (v) => setState(() => dept = v!),
            ),
            const SizedBox(height: 12),
            Text('STATUT', style: AppTheme.label),
            const SizedBox(height: 6),
            Row(children: [
              for (final s in [('actif', 'Actif'), ('mission', 'En mission'), ('conge', 'En congé')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => statut = s.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statut == s.$1 ? AppColors.primary.withOpacity(0.1) : AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statut == s.$1 ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(s.$2, style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: statut == s.$1 ? AppColors.primary : AppColors.text2)),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(
          label: 'Ajouter',
          icon: Icons.add,
          onTap: () {
            final nom = nomCtrl.text.trim();
            final role = roleCtrl.text.trim();
            if (nom.isEmpty || role.isEmpty) return;
            final state = context.read<AppState>();
            state.addEmployee(Employee(
              id: DateTime.now().millisecondsSinceEpoch,
              nom: nom,
              initiales: initialsFor(nom),
              role: role,
              dept: dept,
              statut: statut,
              projets: 0,
              taches: 0,
              perf: 80,
              phone: phoneCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              color: colors[state.employees.length % colors.length],
            ));
            Navigator.of(ctx).pop();
          },
        ),
      ],
    )),
  );
}

// ── Membres Tab ───────────────────────────────────────────
class _MembresTab extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  const _MembresTab({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final employees = context.watch<AppState>().employees.where((e) =>
      search.isEmpty ||
      e.nom.toLowerCase().contains(search.toLowerCase()) ||
      e.role.toLowerCase().contains(search.toLowerCase()) ||
      e.dept.toLowerCase().contains(search.toLowerCase())
    ).toList();

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text('${employees.length} membre${employees.length > 1 ? 's' : ''}', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1)),
            const Spacer(),
            Flexible(child: SearchField(placeholder: 'Rechercher un membre...', onChanged: onSearch, maxWidth: 280)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        HScrollTable(
          minWidth: 980,
          child: Column(children: [
            Container(
              color: AppColors.bg,
              child: const Row(children: [
                Expanded(flex: 4, child: ThCell('MEMBRE')),
                Expanded(flex: 3, child: ThCell('RÔLE')),
                Expanded(flex: 2, child: ThCell('DÉPARTEMENT')),
                Expanded(flex: 2, child: ThCell('STATUT')),
                Expanded(flex: 2, child: ThCell('PROJETS')),
                Expanded(flex: 2, child: ThCell('TÂCHES')),
                Expanded(flex: 2, child: ThCell('PERF.')),
                SizedBox(width: 48),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            ...employees.asMap().entries.map((e) => _EmployeeRow(emp: e.value, isLast: e.key == employees.length - 1)),
          ]),
        ),
        if (employees.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text('Aucun membre trouvé', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
          ),
      ]),
    );
  }
}

class _EmployeeRow extends StatefulWidget {
  final Employee emp;
  final bool isLast;
  const _EmployeeRow({required this.emp, required this.isLast});

  @override
  State<_EmployeeRow> createState() => _EmployeeRowState();
}

class _EmployeeRowState extends State<_EmployeeRow> {
  bool _hovered = false;

  void _showDetails(BuildContext context, Employee e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          AvatarCircle(initials: e.initiales, color: e.color, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.nom, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
            Text(e.role, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          ])),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final item in [
              (Icons.apartment_outlined, 'Département', e.dept),
              (Icons.email_outlined, 'Email', e.email),
              (Icons.phone_outlined, 'Téléphone', e.phone),
              (Icons.folder_outlined, 'Projets en cours', '${e.projets}'),
              (Icons.check_box_outlined, 'Tâches assignées', '${e.taches}'),
              (Icons.speed_outlined, 'Performance', '${e.perf}%'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(item.$1, size: 15, color: AppColors.text3),
                  const SizedBox(width: 10),
                  Text('${item.$2} : ', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3)),
                  Expanded(child: Text(item.$3.isEmpty ? '—' : item.$3,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1))),
                ]),
              ),
            StatusBadge(status: e.statut),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Employee e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Retirer ce membre ?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: Text('« ${e.nom} » sera retiré de l\'équipe.',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteEmployee(e.id);
              Navigator.of(ctx).pop();
            },
            child: Text('Retirer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.emp;
    final perfColor = e.perf >= 90 ? AppColors.green : e.perf >= 80 ? AppColors.blue : AppColors.orange;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFFAFAFB) : AppColors.surface,
          border: widget.isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              AvatarCircle(initials: e.initiales, color: e.color, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nom, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1), overflow: TextOverflow.ellipsis),
                Text(e.email, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3), overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(e.role, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(e.dept, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatusBadge(status: e.statut),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('${e.projets}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('${e.taches}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: perfColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${e.perf}%', style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: perfColor)),
              ),
            ]),
          )),
          SizedBox(width: 48, child: PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
            padding: const EdgeInsets.all(6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: Colors.white,
            onSelected: (action) {
              if (action == 'details') {
                _showDetails(context, e);
              } else if (action == 'delete') {
                _confirmDelete(context, e);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'details', child: Row(children: [
                const Icon(Icons.visibility_outlined, size: 15, color: AppColors.text2),
                const SizedBox(width: 8),
                Text('Voir détails', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
              ])),
              PopupMenuItem(value: 'delete', child: Row(children: [
                const Icon(Icons.person_remove_outlined, size: 15, color: AppColors.red),
                const SizedBox(width: 8),
                Text('Retirer', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
              ])),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Départements Tab ──────────────────────────────────────
class _DepartementsTab extends StatelessWidget {
  const _DepartementsTab();

  @override
  Widget build(BuildContext context) {
    final depts = SampleData.departments;
    return LayoutBuilder(builder: (context, constraints) {
      final cols = (constraints.maxWidth / 320).floor().clamp(1, 3);
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        children: depts.map((d) => _DeptCard(dept: d)).toList(),
      );
    });
  }
}

class _DeptCard extends StatefulWidget {
  final Department dept;
  const _DeptCard({required this.dept});

  @override
  State<_DeptCard> createState() => _DeptCardState();
}

class _DeptCardState extends State<_DeptCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.dept;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hovered ? d.color.withOpacity(0.4) : AppColors.border),
          boxShadow: _hovered ? [BoxShadow(color: d.color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: d.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.group_outlined, size: 18, color: d.color),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: d.bg, borderRadius: BorderRadius.circular(20)),
              child: Text('${d.membres} membre${d.membres > 1 ? 's' : ''}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: d.color)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(d.nom, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const SizedBox(height: 4),
          Text('Chef : ${d.chef}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3)),
          const Spacer(),
          Row(children: [
            const Icon(Icons.folder_outlined, size: 13, color: AppColors.text3),
            const SizedBox(width: 4),
            Text('${d.projets} projet${d.projets > 1 ? 's' : ''}', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text2)),
          ]),
        ]),
      ),
    );
  }
}
