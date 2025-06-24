import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:installed_apps/installed_apps.dart';
import 'update_service.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'dashboard_tab.dart';
import 'sleep_calculator_tab.dart';
import 'updates_tab.dart';
import 'info_tab.dart';
import 'water_tab.dart';

// Enum per la personalizzazione della UI
enum TextSize { small, normal, large }

enum WidgetSize { small, normal, large }

enum ContextualSize { small, normal, large }

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
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _showSplash = false;
      });
    });
  }

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
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: _showSplash
            ? const SplashScreen()
            : MainScreen(
                themeMode: _themeMode,
                onThemeModeChanged: _setThemeMode,
              ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/icon.png', width: 96, height: 96),
              const SizedBox(height: 24),
              Text('SleepTrack',
                  style: FluentTheme.of(context).typography.title),
            ],
          ),
        ),
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
  TextSize _textSize = TextSize.large;
  WidgetSize _widgetSize = WidgetSize.large;
  ContextualSize _contextualSize = ContextualSize.large;

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
      } else if (!isAutomatic) {
        // Feedback: nessun aggiornamento disponibile
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Aggiornamenti'),
            content: const Text('Nessun aggiornamento disponibile.'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Mostra errore se necessario
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Errore'),
          content: Text('Errore durante il controllo aggiornamenti: $e'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
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

  double getGlobalScale() => 1.0;

  double getTextSize() {
    final baseSize = 16.0;
    return baseSize * getGlobalScale();
  }

  double getTitleSize() {
    final baseSize = 24.0;
    return baseSize * getGlobalScale();
  }

  double getButtonTextSize() {
    final baseSize = 16.0;
    return baseSize * getGlobalScale();
  }

  double getIconSize() {
    final baseSize = 24.0;
    return baseSize * getGlobalScale();
  }

  EdgeInsets getButtonPadding() {
    final basePadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final scale = getGlobalScale();
    return EdgeInsets.symmetric(
      horizontal: basePadding.horizontal * scale,
      vertical: basePadding.vertical * scale,
    );
  }

  double getSpacing() => 16.0 * getGlobalScale();

  double getLargeSpacing() => 24.0 * getGlobalScale();

  List<Tab> buildTabs(BuildContext context) {
    bool isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    if (isMobile && isPortrait) {
      // Solo icone
      return [
        Tab(
            text: const SizedBox.shrink(),
            icon: const Icon(FluentIcons.home),
            body: DashboardTab(
              updateResult: _updateResult,
              isDownloading: _isDownloading,
              downloadProgress: _downloadProgress,
              updateStatus: _updateStatus,
              onCheckUpdate: _checkForUpdates,
              onShowVersionInfo: _showVersionInfo,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const SizedBox.shrink(),
            icon: const Icon(FluentIcons.clock),
            body: SleepCalculatorTab(
              selectedTime: _selectedTime,
              showSleepCalculator: _showSleepCalculator,
              onTimeChanged: _onTimeChanged,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const SizedBox.shrink(),
            icon: const Icon(FluentIcons.coffee),
            body: WaterTab(
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const SizedBox.shrink(),
            icon: const Icon(FluentIcons.sync),
            body: UpdatesTab(
              releaseHistory: _releaseHistory,
              onCheckUpdate: _checkForUpdates,
              updateResult: _updateResult,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const SizedBox.shrink(),
            icon: const Icon(FluentIcons.info),
            body: InfoTab(
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              onShowVersionInfo: _showVersionInfo,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
      ];
    } else {
      // Icone + testo
      return [
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
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const Text('Calcolatore Sonno'),
            icon: const Icon(FluentIcons.clock),
            body: SleepCalculatorTab(
              selectedTime: _selectedTime,
              showSleepCalculator: _showSleepCalculator,
              onTimeChanged: _onTimeChanged,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const Text('Acqua'),
            icon: const Icon(FluentIcons.coffee),
            body: WaterTab(
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const Text('Aggiornamenti'),
            icon: const Icon(FluentIcons.sync),
            body: UpdatesTab(
              releaseHistory: _releaseHistory,
              onCheckUpdate: _checkForUpdates,
              updateResult: _updateResult,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
        Tab(
            text: const Text('Info'),
            icon: const Icon(FluentIcons.info),
            body: InfoTab(
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              onShowVersionInfo: _showVersionInfo,
              getTextSize: getTextSize(),
              getTitleSize: getTitleSize(),
              getButtonTextSize: getButtonTextSize(),
              getIconSize: getIconSize(),
              getButtonPadding: getButtonPadding(),
            )),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', width: 32, height: 32),
            const SizedBox(width: 12),
            const Text('SleepTrack'),
          ],
        ),
        leading: _currentIndex != 0
            ? IconButton(
                icon: const Icon(FluentIcons.back),
                onPressed: () => setState(() => _currentIndex = 0),
              )
            : null,
      ),
      content: TabView(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
        tabs: buildTabs(context),
      ),
    );
  }
}
