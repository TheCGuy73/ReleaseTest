import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:installed_apps/installed_apps.dart';
import 'update_service.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

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

  double getContextualScale() {
    switch (_contextualSize) {
      case ContextualSize.small:
        return 0.8;
      case ContextualSize.normal:
        return 1.0;
      case ContextualSize.large:
        return 1.3;
    }
  }

  double getTextSize() {
    final baseSize = switch (_textSize) {
      TextSize.small => 14.0,
      TextSize.normal => 18.0,
      TextSize.large => 24.0,
    };
    return baseSize * getContextualScale();
  }

  double getTitleSize() {
    final baseSize = switch (_textSize) {
      TextSize.small => 20.0,
      TextSize.normal => 26.0,
      TextSize.large => 32.0,
    };
    return baseSize * getContextualScale();
  }

  double getButtonTextSize() {
    final baseSize = switch (_textSize) {
      TextSize.small => 14.0,
      TextSize.normal => 18.0,
      TextSize.large => 22.0,
    };
    return baseSize * getContextualScale();
  }

  double getIconSize() {
    final baseSize = switch (_widgetSize) {
      WidgetSize.small => 18.0,
      WidgetSize.normal => 28.0,
      WidgetSize.large => 36.0,
    };
    return baseSize * getContextualScale();
  }

  EdgeInsets getButtonPadding() {
    final basePadding = switch (_widgetSize) {
      WidgetSize.small =>
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      WidgetSize.normal =>
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      WidgetSize.large =>
        const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    };
    final scale = getContextualScale();
    return EdgeInsets.symmetric(
      horizontal: basePadding.horizontal * scale,
      vertical: basePadding.vertical * scale,
    );
  }

  double getSpacing() {
    return 16.0 * getContextualScale();
  }

  double getLargeSpacing() {
    return 32.0 * getContextualScale();
  }

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
        title: const Text('SleepTrack'),
      ),
      content: TabView(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
        tabs: buildTabs(context),
      ),
    );
  }
}

// --- TABS ---

class DashboardTab extends StatefulWidget {
  final UpdateResult? updateResult;
  final bool isDownloading;
  final double downloadProgress;
  final String updateStatus;
  final VoidCallback onCheckUpdate;
  final VoidCallback onShowVersionInfo;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const DashboardTab({
    super.key,
    required this.updateResult,
    required this.isDownloading,
    required this.downloadProgress,
    required this.updateStatus,
    required this.onCheckUpdate,
    required this.onShowVersionInfo,
    required this.getTextSize,
    required this.getTitleSize,
    required this.getButtonTextSize,
    required this.getIconSize,
    required this.getButtonPadding,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _displayedText = '';
  final String _fullText = 'Benvenuto in SleepTrack!';
  int _charIndex = 0;
  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  void _startTypewriter() async {
    while (_charIndex < _fullText.length) {
      await Future.delayed(const Duration(milliseconds: 45));
      setState(() {
        _displayedText = _fullText.substring(0, _charIndex + 1);
        _charIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 700),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  widget.updateResult?.isUpdateAvailable == true
                      ? 'Aggiornamento disponibile!'
                      : 'App aggiornata',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 32),
              InfoBar(
                title: Text(
                  widget.updateResult?.isUpdateAvailable == true
                      ? 'Aggiornamento disponibile!'
                      : 'App aggiornata',
                  style: const TextStyle(fontSize: 22),
                ),
                severity: widget.updateResult?.isUpdateAvailable == true
                    ? InfoBarSeverity.warning
                    : InfoBarSeverity.success,
                action: widget.updateResult?.isUpdateAvailable == true
                    ? Button(
                        child: Text('Aggiorna',
                            style:
                                TextStyle(fontSize: widget.getButtonTextSize)),
                        onPressed: widget.onCheckUpdate,
                        style: ButtonStyle(
                            padding: ButtonState.all(widget.getButtonPadding)),
                      )
                    : null,
              ),
              if (widget.isDownloading) ...[
                const SizedBox(height: 24),
                ProgressBar(
                  value: widget.downloadProgress > 0
                      ? widget.downloadProgress
                      : null,
                ),
                const SizedBox(height: 16),
                Text(widget.updateStatus,
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
              ],
              const SizedBox(height: 32),
              Button(
                child: Text('Controlla Aggiornamenti',
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
                onPressed: widget.onCheckUpdate,
                style: ButtonStyle(
                    padding: ButtonState.all(widget.getButtonPadding)),
              ),
              const SizedBox(height: 16),
              Button(
                child: Text('Info App',
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
                onPressed: widget.onShowVersionInfo,
                style: ButtonStyle(
                    padding: ButtonState.all(widget.getButtonPadding)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SleepCalculatorTab extends StatefulWidget {
  final material.TimeOfDay? selectedTime;
  final bool showSleepCalculator;
  final ValueChanged<material.TimeOfDay> onTimeChanged;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const SleepCalculatorTab(
      {super.key,
      required this.selectedTime,
      required this.showSleepCalculator,
      required this.onTimeChanged,
      required this.getTextSize,
      required this.getTitleSize,
      required this.getButtonTextSize,
      required this.getIconSize,
      required this.getButtonPadding});

  @override
  State<SleepCalculatorTab> createState() => _SleepCalculatorTabState();
}

class _SleepCalculatorTabState extends State<SleepCalculatorTab> {
  material.TimeOfDay? _selectedTime;
  List<material.TimeOfDay> _results = [];
  String _calculationType = '';
  final int _sleepCycleMinutes = 90;
  final int _fallAsleepMinutes = 15;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.selectedTime;
  }

  void _onTimeChanged(material.TimeOfDay newTime) {
    setState(() {
      _selectedTime = newTime;
      _results.clear();
    });
    widget.onTimeChanged(newTime);
  }

  void _calculateWakeUpTimes() {
    setState(() {
      _calculationType = 'Sveglia';
      _results.clear();
      final now = DateTime.now();
      DateTime bedTime = DateTime(now.year, now.month, now.day,
          _selectedTime!.hour, _selectedTime!.minute);
      DateTime fallAsleepTime =
          bedTime.add(Duration(minutes: _fallAsleepMinutes));
      for (int i = 6; i >= 3; i--) {
        final wakeUpTime =
            fallAsleepTime.add(Duration(minutes: _sleepCycleMinutes * i));
        _results.add(material.TimeOfDay(
            hour: wakeUpTime.hour, minute: wakeUpTime.minute));
      }
    });
    _askSetAlarm();
  }

  void _calculateBedTimes() {
    setState(() {
      _calculationType = 'Dormire';
      _results.clear();
      final now = DateTime.now();
      DateTime wakeUpTime = DateTime(now.year, now.month, now.day,
          _selectedTime!.hour, _selectedTime!.minute);
      for (int i = 6; i >= 3; i--) {
        final bedTime =
            wakeUpTime.subtract(Duration(minutes: _sleepCycleMinutes * i));
        _results.add(
            material.TimeOfDay(hour: bedTime.hour, minute: bedTime.minute));
      }
    });
    _askSetAlarm();
  }

  Future<void> _askSetAlarm() async {
    if (_results.isEmpty) return;
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Imposta Sveglia'),
        content: const Text(
            'Vuoi impostare una sveglia per uno degli orari suggeriti?'),
        actions: [
          Button(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          Button(
            child: const Text('Sì'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (res == true) {
      await _handleSetAlarm();
    }
  }

  Future<void> _handleSetAlarm() async {
    // Verifica se esiste l'app orologio (Google Clock)
    const clockAppPackage = 'com.google.android.deskclock';
    final isInstalled = await InstalledApps.isAppInstalled(clockAppPackage);
    if (isInstalled != true) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Errore'),
          content: const Text(
              'Per impostare la sveglia è necessaria l\'app Google Orologio.'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }
    // Mostra dialog per selezionare l'orario
    final selected = await showDialog<material.TimeOfDay>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Scegli Orario Sveglia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _results
              .map((t) => Button(
                    child: Text(_formatTime(t)),
                    onPressed: () => Navigator.of(context).pop(t),
                  ))
              .toList(),
        ),
        actions: [
          Button(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (selected != null) {
      await _setAlarm(selected);
    }
  }

  Future<void> _setAlarm(material.TimeOfDay time) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': time.hour,
        'android.intent.extra.alarm.MINUTES': time.minute,
        'android.intent.extra.alarm.MESSAGE': 'Sveglia da SleepTrack',
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    try {
      await intent.launch();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Sveglia impostata'),
            content: Text('Sveglia impostata per le ${_formatTime(time)}.'),
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Errore'),
            content: Text('Impossibile impostare la sveglia: $e'),
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
  }

  String _formatTime(material.TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(BuildContext context) async {
    DateTime initial = _selectedTime != null
        ? DateTime(0, 1, 1, _selectedTime!.hour, _selectedTime!.minute)
        : DateTime.now();
    DateTime tempSelected = initial;

    final picked = await showDialog<material.TimeOfDay>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => ContentDialog(
            title: const Text('Scegli orario'),
            content: TimePicker(
              selected: tempSelected,
              onChanged: (dt) {
                if (dt != null) setState(() => tempSelected = dt);
              },
            ),
            actions: [
              Button(
                child: const Text('Annulla'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Button(
                child: const Text('Conferma'),
                onPressed: () {
                  Navigator.of(context).pop(
                    material.TimeOfDay(
                        hour: tempSelected.hour, minute: tempSelected.minute),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      _onTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 700),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).micaBackgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Calcolatore del Sonno',
                    style: FluentTheme.of(context)
                        .typography
                        .title
                        ?.copyWith(fontSize: widget.getTitleSize)),
                const SizedBox(height: 24),
                Button(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.clock, size: 32),
                      const SizedBox(width: 12),
                      Text(
                          _selectedTime == null
                              ? 'Scegli orario'
                              : 'Orario: ${_formatTime(_selectedTime!)}',
                          style: const TextStyle(fontSize: 22)),
                    ],
                  ),
                  onPressed: () => _selectTime(context),
                  style: ButtonStyle(
                      padding: ButtonState.all(widget.getButtonPadding)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Button(
                      child: Text('Calcola Sonno',
                          style: TextStyle(fontSize: widget.getButtonTextSize)),
                      onPressed:
                          _selectedTime == null ? null : _calculateBedTimes,
                      style: ButtonStyle(
                          padding: ButtonState.all(widget.getButtonPadding)),
                    ),
                    const SizedBox(width: 24),
                    Button(
                      child: Text('Calcola Sveglia',
                          style: TextStyle(fontSize: widget.getButtonTextSize)),
                      onPressed:
                          _selectedTime == null ? null : _calculateWakeUpTimes,
                      style: ButtonStyle(
                          padding: ButtonState.all(widget.getButtonPadding)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_results.isNotEmpty) ...[
                  Text(
                    _calculationType == 'Sveglia'
                        ? 'Dovresti svegliarti in uno di questi orari:'
                        : 'Dovresti andare a letto in uno di questi orari:',
                    style: FluentTheme.of(context)
                        .typography
                        .subtitle
                        ?.copyWith(fontSize: widget.getButtonTextSize),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _results
                        .map((t) => InfoBar(
                              title: Text(_formatTime(t),
                                  style: const TextStyle(fontSize: 20)),
                              severity: InfoBarSeverity.info,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdatesTab extends StatelessWidget {
  final List<Map<String, dynamic>> releaseHistory;
  final VoidCallback onCheckUpdate;
  final UpdateResult? updateResult;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const UpdatesTab(
      {super.key,
      required this.releaseHistory,
      required this.onCheckUpdate,
      required this.updateResult,
      required this.getTextSize,
      required this.getTitleSize,
      required this.getButtonTextSize,
      required this.getIconSize,
      required this.getButtonPadding});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 700),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Storico Aggiornamenti',
                style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 12),
            ...releaseHistory.map((rel) => InfoBar(
                  title: Text(rel['tag_name'] ?? '',
                      style: const TextStyle(fontSize: 20)),
                  content: Text(rel['name'] ?? '',
                      style: const TextStyle(fontSize: 20)),
                  severity: InfoBarSeverity.info,
                )),
            const SizedBox(height: 16),
            Button(
                child: const Text('Controlla Aggiornamenti'),
                onPressed: onCheckUpdate),
          ],
        ),
      ),
    );
  }
}

class InfoTab extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onShowVersionInfo;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const InfoTab(
      {super.key,
      required this.themeMode,
      required this.onThemeModeChanged,
      required this.onShowVersionInfo,
      required this.getTextSize,
      required this.getTitleSize,
      required this.getButtonTextSize,
      required this.getIconSize,
      required this.getButtonPadding});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 700),
      child: SingleChildScrollView(
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
      ),
    );
  }
}
