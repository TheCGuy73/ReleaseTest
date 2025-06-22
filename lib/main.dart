import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'update_service.dart';

void main() {
  // Assicura che i binding di Flutter siano inizializzati prima di eseguire l'app.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Version App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Updater'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'show_version') {
                _showVersionInfo();
              } else if (value == 'check_update') {
                _checkForUpdates();
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
                    onTimeChanged: (newTime) {
                      setState(() {
                        _selectedTime = newTime;
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
