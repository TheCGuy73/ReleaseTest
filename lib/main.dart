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
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
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
    List<String> latestSemverParts = latestSemver.split('.');
    List<String> currentSemverParts = currentSemver.split('.');

    for (int i = 0; i < 3; i++) {
      int latestNum = i < latestSemverParts.length
          ? int.tryParse(latestSemverParts[i]) ?? 0
          : 0;
      int currentNum = i < currentSemverParts.length
          ? int.tryParse(currentSemverParts[i]) ?? 0
          : 0;

      if (latestNum > currentNum) {
        print('Nuova versione trovata (semver)');
        return true;
      }
      if (latestNum < currentNum) {
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
              }
            },
            itemBuilder: (BuildContext context) {
              return [
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
            icon: const Icon(Icons.system_update),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Allinea in alto
          children: <Widget>[
            // Selettore di tempo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selettore Orario:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.access_time,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Display dell'orario selezionato
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(_selectedTime),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Periodo del giorno
                  Text(
                    _getTimePeriod(_selectedTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottone per aprire il selettore
                  ElevatedButton.icon(
                    onPressed: _isTimePickerOpen ? null : _selectTime,
                    icon: _isTimePickerOpen
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.edit),
                    label: Text(
                      _isTimePickerOpen ? 'Apertura...' : 'Cambia Orario',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status aggiornamento
            if (_updateStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _updateStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_downloadProgress > 0 && _downloadProgress < 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
