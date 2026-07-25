import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/models.dart';
import 'core/app_state.dart';
import 'core/persistence.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_header.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/documents_list_screen.dart';
import 'screens/document_create_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/projets_screen.dart';
import 'screens/gantt_screen.dart';
import 'screens/suivi_screen.dart';
import 'screens/activites_screen.dart';
import 'screens/rapports_screen.dart';
import 'screens/parametres_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  // Charge la sauvegarde disque avant d'afficher l'UI (fichier local, OS).
  final state = AppState(store: defaultStore());
  await state.init();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const KlrTechApp(),
    ),
  );
}

class KlrTechApp extends StatelessWidget {
  const KlrTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KLR TECH – Gestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Porte d'entrée : tant que le manager n'est pas connecté, l'app n'est
      // pas montée. La connexion est redemandée à chaque démarrage.
      home: Consumer<AppState>(
        builder: (context, state, _) =>
            state.authenticated ? const AppShell() : const LoginScreen(),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(builder: (context, constraints) {
        // Sidebar compacte (icônes seules) sur écran étroit
        final compact = constraints.maxWidth < 900;
        return Row(
          children: [
            Sidebar(compact: compact),
            Expanded(
              child: Column(
                children: [
                  const AppHeader(),
                  const Expanded(child: _ContentArea()),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Document create overlay
    if (state.creating) {
      return const DocumentCreateScreen();
    }

    return switch (state.screen) {
      NavScreen.dashboard      => const DashboardScreen(),
      NavScreen.documents      => const DocumentsListScreen(),
      NavScreen.clients        => const ClientsScreen(),
      NavScreen.projets        => const ProjetsScreen(),
      NavScreen.gantt          => const GanttScreen(),
      NavScreen.suivi          => const SuiviScreen(),
      NavScreen.activites      => const ActivitesScreen(),
      NavScreen.rapports       => const RapportsScreen(),
      NavScreen.parametres     => const ParametresScreen(),
      NavScreen.documentCreate => const DocumentCreateScreen(),
    };
  }
}
