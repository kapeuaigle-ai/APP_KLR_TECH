import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/models.dart';
import 'core/app_state.dart';
import 'core/persistence.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_header.dart';
import 'widgets/mobile_shell.dart';
import 'widgets/responsive.dart';
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
    // Sous 700 px : barre de navigation basse, pas de sidebar. Le choix se
    // fait sur la largeur, donc la fenêtre de bureau réduite en bénéficie
    // aussi. Voir isPhone dans widgets/responsive.dart.
    if (isPhone(context)) return const _PhoneShell();

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

/// Coquille téléphone. Se charge aussi de quitter un écran devenu
/// inaccessible : si la fenêtre rétrécit alors que Projets est affiché,
/// l'écran n'a plus d'entrée de navigation, donc on revient au tableau de
/// bord. La redirection est différée d'une frame — on ne mute pas l'état
/// pendant un build.
class _PhoneShell extends StatelessWidget {
  const _PhoneShell();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // La création de document est un parcours de saisie, pas une
    // destination : elle prend tout l'écran, sans barre du bas. Son propre
    // en-tête porte déjà le retour, Annuler et Enregistrer.
    if (state.creating || state.screen == NavScreen.documentCreate) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: DocumentCreateScreen()),
      );
    }

    if (isPhoneUnreachable(state.screen)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isPhoneUnreachable(state.screen)) state.navigate(NavScreen.dashboard);
      });
      return const MobileShell(child: SizedBox.shrink());
    }

    return const MobileShell(child: _ContentArea());
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
