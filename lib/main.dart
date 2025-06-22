import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:app_settings/app_settings.dart';

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
  String _latestVersion = '';
  bool _isCheckingUpdate = false;
  bool _isUpdating = false;
  String _updateStatus = '';
  double _downloadProgress = 0.0;

  // Aggiungo per info dettagliate
  PackageInfo? _packageInfo;

  // Variabili per il selettore di tempo
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isTimePickerOpen = false;

  // Configurazione GitHub - Sostituisci con i tuoi dati
  final String _githubOwner = 'TheCGuy73';
  final String _githubRepo = 'ReleaseTest';
  final String _githubToken = ''; // Opzionale, per repository privati

  @override
  void initState() {
    super.initState();
    _loadAppVersion().then((_) {
      // Controlla aggiornamenti automaticamente all'avvio
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
        _appVersion = 'Errore nel caricamento della versione';
      });
    }
  }

  // Metodo per aprire il selettore di tempo
  Future<void> _selectTime() async {
    setState(() {
      _isTimePickerOpen = true;
    });

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: Theme.of(context).colorScheme.primary,
              hourMinuteColor: Theme.of(context).colorScheme.surfaceVariant,
              dialBackgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialTextColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          child: child!,
        );
      },
    );

    setState(() {
      _isTimePickerOpen = false;
    });

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      _showSnackBar('Orario selezionato: ${_formatTime(_selectedTime)}');
    }
  }

  // Metodo per formattare l'orario
  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Metodo per ottenere il periodo del giorno
  String _getTimePeriod(TimeOfDay time) {
    if (time.hour < 12) {
      return 'Mattina';
    } else if (time.hour < 18) {
      return 'Pomeriggio';
    } else {
      return 'Sera';
    }
  }

  Future<void> _checkForUpdates({bool isAutomatic = false}) async {
    if (!isAutomatic) {
      setState(() {
        _isCheckingUpdate = true;
        _updateStatus = 'Controllo aggiornamenti...';
      });
    }

    try {
      final dio = Dio();

      // Aggiungi token se necessario
      if (_githubToken.isNotEmpty) {
        dio.options.headers['Authorization'] = 'token $_githubToken';
      }

      // Prima prova a ottenere l'ultima release ufficiale
      try {
        final response = await dio.get(
          'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
        );

        if (response.statusCode == 200) {
          final latestRelease = response.data;
          final latestVersion = latestRelease['tag_name'] ?? '';

          if (!isAutomatic) {
            setState(() {
              _latestVersion = latestVersion;
              _updateStatus = 'Ultima versione disponibile: $latestVersion';
            });
          }

          // Confronta le versioni
          if (_isNewerVersion(latestVersion, _appVersion)) {
            _showUpdateAvailableDialog(latestRelease);
          } else if (!isAutomatic) {
            _showSnackBar('L\'app è già aggiornata!');
            setState(() {
              _updateStatus = 'App aggiornata alla versione più recente';
            });
          }
          return;
        }
      } catch (e) {
        // Se non ci sono release ufficiali, prova con le pre-release
        if (!isAutomatic)
          print('Nessuna release ufficiale trovata, controllo pre-release...');
      }

      // Se non ci sono release ufficiali, ottieni tutte le release e prendi la più recente
      final allReleasesResponse = await dio.get(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases',
      );

      if (allReleasesResponse.statusCode == 200) {
        final releases = allReleasesResponse.data as List<dynamic>;

        if (releases.isNotEmpty) {
          // Prendi la release più recente (prima nell'array)
          final latestRelease = releases.first;
          final latestVersion = latestRelease['tag_name'] ?? '';

          setState(() {
            _latestVersion = latestVersion;
          });

          if (!isAutomatic) {
            setState(() {
              _updateStatus =
                  'Ultima versione disponibile: $latestVersion (${latestRelease['prerelease'] ? 'Pre-release' : 'Release'})';
            });
          }

          // Confronta le versioni
          if (_isNewerVersion(latestVersion, _appVersion)) {
            _showUpdateAvailableDialog(latestRelease);
          } else if (!isAutomatic) {
            _showSnackBar('L\'app è già aggiornata!');
            setState(() {
              _updateStatus = 'App aggiornata alla versione più recente';
            });
          }
        } else if (!isAutomatic) {
          setState(() {
            _updateStatus = 'Nessuna release trovata';
          });
          _showSnackBar('Nessuna release trovata nel repository');
        }
      }
    } catch (e) {
      if (!isAutomatic) {
        setState(() {
          _updateStatus = 'Errore nel controllo aggiornamenti: $e';
        });
        _showSnackBar('Errore nel controllo aggiornamenti: $e');
      }
    } finally {
      if (!isAutomatic) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  bool _isNewerVersion(String latestVersion, String currentVersion) {
    print('Controllo nuova versione...');
    print('Versione GitHub: $latestVersion');
    print('Versione App: $currentVersion');

    // Rimuovi il prefisso 'v' se presente
    if (latestVersion.startsWith('v')) {
      latestVersion = latestVersion.substring(1);
    }

    // Separa versione e build number
    List<String> latestParts = latestVersion.split('+');
    String latestSemver = latestParts[0];
    int latestBuild = latestParts.length > 1
        ? int.tryParse(latestParts[1]) ?? 0
        : 0;

    List<String> currentParts = currentVersion.split('+');
    String currentSemver = currentParts[0];
    int currentBuild = currentParts.length > 1
        ? int.tryParse(currentParts[1]) ?? 0
        : 0;

    print('-> Versione GitHub analizzata: $latestSemver, build: $latestBuild');
    print('-> Versione App analizzata: $currentSemver, build: $currentBuild');

    // Confronta la parte semver (major.minor.patch)
    List<int> latestSemverParts = latestSemver
        .split('.')
        .map(int.parse)
        .toList();
    List<int> currentSemverParts = currentSemver
        .split('.')
        .map(int.parse)
        .toList();

    // Assicura che entrambe le liste abbiano la stessa lunghezza per il confronto
    while (latestSemverParts.length < currentSemverParts.length)
      latestSemverParts.add(0);
    while (currentSemverParts.length < latestSemverParts.length)
      currentSemverParts.add(0);

    for (int i = 0; i < latestSemverParts.length; i++) {
      if (latestSemverParts[i] > currentSemverParts[i]) {
        print('Nuova versione trovata (semver)');
        return true;
      }
      if (latestSemverParts[i] < currentSemverParts[i]) {
        print('Versione attuale più recente (semver)');
        return false;
      }
    }

    // Se la parte semver è identica, confronta il build number
    if (latestBuild > currentBuild) {
      print('Nuova versione trovata (build number)');
      return true;
    }

    print('Nessuna nuova versione trovata');
    return false;
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
              Text(
                'Descrizione:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(release['body'] ?? 'Nessuna descrizione disponibile'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vuoi scaricare e installare questo aggiornamento?',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _updateStatus = 'Aggiornamento disponibile ma non installato';
                });
              },
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
    setState(() {
      _isUpdating = true;
      _updateStatus = 'Preparazione download...';
      _downloadProgress = 0.0;
    });

    try {
      // Richiedi permessi per Android
      if (Platform.isAndroid) {
        bool hasPermissions = await _requestStoragePermissions();
        if (!hasPermissions) {
          setState(() {
            _isUpdating = false;
            _updateStatus = 'Permessi di storage non concessi';
          });
          return;
        }
      }

      // Trova l'asset APK
      final assets = release['assets'] as List<dynamic>;
      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => throw Exception('APK non trovato nella release'),
      );

      final downloadUrl = apkAsset['browser_download_url'];
      final fileName = apkAsset['name'];

      setState(() {
        _updateStatus = 'Download in corso...';
      });

      // Scarica il file
      final dio = Dio();

      // Scegli il directory appropriato per il download
      Directory downloadDir;
      if (Platform.isAndroid) {
        // Prova prima il directory pubblico dei download
        try {
          downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            downloadDir = await getApplicationDocumentsDirectory();
          }
        } catch (e) {
          downloadDir = await getApplicationDocumentsDirectory();
        }
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${downloadDir.path}/$fileName';

      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
              _updateStatus =
                  'Download: ${(_downloadProgress * 100).toStringAsFixed(1)}%';
            });
          }
        },
      );

      setState(() {
        _updateStatus = 'Installazione in corso...';
      });

      // Installa l'APK
      if (Platform.isAndroid) {
        try {
          // Prova a usare l'intent per aprire il file APK
          final result = await Process.run('am', [
            'start',
            '-a',
            'android.intent.action.VIEW',
            '-d',
            'file://$filePath',
            '-t',
            'application/vnd.android.package-archive',
          ]);

          if (result.exitCode == 0) {
            _showSnackBar(
              'APK scaricato in: $filePath\nApri il file per installare.',
            );
          } else {
            // Fallback: mostra il percorso del file
            _showSnackBar(
              'APK scaricato in: $filePath\nApri manualmente il file per installare.',
            );
          }
        } catch (e) {
          // Se fallisce, mostra il percorso del file
          _showSnackBar(
            'APK scaricato in: $filePath\nApri manualmente il file per installare.',
          );
        }
      }
    } catch (e) {
      setState(() {
        _updateStatus = 'Errore: $e';
      });
      _showSnackBar('Errore durante l\'aggiornamento: $e');
    } finally {
      setState(() {
        _isUpdating = false;
        _downloadProgress = 0.0;
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

  Future<void> _downloadLatestUpdate() async {
    try {
      final dio = Dio();

      // Aggiungi token se necessario
      if (_githubToken.isNotEmpty) {
        dio.options.headers['Authorization'] = 'token $_githubToken';
      }

      // Ottieni la release più recente
      final response = await dio.get(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      );

      if (response.statusCode == 200) {
        final latestRelease = response.data;
        await _downloadAndInstallUpdate(latestRelease);
      } else {
        // Fallback: ottieni tutte le release
        final allReleasesResponse = await dio.get(
          'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases',
        );

        if (allReleasesResponse.statusCode == 200) {
          final releases = allReleasesResponse.data as List<dynamic>;
          if (releases.isNotEmpty) {
            await _downloadAndInstallUpdate(releases.first);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Errore nel recupero della release: $e');
    }
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
              } else if (value == 'download_update') {
                _downloadLatestUpdate();
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
                  enabled: !_isCheckingUpdate && !_isUpdating,
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
                if (_latestVersion.isNotEmpty &&
                    _isNewerVersion(_latestVersion, _appVersion))
                  PopupMenuItem<String>(
                    value: 'download_update',
                    enabled: !_isUpdating,
                    child: ListTile(
                      leading: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, color: Colors.green),
                      title: Text(
                        _isUpdating
                            ? 'Download...'
                            : 'Scarica v$_latestVersion',
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
