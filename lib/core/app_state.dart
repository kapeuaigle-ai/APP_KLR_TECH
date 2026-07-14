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
  }

  NavScreen get screen => _screen;
  String get docType => _docType;
  bool get creating => _creating;
  bool get isMonoUser => settings.monoUser;

  void setMonoUser(bool v) {
    settings.monoUser = v;
    // If switching to mono-user and currently on Équipes screen, redirect to dashboard
    if (v && _screen == NavScreen.equipes) {
      _screen = NavScreen.dashboard;
    }
    notifyListeners();
  }

  void navigate(NavScreen s) {
    _screen = s;
    _creating = false;
    notifyListeners();
  }

  void setDocType(String t) { _docType = t; notifyListeners(); }
  void setCreating(bool v) { _creating = v; notifyListeners(); }

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

  void saveNote(Note n) {
    final idx = notes.indexWhere((x) => x.id == n.id);
    if (idx >= 0) notes[idx] = n; else notes.add(n);
    notifyListeners();
  }

  void deleteNote(int id) {
    notes.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  void updateSettings(AppSettings s) {
    settings = s;
    notifyListeners();
  }

  void addDocument(String type, DocumentItem doc) {
    documents[type]?.add(doc);
    notifyListeners();
  }
}
