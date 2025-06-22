import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'update_service.dart'; // Importa il nuovo servizio

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Release Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

class _MyHomePageState extends State<MyHomePage> {
  String _appVersion = 'Caricamento...';
  String _updateStatus = '';
  double _downloadProgress = 0.0;
  PackageInfo? _packageInfo;
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Variabili per la gestione dello stato dell'aggiornamento
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  UpdateResult? _updateResult;

  // Istanza del servizio di aggiornamento
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    // Inizializza il servizio con la configurazione di GitHub
    _updateService = UpdateService(
      githubOwner: 'TheCGuy73',
      githubRepo: 'ReleaseTest',
      githubToken: '', // Opzionale
    );

    _loadAppVersion().then((_) {
      _checkForUpdates(isAutomatic: true);
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _packageInfo = packageInfo;
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Errore caricamento versione';
      });
    }
  }

  Future<void> _checkForUpdates({bool isAutomatic = false}) async {
    if (!isAutomatic) {
      setState(() {
        _isCheckingUpdate = true;
        _updateStatus = 'Controllo aggiornamenti...';
        _updateResult = null;
      });
    }

    try {
      final result = await _updateService.checkForUpdates(_appVersion);
      setState(() {
        _updateResult = result;
        if (result.isUpdateAvailable) {
          if (isAutomatic) {
            _showUpdateAvailableDialog(result.release!);
          } else {
            _updateStatus =
                'Nuova versione disponibile: ${result.latestVersion}';
          }
        } else if (!isAutomatic) {
          _updateStatus = 'L\'app è già aggiornata.';
          _showSnackBar('Nessun aggiornamento trovato.');
        }
      });
    } catch (e) {
      if (!isAutomatic) {
        setState(() {
          _updateStatus = 'Errore: ${e.toString()}';
        });
        _showSnackBar('Errore durante il controllo: ${e.toString()}');
      }
    } finally {
      if (!isAutomatic) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  void _showUpdateAvailableDialog(Map<String, dynamic> release) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aggiornamento Disponibile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versione attuale: $_appVersion'),
              const SizedBox(height: 8),
              Text('Nuova versione: ${release['tag_name']}'),
              const SizedBox(height: 16),
              const Text(
                'Vuoi scaricare e installare questo aggiornamento?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(release);
              },
              icon: const Icon(Icons.download),
              label: const Text('Scarica e Installa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> release) async {
    // Richiedi permessi prima di iniziare il download
    if (Platform.isAndroid) {
      bool permissionsGranted = await _requestStoragePermissions();
      if (!permissionsGranted) {
        _showSnackBar('Permessi di storage negati. Impossibile scaricare.');
        return;
      }
    }

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
      setState(() {
        _updateStatus = 'Errore durante il download: ${e.toString()}';
      });
      _showSnackBar('Errore: ${e.toString()}');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.storage.status;
    if (status.isGranted) return true;

    // Mostra dialog informativo prima di richiedere i permessi
    bool shouldRequest =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Permessi Richiesti'),
              content: const Text(
                'L\'app ha bisogno dei permessi di storage per scaricare e installare gli aggiornamenti. '
                'Vuoi concedere questi permessi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Concedi Permessi'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRequest) return false;

    // Richiedi i permessi
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    bool hasStoragePermission =
        statuses[Permission.storage]?.isGranted == true ||
        statuses[Permission.manageExternalStorage]?.isGranted == true;

    if (!hasStoragePermission) {
      // Mostra dialog per aprire le impostazioni
      bool openSettings =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Permessi Negati'),
                content: const Text(
                  'I permessi di storage sono necessari per scaricare gli aggiornamenti. '
                  'Vuoi aprire le impostazioni per concederli manualmente?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annulla'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Apri Impostazioni'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (openSettings) {
        await openAppSettings();
      }
    }

    return hasStoragePermission;
  }

  void _showVersionInfoDialog() {
    if (_packageInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informazioni App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Nome App'),
              subtitle: Text(_packageInfo!.appName),
            ),
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: const Text('Versione'),
              subtitle: Text(_packageInfo!.version),
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Build'),
              subtitle: Text(_packageInfo!.buildNumber),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Nome Pacchetto'),
              subtitle: Text(_packageInfo!.packageName),
            ),
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Release Test App'),
        centerTitle: true,
        actions: [
          // Menu a tendina per gli aggiornamenti
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'check_update') {
                _checkForUpdates(isAutomatic: false);
              } else if (value == 'show_info') {
                _showVersionInfoDialog();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                // Opzione per le informazioni
                const PopupMenuItem<String>(
                  value: 'show_info',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Informazioni'),
                  ),
                ),
                const PopupMenuDivider(),
                // Opzione per controllare gli aggiornamenti
                PopupMenuItem<String>(
                  value: 'check_update',
                  enabled: !_isCheckingUpdate && !_isDownloading,
                  child: ListTile(
                    leading: _isCheckingUpdate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    title: Text(
                      _isCheckingUpdate
                          ? 'Controllo...'
                          : 'Controlla Aggiornamenti',
                    ),
                  ),
                ),

                // Opzione per scaricare l'aggiornamento, se disponibile
                if (_updateResult != null && _updateResult!.isUpdateAvailable)
                  PopupMenuItem<String>(
                    value: 'download_update',
                    enabled: !_isDownloading,
                    child: ListTile(
                      leading: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, color: Colors.green),
                      title: Text(
                        _isDownloading
                            ? 'Download...'
                            : 'Scarica v${_updateResult!.latestVersion}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ];
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TimePicker(
              initialTime: _selectedTime,
              onTimeChanged: (newTime) {
                setState(() {
                  _selectedTime = newTime;
                });
              },
            ),
            const SizedBox(height: 20),
            SleepCalculator(timeToCalculate: _selectedTime),
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

  String _getTimePeriod(TimeOfDay time) {
    if (time.hour >= 5 && time.hour < 12) {
      return 'Mattina';
    } else if (time.hour >= 12 && time.hour < 18) {
      return 'Pomeriggio';
    } else if (time.hour >= 18 && time.hour < 22) {
      return 'Sera';
    } else {
      return 'Notte';
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selettore Orario:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Icon(
                Icons.access_time,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(initialTime),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getTimePeriod(initialTime),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _selectTime(context),
            icon: const Icon(Icons.edit),
            label: const Text('Cambia Orario'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
      DateTime fallAsleepTime = bedTime.add(
        Duration(minutes: _fallAsleepMinutes),
      );

      for (int i = 6; i >= 3; i--) {
        // Suggerisce orari per 6, 5, 4, 3 cicli di sonno
        final wakeUpTime = fallAsleepTime.add(
          Duration(minutes: _sleepCycleMinutes * i),
        );
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
        // Suggerisce orari per 6, 5, 4, 3 cicli di sonno
        final bedTime = wakeUpTime.subtract(
          Duration(minutes: _sleepCycleMinutes * i),
        );
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
          const SizedBox(height: 8),
          Text(
            'Usa l\'orario selezionato sopra e calcola i cicli di sonno.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _calculateBedTimes,
                child: const Text('sonno'),
              ),
              ElevatedButton(
                onPressed: _calculateWakeUpTimes,
                child: const Text('sveglia'),
              ),
            ],
          ),
          if (_results.isNotEmpty)
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Per completare da 3 a 6 cicli di sonno completi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
