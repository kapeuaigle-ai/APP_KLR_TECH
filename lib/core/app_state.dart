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
  late List<Employee> employees;
  late List<FactureEntry> factures;

  AppState() {
    clients = List.from(SampleData.clients);
    documents = {
      'proforma': List.from(SampleData.documents['proforma']!),
      'facture': List.from(SampleData.documents['facture']!),
      'bl': List.from(SampleData.documents['bl']!),
    };
    settings = AppSettings(
      company: 'KLR TECH S.A.R.L',
      rc: '22000038',
      ifNum: '12883445',
      address: 'Cocody Riviera 2, Abidjan, Côte d\'Ivoire',
      ice: '001552883000045',
      prefix: 'KLR',
      startNum: '001',
      tva: 5,
      conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
    );
    tasks = SampleData.initialTasks;
    notes = SampleData.initialNotes;
    employees = List.from(SampleData.employees);
    factures = List.from(SampleData.factureHistory);
  }

  NavScreen get screen => _screen;
  String get docType => _docType;
  bool get creating => _creating;

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

  // ── Employés ───────────────────────────────────────────
  void addEmployee(Employee e) {
    employees.add(e);
    notifyListeners();
  }

  void deleteEmployee(int id) {
    employees.removeWhere((x) => x.id == id);
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
}
