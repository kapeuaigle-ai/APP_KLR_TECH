import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<AppState>().clients;
    final filtered = clients.where((c) =>
      _search.isEmpty ||
      c.name.toLowerCase().contains(_search.toLowerCase()) ||
      c.contact.toLowerCase().contains(_search.toLowerCase()) ||
      c.email.toLowerCase().contains(_search.toLowerCase())
    ).toList();

    final totalCA = clients.fold<double>(0, (s, c) => s + c.totalFacture);
    final actifs = clients.where((c) => c.status == 'actif').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clients', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Gérez votre portefeuille clients et leur historique.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              PrimaryBtn(label: '+ Nouveau client', icon: Icons.add, onTap: () {}),
            ]),
            const SizedBox(height: 24),

            // Stat cards
            Row(children: [
              Expanded(child: StatCard(label: 'TOTAL CLIENTS', value: '${clients.length}', sub: 'Entreprises partenaires')),
              const SizedBox(width: 16),
              Expanded(child: StatCard(label: 'CLIENTS ACTIFS', value: '$actifs',
                badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
                  child: Text('${((actifs / clients.length) * 100).round()}%', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green))))),
              const SizedBox(width: 16),
              Expanded(child: StatCard(label: 'CA CUMULÉ', value: Fmt.millions(totalCA), unit: 'FCFA')),
            ]),
            const SizedBox(height: 20),

            // Table
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text('${filtered.length} client${filtered.length > 1 ? 's' : ''}', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1)),
                    const Spacer(),
                    SearchField(placeholder: 'Rechercher un client...', onChanged: (v) => setState(() => _search = v), maxWidth: 280),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
                Container(
                  color: AppColors.bg,
                  child: const Row(children: [
                    Expanded(flex: 4, child: ThCell('CLIENT')),
                    Expanded(flex: 3, child: ThCell('CONTACT')),
                    Expanded(flex: 4, child: ThCell('EMAIL')),
                    Expanded(flex: 3, child: ThCell('TÉLÉPHONE')),
                    Expanded(flex: 3, child: ThCell('CA TOTAL')),
                    Expanded(flex: 2, child: ThCell('STATUT')),
                    SizedBox(width: 48),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
                ...filtered.asMap().entries.map((e) => _ClientRow(client: e.value, isLast: e.key == filtered.length - 1)),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('Aucun client trouvé', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientRow extends StatefulWidget {
  final Client client;
  final bool isLast;
  const _ClientRow({required this.client, required this.isLast});

  @override
  State<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends State<_ClientRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
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
              AvatarCircle(initials: c.initials, color: c.color, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(c.name, style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text1), overflow: TextOverflow.ellipsis)),
            ]),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(c.contact, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(c.email, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(c.phone, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(c.totalFacture > 0 ? Fmt.money(c.totalFacture) : '—', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatusBadge(status: c.status),
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
