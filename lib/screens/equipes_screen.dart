import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/data.dart';
import '../widgets/common.dart';

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
              PrimaryBtn(label: '+ Ajouter membre', icon: Icons.add, onTap: () {}),
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

// ── Membres Tab ───────────────────────────────────────────
class _MembresTab extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  const _MembresTab({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final employees = SampleData.employees.where((e) =>
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
            SearchField(placeholder: 'Rechercher un membre...', onChanged: onSearch, maxWidth: 280),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
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
          SizedBox(width: 48, child: IconButton(
            icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
            onPressed: () {},
            padding: const EdgeInsets.all(6),
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
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: depts.map((d) => _DeptCard(dept: d)).toList(),
    );
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
