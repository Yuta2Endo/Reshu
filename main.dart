import 'package:flutter/material.dart';

import 'app_state.dart';
import 'notifier.dart';
import 'pages/news_page.dart';
import 'pages/settings_page.dart';
import 'pages/timetable_page.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initTimezone();
  await Notifier.init();
  final state = await AppState.load();
  runApp(App(state));
  state.refreshTimetable();
  state.refreshNews();
}

class App extends StatelessWidget {
  const App(this.state, {super.key});
  final AppState state;

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Color(state.seed),
        brightness: b,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'СибГУ Планер',
        debugShowCheckedModeBanner: false,
        themeMode: state.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: Shell(state),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell(this.state, {super.key});
  final AppState state;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: [
        TimetablePage(widget.state),
        NewsPage(widget.state),
        SettingsPage(widget.state),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Расписание'),
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Новости'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Настройки'),
        ],
      ),
    );
  }
}
