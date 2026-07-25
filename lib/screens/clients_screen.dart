import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

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

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Clients',
              subtitle: 'Gérez votre portefeuille clients et leur historique.',
              actions: [
                PrimaryBtn(label: 'Nouveau client', icon: Icons.add, onTap: () => showClientDialog(context)),
              ],
            ),
            const SizedBox(height: 24),

            // Stat cards
            StatGrid(cards: [
              StatCard(label: 'TOTAL CLIENTS', value: '${clients.length}', sub: 'Entreprises partenaires'),
              StatCard(label: 'CA CUMULÉ', value: Fmt.number(totalCA), unit: 'FCFA'),
              StatCard(label: 'CA MOY./CLIENT',
                value: Fmt.number(clients.isEmpty ? 0 : totalCA / clients.length), unit: 'FCFA'),
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
                    Flexible(child: SearchField(placeholder: 'Rechercher un client...', onChanged: (v) => setState(() => _search = v), maxWidth: 280)),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
                HScrollTable(
                  minWidth: 1020,
                  child: Column(children: [
                    Container(
                      color: AppColors.bg,
                      child: const Row(children: [
                        Expanded(flex: 4, child: ThCell('CLIENT')),
                        Expanded(flex: 3, child: ThCell('CONTACT')),
                        Expanded(flex: 4, child: ThCell('EMAIL')),
                        Expanded(flex: 3, child: ThCell('TÉLÉPHONE')),
                        Expanded(flex: 3, child: ThCell('CA TOTAL')),
                        SizedBox(width: 48),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    ...filtered.asMap().entries.map((e) => _ClientRow(client: e.value, isLast: e.key == filtered.length - 1)),
                  ]),
                ),
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

// ── Dialogue Ajouter / Modifier un client ─────────────────
void showClientDialog(BuildContext context, {Client? existing}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final contactCtrl = TextEditingController(text: existing?.contact ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final addressCtrl = TextEditingController(text: existing?.address ?? '');

  const colors = [AppColors.purple, AppColors.blue, AppColors.emerald, AppColors.orange, AppColors.red, AppColors.teal];

  String initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(existing == null ? 'Nouveau client' : 'Modifier le client',
          style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
      content: SizedBox(
        width: dialogWidth(ctx, 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _DialogField(label: 'NOM DE L\'ENTREPRISE *', ctrl: nameCtrl, hint: 'Ex : Acme Corp'),
            const SizedBox(height: 12),
            _DialogField(label: 'CONTACT', ctrl: contactCtrl, hint: 'Nom du contact'),
            const SizedBox(height: 12),
            _DialogField(label: 'EMAIL', ctrl: emailCtrl, hint: 'email@exemple.com'),
            const SizedBox(height: 12),
            _DialogField(label: 'TÉLÉPHONE', ctrl: phoneCtrl, hint: '+225 ...'),
            const SizedBox(height: 12),
            _DialogField(label: 'ADRESSE', ctrl: addressCtrl, hint: 'Adresse complète', maxLines: 2),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        ),
        PrimaryBtn(
          label: existing == null ? 'Ajouter' : 'Enregistrer',
          icon: existing == null ? Icons.add : Icons.save_outlined,
          onTap: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            final state = context.read<AppState>();
            final client = Client(
              id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
              initials: initialsFor(name),
              color: existing?.color ?? colors[state.clients.length % colors.length],
              name: name,
              contact: contactCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              totalFacture: existing?.totalFacture ?? 0,
              address: addressCtrl.text.trim(),
            );
            if (existing == null) {
              state.addClient(client);
            } else {
              state.updateClient(client);
            }
            Navigator.of(ctx).pop();
          },
        ),
      ],
    )),
  );
}

class _DialogField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final int maxLines;
  const _DialogField({required this.label, required this.ctrl, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.label),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
          filled: true, fillColor: AppColors.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    ]);
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

  void _confirmDelete(BuildContext context, Client c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer le client ?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: Text('« ${c.name} » sera retiré de votre portefeuille. Cette action est irréversible.',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteClient(c.id);
              Navigator.of(ctx).pop();
            },
            child: Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }

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
            child: Text(c.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(c.totalFacture > 0 ? Fmt.money(c.totalFacture) : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          SizedBox(width: 48, child: PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
            padding: const EdgeInsets.all(6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: Colors.white,
            onSelected: (action) {
              if (action == 'edit') {
                showClientDialog(context, existing: c);
              } else if (action == 'delete') {
                _confirmDelete(context, c);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'edit', child: Row(children: [
                const Icon(Icons.edit_outlined, size: 15, color: AppColors.text2),
                const SizedBox(width: 8),
                Text('Modifier', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
              ])),
              PopupMenuItem(value: 'delete', child: Row(children: [
                const Icon(Icons.delete_outline, size: 15, color: AppColors.red),
                const SizedBox(width: 8),
                Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.red)),
              ])),
            ],
          )),
        ]),
      ),
    );
  }
}
