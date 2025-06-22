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

  // Configurazione GitHub - Sostituisci con i tuoi dati
  final String _githubOwner = 'TheCGuy73';
  final String _githubRepo = 'ReleaseTest';
  final String _githubToken = ''; // Opzionale, per repository privati

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
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

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatus = 'Controllo aggiornamenti...';
    });

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

          setState(() {
            _latestVersion = latestVersion;
            _updateStatus = 'Ultima versione disponibile: $latestVersion';
          });

          // Confronta le versioni
          if (_isNewerVersion(latestVersion, _appVersion)) {
            _showUpdateDialog(latestRelease);
          } else {
            _showSnackBar('L\'app è già aggiornata!');
          }
          return;
        }
      } catch (e) {
        // Se non ci sono release ufficiali, prova con le pre-release
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
            _updateStatus =
                'Ultima versione disponibile: $latestVersion (${latestRelease['prerelease'] ? 'Pre-release' : 'Release'})';
          });

          // Confronta le versioni
          if (_isNewerVersion(latestVersion, _appVersion)) {
            _showUpdateDialog(latestRelease);
          } else {
            _showSnackBar('L\'app è già aggiornata!');
          }
        } else {
          setState(() {
            _updateStatus = 'Nessuna release trovata';
          });
          _showSnackBar('Nessuna release trovata nel repository');
        }
      }
    } catch (e) {
      setState(() {
        _updateStatus = 'Errore nel controllo aggiornamenti: $e';
      });
      _showSnackBar('Errore nel controllo aggiornamenti: $e');
    } finally {
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  bool _isNewerVersion(String latestVersion, String currentVersion) {
    // Logica semplice per confrontare le versioni
    // Rimuovi il prefisso 'v' se presente
    latestVersion = latestVersion.replaceAll('v', '');
    currentVersion = currentVersion.split('+')[0]; // Rimuovi il build number

    final latest = latestVersion.split('.');
    final current = currentVersion.split('.');

    for (int i = 0; i < 3; i++) {
      final latestNum = i < latest.length ? int.tryParse(latest[i]) ?? 0 : 0;
      final currentNum = i < current.length ? int.tryParse(current[i]) ?? 0 : 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  void _showUpdateDialog(Map<String, dynamic> release) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aggiornamento disponibile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versione attuale: $_appVersion'),
              const SizedBox(height: 8),
              Text('Nuova versione: ${release['tag_name']}'),
              const SizedBox(height: 16),
              Text(release['body'] ?? 'Nessuna descrizione disponibile'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(release);
              },
              child: const Text('Aggiorna'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Release Test App'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Versione dell'app
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Versione App:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _appVersion,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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

              const SizedBox(height: 40),

              // Bottone di aggiornamento
              ElevatedButton.icon(
                onPressed: _isCheckingUpdate || _isUpdating
                    ? null
                    : _checkForUpdates,
                icon: _isCheckingUpdate || _isUpdating
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
                    : const Icon(Icons.system_update),
                label: Text(
                  _isCheckingUpdate
                      ? 'Controllo...'
                      : _isUpdating
                      ? 'Aggiornamento...'
                      : 'Controlla Aggiornamenti',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Informazioni GitHub
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Configurazione GitHub:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text('Repository: $_githubOwner/$_githubRepo'),
                    const SizedBox(height: 8),
                    const Text(
                      'Nota: Modifica le variabili _githubOwner e _githubRepo nel codice per il tuo repository.',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
