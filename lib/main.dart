import 'package:flutter/material.dart';
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
    return MaterialApp(
      title: 'Sleep Calculator',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: MyHomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MyHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late final UpdateService _updateService;
  UpdateResult? _updateResult;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _updateStatus = '';
  TimeOfDay _selectedTime = TimeOfDay.now();
  Map<String, dynamic>? _pendingUpdateRelease;
  bool _showSleepCalculator = false;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService(
      githubOwner: 'TheCGuy73',
      githubRepo: 'ReleaseTest',
    );
    WidgetsBinding.instance.addObserver(this);
    // Controlla automaticamente gli aggiornamenti all'avvio
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

  // Controlla gli aggiornamenti
  Future<void> _checkForUpdates({bool isAutomatic = false}) async {
    try {
      final result = await _updateService.checkForUpdates();
      setState(() {
        _updateResult = result;
      });

      if (result.isUpdateAvailable) {
        _showUpdateAvailableDialog(result.release!);
      } else if (!isAutomatic) {
        _showSnackBar('Nessun aggiornamento disponibile.');
      }
    } catch (e) {
      if (!isAutomatic) {
        _showSnackBar('Errore durante il controllo: ${e.toString()}');
      }
    }
  }

  // Mostra il dialogo di aggiornamento
  void _showUpdateAvailableDialog(Map<String, dynamic> release) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dopo'),
          ),
          ElevatedButton(
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

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permesso Richiesto'),
          content: const Text(
            'Per aggiornare l\'app, è necessario autorizzare l\'installazione. Verrai reindirizzato alle impostazioni per concedere il permesso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Vai alle Impostazioni'),
            ),
          ],
        ),
      );

      if (result == true) {
        await openAppSettings();
        // L'aggiornamento riprenderà automaticamente quando l'utente torna all'app.
      } else {
        setState(() {
          _pendingUpdateRelease = null;
        });
      }
    }
  }

  // Scarica e installa l'aggiornamento
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
              'Download: ${(_downloadProgress * 100).toStringAsFixed(1)}%';
        });
      });

      _updateStatus = 'Download completato. Avvio installazione...';
    } catch (e) {
      _updateStatus = 'Errore durante il download: ${e.toString()}';
      _showSnackBar('Errore: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Funzione per mostrare le informazioni sulla versione
  void _showVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.appName;
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void _onTimeChanged(TimeOfDay newTime) {
    setState(() {
      _selectedTime = newTime;
      _showSleepCalculator = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Calculator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'show_version') {
                _showVersionInfo();
              } else if (value == 'check_update') {
                _checkForUpdates();
              } else if (value == 'toggle_theme') {
                widget.onThemeModeChanged(ThemeMode.system);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'show_version',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Mostra Versione'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'check_update',
                  child: ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Controlla Aggiornamenti'),
                  ),
                ),
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('Tema',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        groupValue: widget.themeMode,
                        onChanged: (mode) {
                          if (mode != null) widget.onThemeModeChanged(mode);
                          Navigator.of(context).pop();
                        },
                        title: const Text('Automatico (Sistema)'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: widget.themeMode,
                        onChanged: (mode) {
                          if (mode != null) widget.onThemeModeChanged(mode);
                          Navigator.of(context).pop();
                        },
                        title: const Text('Chiaro'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: widget.themeMode,
                        onChanged: (mode) {
                          if (mode != null) widget.onThemeModeChanged(mode);
                          Navigator.of(context).pop();
                        },
                        title: const Text('Scuro'),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Center(
        child: _isDownloading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null),
                  const SizedBox(height: 20),
                  Text(_updateStatus),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TimePicker(
                    initialTime: _selectedTime,
                    onTimeChanged: _onTimeChanged,
                  ),
                  const SizedBox(height: 20),
                  if (_showSleepCalculator)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Calcolatore del Sonno',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: 'Nascondi',
                              onPressed: () {
                                setState(() {
                                  _showSleepCalculator = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SleepCalculator(timeToCalculate: _selectedTime),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Mostra calcolatore del sonno',
                      onPressed: () {
                        setState(() {
                          _showSleepCalculator = true;
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Tutte le funzionalità qui presenti sono in fase di testing, usale con cautela, a tuo rischio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TimePicker extends StatelessWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const TimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
  });

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && picked != initialTime) {
      onTimeChanged(picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Selettore Orario',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            _formatTime(initialTime),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _selectTime(context),
            icon: const Icon(Icons.edit),
            label: const Text('Cambia Orario'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class SleepCalculator extends StatefulWidget {
  final TimeOfDay timeToCalculate;

  const SleepCalculator({super.key, required this.timeToCalculate});

  @override
  State<SleepCalculator> createState() => _SleepCalculatorState();
}

class _SleepCalculatorState extends State<SleepCalculator> {
  List<TimeOfDay> _results = [];
  String _calculationType = '';
  final int _sleepCycleMinutes = 90;
  final int _fallAsleepMinutes = 15;

  void _calculateWakeUpTimes() {
    setState(() {
      _calculationType = 'Sveglia';
      _results.clear();
      DateTime bedTime = _timeOfDayToDateTime(widget.timeToCalculate);
      DateTime fallAsleepTime =
          bedTime.add(Duration(minutes: _fallAsleepMinutes));

      for (int i = 6; i >= 3; i--) {
        final wakeUpTime =
            fallAsleepTime.add(Duration(minutes: _sleepCycleMinutes * i));
        _results.add(TimeOfDay.fromDateTime(wakeUpTime));
      }
    });
  }

  void _calculateBedTimes() {
    setState(() {
      _calculationType = 'Dormire';
      _results.clear();
      DateTime wakeUpTime = _timeOfDayToDateTime(widget.timeToCalculate);

      for (int i = 6; i >= 3; i--) {
        final bedTime =
            wakeUpTime.subtract(Duration(minutes: _sleepCycleMinutes * i));
        _results.add(TimeOfDay.fromDateTime(bedTime));
      }
    });
  }

  DateTime _timeOfDayToDateTime(TimeOfDay time) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _showAlarmDialog() async {
    if (_results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prima calcola gli orari!')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imposta Sveglia'),
        content: const Text('Vuoi aggiungere una sveglia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sì'),
          ),
        ],
      ),
    );

    if (result == true) {
      _showTimeSelectionDialog();
    }
  }

  Future<void> _showTimeSelectionDialog() async {
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scegli Orario'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final time = _results[index];
              return ListTile(
                leading: Icon(
                  _calculationType == 'Sveglia'
                      ? Icons.alarm_on
                      : Icons.bedtime,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  _formatTime(time),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(time),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (selectedTime != null) {
      await _setAlarm(selectedTime);
    }
  }

  Future<void> _setAlarm(TimeOfDay time) async {
    const clockAppPackage = 'com.google.android.deskclock';
    final isInstalled = await InstalledApps.isAppInstalled(clockAppPackage);

    if (isInstalled != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Per impostare la sveglia è necessaria l\'app Google Orologio.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final alarmTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': time.hour,
        'android.intent.extra.alarm.MINUTES': time.minute,
        'android.intent.extra.alarm.MESSAGE': 'Sveglia da Sleep Calculator',
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );

    try {
      await intent.launch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Apertura di Google Orologio per impostare la sveglia...'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile aprire Google Orologio: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Calcolatore del Sonno',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _calculateBedTimes,
                child: const Text('Sonno'),
              ),
              ElevatedButton(
                onPressed: _calculateWakeUpTimes,
                child: const Text('Sveglia'),
              ),
            ],
          ),
          if (_results.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                children: [
                  Text(
                    _calculationType == 'Sveglia'
                        ? 'Dovresti svegliarti in uno di questi orari:'
                        : 'Dovresti andare a letto in uno di questi orari:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: _results.map((time) {
                      return Chip(
                        avatar: Icon(
                          _calculationType == 'Sveglia'
                              ? Icons.alarm_on
                              : Icons.bedtime,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          _formatTime(time),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAlarmDialog,
                    icon: const Icon(Icons.alarm_add),
                    label: const Text('Imposta Sveglia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
