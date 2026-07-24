import 'package:flutter/material.dart';
import 'models.dart';
import 'data.dart';

class AppState extends ChangeNotifier {
  NavScreen _screen = NavScreen.dashboard;
  String _docType = 'proforma';
  bool _creating = false;

  late List<Client> clients;
  late Map<String, List<DocumentItem>> documents;
  late AppSettings settings;
  late List<Task> tasks;
  late List<Note> notes;
  late List<FactureEntry> factures;
  late List<Expense> expenses;
  final Set<String> _dimePaidMonths = {};
  final Map<String, String> _dimePaidDates = {};

  AppState() {
    clients = List.from(SampleData.clients);
    documents = {
      'proforma': List.from(SampleData.documents['proforma']!),
      'facture': List.from(SampleData.documents['facture']!),
      'bl': List.from(SampleData.documents['bl']!),
    };
    settings = AppSettings(
      company: 'KLR TECH SARL',
      address: 'Abidjan Riviera 2 Lot 128 ilot 307',
      bp: '28 BP 994 Abidjan 28',
      rccm: 'CI-ABJ-03-2021-B1308160',
      regime: 'TEE',
      tel: '0708714557',
      email: 'klr.tech8@gmail.com',
      prefix: 'KLR',
      startNum: '01',
      tva: 5,
      conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
    );
    tasks = SampleData.initialTasks;
    notes = SampleData.initialNotes;
    factures = List.from(SampleData.factureHistory);
    expenses = List.from(SampleData.initialExpenses);
  }

  NavScreen get screen => _screen;
  String get docType => _docType;
  bool get creating => _creating;
  Set<String> get dimePaidMonths => _dimePaidMonths;
  Map<String, String> get dimePaidDates => _dimePaidDates;

  void navigate(NavScreen s) {
    _screen = s;
    _creating = false;
    notifyListeners();
  }

  void setDocType(String t) { _docType = t; notifyListeners(); }
  void setCreating(bool v) { _creating = v; notifyListeners(); }

  // ── Clients ────────────────────────────────────────────
  void addClient(Client c) {
    clients.add(c);
    notifyListeners();
  }

  void updateClient(Client c) {
    final idx = clients.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      clients[idx] = c;
      notifyListeners();
    }
  }

  void deleteClient(int id) {
    clients.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // ── Factures (suivi) ───────────────────────────────────
  void markFacturePaid(String num) {
    final f = factures.where((x) => x.num == num);
    if (f.isNotEmpty) {
      f.first.statut = 'paye';
      notifyListeners();
    }
  }

  // ── Tâches ─────────────────────────────────────────────
  void toggleTask(int id) {
    final t = tasks.firstWhere((x) => x.id == id);
    t.done = !t.done;
    notifyListeners();
  }

  void deleteTask(int id) {
    tasks.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  void addTask(Task t) {
    tasks.add(t);
    notifyListeners();
  }

  // ── Notes ──────────────────────────────────────────────
  void saveNote(Note n) {
    final idx = notes.indexWhere((x) => x.id == n.id);
    if (idx >= 0) notes[idx] = n; else notes.add(n);
    notifyListeners();
  }

  void deleteNote(int id) {
    notes.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // ── Paramètres ─────────────────────────────────────────
  void updateSettings(AppSettings s) {
    settings = s;
    notifyListeners();
  }

  // ── Documents ──────────────────────────────────────────
  void addDocument(String type, DocumentItem doc) {
    documents[type]?.add(doc);
    notifyListeners();
  }

  void setDocumentStatus(String type, int id, String statut) {
    final doc = documents[type]?.where((d) => d.id == id);
    if (doc != null && doc.isNotEmpty) {
      doc.first.statut = statut;
      notifyListeners();
    }
  }

  /// Valide une proforma : elle devient une offre acceptée, et la facture
  /// et le bon de livraison associés sont générés automatiquement avec le
  /// même numéro et les mêmes informations. Retourne true si la facture et
  /// le BL ont été créés (false s'ils existaient déjà).
  bool validateProforma(int id) {
    final matches = documents['proforma']!.where((d) => d.id == id);
    if (matches.isEmpty) return false;
    final p = matches.first;
    p.statut = 'validee';

    final alreadyGenerated =
        documents['facture']!.any((d) => d.numero == p.numero);
    if (!alreadyGenerated) {
      final now = DateTime.now().millisecondsSinceEpoch;
      documents['facture']!.add(DocumentItem(
        id: now, numero: p.numero, date: p.date,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: p.montant, statut: 'cours',
        lines: p.lines,
      ));
      // Le BL ne porte aucun montant.
      documents['bl']!.add(DocumentItem(
        id: now + 1, numero: p.numero, date: p.date,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: 0, statut: 'cours',
        lines: p.lines,
      ));
    }
    notifyListeners();
    return !alreadyGenerated;
  }

  // ── Comptabilité : dépenses ────────────────────────────
  void addExpense(Expense e) {
    expenses.add(e);
    notifyListeners();
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── Comptabilité : encaissement des factures ───────────
  void setFactureEncaissee(int id, bool encaissee, {String? date}) {
    final f = documents['facture']?.where((d) => d.id == id);
    if (f != null && f.isNotEmpty) {
      f.first.encaissee = encaissee;
      f.first.dateEncaissement = encaissee ? date : null;
      notifyListeners();
    }
  }

  // ── Comptabilité : versement de la dîme ────────────────
  void setDimePaid(String monthKey, bool paid, {String? date}) {
    if (paid) {
      _dimePaidMonths.add(monthKey);
      if (date != null) _dimePaidDates[monthKey] = date;
    } else {
      _dimePaidMonths.remove(monthKey);
      _dimePaidDates.remove(monthKey);
    }
    notifyListeners();
  }
}
