import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class GanttScreen extends StatelessWidget {
  const GanttScreen({super.key});

  static const _months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin'];
  static final _projects = [
    _GanttProject(name: 'Dashboard Analytics v2', color: AppColors.primary, start: 0, duration: 2, progress: 100, assignees: ['AB', 'AK']),
    _GanttProject(name: 'API OAuth2 Connecteurs', color: AppColors.blue, start: 1, duration: 3, progress: 67, assignees: ['AB', 'KL']),
    _GanttProject(name: 'Charte graphique 2026', color: AppColors.orange, start: 0, duration: 3, progress: 100, assignees: ['AK']),
    _GanttProject(name: 'Migration cloud AWS', color: AppColors.teal, start: 2, duration: 4, progress: 25, assignees: ['JT']),
    _GanttProject(name: 'Module CRM clients', color: AppColors.purple, start: 3, duration: 3, progress: 0, assignees: ['AB', 'JT']),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Gantt',
              subtitle: 'Vue chronologique des projets sur 6 mois.',
              actions: [
                // Le Kanban n'existe pas sur téléphone : proposer le bouton
                // enverrait vers un écran dont la coquille ressort aussitôt.
                if (!isPhone(context))
                  SecondaryBtn(label: 'Kanban', icon: Icons.view_kanban_outlined,
                      onTap: () => context.read<AppState>().navigate(NavScreen.projets)),
              ],
            ),
            const SizedBox(height: 24),

            CardBox(
              padding: const EdgeInsets.all(20),
              child: HScrollTable(
                minWidth: 700,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Month headers
                  Row(children: [
                    const SizedBox(width: 200),
                    ...List.generate(_months.length, (i) => Expanded(
                      child: Text(_months[i], style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text3), textAlign: TextAlign.center),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),

                  // Project rows
                  ..._projects.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _GanttRow(project: p, totalMonths: _months.length),
                  )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GanttProject {
  final String name;
  final Color color;
  final int start, duration, progress;
  final List<String> assignees;
  const _GanttProject({required this.name, required this.color, required this.start, required this.duration, required this.progress, required this.assignees});
}

class _GanttRow extends StatelessWidget {
  final _GanttProject project;
  final int totalMonths;
  const _GanttRow({required this.project, required this.totalMonths});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 200, child: Row(children: [
        Expanded(child: Text(project.name, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text1), overflow: TextOverflow.ellipsis)),
      ])),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final unitW = constraints.maxWidth / totalMonths;
        final barLeft = project.start * unitW;
        final barWidth = project.duration * unitW - 4;
        final progressWidth = barWidth * (project.progress / 100);

        return SizedBox(height: 32, child: Stack(children: [
          // Background grid
          ...List.generate(totalMonths, (i) => Positioned(
            left: i * unitW,
            top: 0, bottom: 0, width: 1,
            child: Container(color: AppColors.border),
          )),

          // Bar background
          Positioned(
            left: barLeft + 2, top: 6,
            width: barWidth, height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: project.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // Progress fill
          Positioned(
            left: barLeft + 2, top: 6,
            width: max(progressWidth, project.progress > 0 ? 12 : 0), height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: project.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // Progress text
          Positioned(
            left: barLeft + 2, top: 6,
            width: barWidth, height: 20,
            child: Center(child: Text(
              project.progress > 0 ? '${project.progress}%' : '',
              style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
            )),
          ),
        ]));
      })),
    ]);
  }
}
