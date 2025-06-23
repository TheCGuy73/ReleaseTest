import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:installed_apps/installed_apps.dart';
import 'update_service.dart';
import 'package:android_intent_plus/android_intent.dart';

void main() {
  // Assicura che i binding di Flutter siano inizializzati prima di eseguire l'app.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'SleepTrack',
      themeMode: _themeMode,
      theme: FluentThemeData(
        brightness: Brightness.light,
        accentColor: AccentColor.swatch({
          'normal': material.Colors.blue.shade500,
          'dark': material.Colors.blue.shade700,
          'light': material.Colors.blue.shade200,
        }),
      ),
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: AccentColor.swatch({
          'normal': material.Colors.blue.shade500,
          'dark': material.Colors.blue.shade700,
          'light': material.Colors.blue.shade200,
        }),
      ),
      home: MainScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MainScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final UpdateService _updateService;
  UpdateResult? _updateResult;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _updateStatus = '';
  material.TimeOfDay? _selectedTime;
  Map<String, dynamic>? _pendingUpdateRelease;
  bool _showSleepCalculator = false;
  List<Map<String, dynamic>> _releaseHistory = [];

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService(
      githubOwner: 'TheCGuy73',
      githubRepo: 'ReleaseTest',
    );
    WidgetsBinding.instance.addObserver(this);
    _fetchReleaseHistory();
    _checkForUpdates(isAutomatic: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _pendingUpdateRelease != null) {
      // L'utente è tornato all'app, controlla se ha concesso il permesso.
      _resumeUpdateAfterPermissionRequest();
    }
  }

  Future<void> _resumeUpdateAfterPermissionRequest() async {
    if (await Permission.requestInstallPackages.isGranted) {
      final releaseToInstall = _pendingUpdateRelease!;
      setState(() {
        _pendingUpdateRelease = null;
      });
      _downloadAndInstallUpdate(releaseToInstall);
    }
  }

  Future<void> _fetchReleaseHistory() async {
    try {
      final releases = await _updateService.fetchAllReleases();
      setState(() {
        _releaseHistory = releases;
      });
    } catch (_) {}
  }

  Future<void> _checkForUpdates({bool isAutomatic = false}) async {
    try {
      final result = await _updateService.checkForUpdates();
      setState(() {
        _updateResult = result;
      });
      if (result.isUpdateAvailable && !isAutomatic) {
        _showUpdateAvailableDialog(result.release!);
      }
    } catch (_) {}
  }

  void _showUpdateAvailableDialog(Map<String, dynamic> release) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    material.showDialog(
      context: context,
      builder: (context) => material.AlertDialog(
        title: const Text('Aggiornamento Disponibile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versione attuale: $currentVersion'),
            const SizedBox(height: 8),
            Text('Nuova versione: ${release['tag_name']}'),
          ],
        ),
        actions: [
          material.TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dopo'),
          ),
          material.ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initiateUpdateProcess(release);
            },
            child: const Text('Scarica e Installa'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateUpdateProcess(Map<String, dynamic> release) async {
    bool hasPermission = await Permission.requestInstallPackages.isGranted;
    if (hasPermission) {
      _downloadAndInstallUpdate(release);
    } else {
      setState(() {
        _pendingUpdateRelease = release;
      });
      final result = await material.showDialog<bool>(
        context: context,
        builder: (context) => material.AlertDialog(
          title: const Text('Permesso Richiesto'),
          content: const Text(
            'Per aggiornare l\'app, è necessario autorizzare l\'installazione. Verrai reindirizzato alle impostazioni per concedere il permesso.',
          ),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            material.ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Vai alle Impostazioni'),
            ),
          ],
        ),
      );
      if (result == true) {
        await openAppSettings();
      } else {
        setState(() {
          _pendingUpdateRelease = null;
        });
      }
    }
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> release) async {
    setState(() {
      _isDownloading = true;
      _updateStatus = 'Download in corso...';
      _downloadProgress = 0.0;
    });
    try {
      await _updateService.downloadAndInstallUpdate(release, (progress) {
        setState(() {
          _downloadProgress = progress;
          _updateStatus =
              'Download: \\${(_downloadProgress * 100).toStringAsFixed(1)}%';
        });
      });
      _updateStatus = 'Download completato. Avvio installazione...';
    } catch (e) {
      _updateStatus = 'Errore durante il download: \\${e.toString()}';
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.appName;
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Informazioni su $appName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versione: $version'),
            Text('Build: $buildNumber'),
          ],
        ),
        actions: [
          Button(
            child: const Text('Chiudi'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onTimeChanged(material.TimeOfDay newTime) {
    setState(() {
      _selectedTime = newTime;
      _showSleepCalculator = true;
    });
  }

  List<Widget> get _tabs => [
        DashboardTab(
          updateResult: _updateResult,
          isDownloading: _isDownloading,
          downloadProgress: _downloadProgress,
          updateStatus: _updateStatus,
          onCheckUpdate: _checkForUpdates,
          onShowVersionInfo: _showVersionInfo,
        ),
        SleepCalculatorTab(
          selectedTime: _selectedTime,
          showSleepCalculator: _showSleepCalculator,
          onTimeChanged: _onTimeChanged,
        ),
        UpdatesTab(
          releaseHistory: _releaseHistory,
          onCheckUpdate: _checkForUpdates,
          updateResult: _updateResult,
        ),
        InfoTab(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          onShowVersionInfo: _showVersionInfo,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: const Text('SleepTrack'),
        actions: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.info),
              onPressed: _showVersionInfo,
            ),
          ],
        ),
      ),
      content: TabView(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
        tabs: [
          Tab(
            text: const Text('Dashboard'),
            icon: const Icon(FluentIcons.home),
            body: DashboardTab(
              updateResult: _updateResult,
              isDownloading: _isDownloading,
              downloadProgress: _downloadProgress,
              updateStatus: _updateStatus,
              onCheckUpdate: _checkForUpdates,
              onShowVersionInfo: _showVersionInfo,
            ),
          ),
          Tab(
            text: const Text('Calcolatore Sonno'),
            icon: const Icon(FluentIcons.clock),
            body: SleepCalculatorTab(
              selectedTime: _selectedTime,
              showSleepCalculator: _showSleepCalculator,
              onTimeChanged: _onTimeChanged,
            ),
          ),
          Tab(
            text: const Text('Aggiornamenti'),
            icon: const Icon(FluentIcons.sync),
            body: UpdatesTab(
              releaseHistory: _releaseHistory,
              onCheckUpdate: _checkForUpdates,
              updateResult: _updateResult,
            ),
          ),
          Tab(
            text: const Text('Info'),
            icon: const Icon(FluentIcons.info),
            body: InfoTab(
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              onShowVersionInfo: _showVersionInfo,
            ),
          ),
        ],
      ),
    );
  }
}

// --- TABS ---

class DashboardTab extends StatelessWidget {
  final UpdateResult? updateResult;
  final bool isDownloading;
  final double downloadProgress;
  final String updateStatus;
  final VoidCallback onCheckUpdate;
  final VoidCallback onShowVersionInfo;
  const DashboardTab({
    super.key,
    required this.updateResult,
    required this.isDownloading,
    required this.downloadProgress,
    required this.updateStatus,
    required this.onCheckUpdate,
    required this.onShowVersionInfo,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Benvenuto in SleepTrack!',
              style: FluentTheme.of(context).typography.title),
          const SizedBox(height: 16),
          InfoBar(
            title: Text(updateResult?.isUpdateAvailable == true
                ? 'Aggiornamento disponibile!'
                : 'App aggiornata'),
            severity: updateResult?.isUpdateAvailable == true
                ? InfoBarSeverity.warning
                : InfoBarSeverity.success,
            action: updateResult?.isUpdateAvailable == true
                ? Button(
                    child: const Text('Aggiorna'), onPressed: onCheckUpdate)
                : null,
          ),
          if (isDownloading) ...[
            const SizedBox(height: 16),
            ProgressBar(value: downloadProgress > 0 ? downloadProgress : null),
            const SizedBox(height: 8),
            Text(updateStatus),
          ],
          const SizedBox(height: 24),
          Button(
              child: const Text('Controlla Aggiornamenti'),
              onPressed: onCheckUpdate),
          const SizedBox(height: 8),
          Button(child: const Text('Info App'), onPressed: onShowVersionInfo),
        ],
      ),
    );
  }
}

class SleepCalculatorTab extends StatelessWidget {
  final material.TimeOfDay? selectedTime;
  final bool showSleepCalculator;
  final ValueChanged<material.TimeOfDay> onTimeChanged;
  const SleepCalculatorTab(
      {super.key,
      required this.selectedTime,
      required this.showSleepCalculator,
      required this.onTimeChanged});
  @override
  Widget build(BuildContext context) {
    // Qui puoi incollare la UI del calcolatore sonno già pronta, adattata a Fluent UI
    return Center(child: Text('Calcolatore Sonno qui!'));
  }
}

class UpdatesTab extends StatelessWidget {
  final List<Map<String, dynamic>> releaseHistory;
  final VoidCallback onCheckUpdate;
  final UpdateResult? updateResult;
  const UpdatesTab(
      {super.key,
      required this.releaseHistory,
      required this.onCheckUpdate,
      required this.updateResult});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Storico Aggiornamenti',
              style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: releaseHistory.length,
              itemBuilder: (context, index) {
                final rel = releaseHistory[index];
                return InfoBar(
                  title: Text(rel['tag_name'] ?? ''),
                  content: Text(rel['name'] ?? ''),
                  severity: InfoBarSeverity.info,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Button(
              child: const Text('Controlla Aggiornamenti'),
              onPressed: onCheckUpdate),
        ],
      ),
    );
  }
}

class InfoTab extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onShowVersionInfo;
  const InfoTab(
      {super.key,
      required this.themeMode,
      required this.onThemeModeChanged,
      required this.onShowVersionInfo});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Impostazioni',
              style: FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 16),
          Text('Tema:'),
          const SizedBox(height: 8),
          Row(
            children: [
              RadioButton(
                checked: themeMode == ThemeMode.system,
                onChanged: (_) => onThemeModeChanged(ThemeMode.system),
                content: const Text('Sistema'),
              ),
              RadioButton(
                checked: themeMode == ThemeMode.light,
                onChanged: (_) => onThemeModeChanged(ThemeMode.light),
                content: const Text('Chiaro'),
              ),
              RadioButton(
                checked: themeMode == ThemeMode.dark,
                onChanged: (_) => onThemeModeChanged(ThemeMode.dark),
                content: const Text('Scuro'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Button(child: const Text('Info App'), onPressed: onShowVersionInfo),
        ],
      ),
    );
  }
}
