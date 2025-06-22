import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Classe per incapsulare il risultato di un controllo aggiornamenti.
class UpdateResult {
  final bool isUpdateAvailable;
  final String latestVersion;
  final Map<String, dynamic>? release;

  UpdateResult({
    required this.isUpdateAvailable,
    this.latestVersion = '',
    this.release,
  });
}

/// Servizio per la gestione degli aggiornamenti dell'app tramite GitHub Releases.
class UpdateService {
  final String githubOwner;
  final String githubRepo;
  final String githubToken;

  UpdateService({
    required this.githubOwner,
    required this.githubRepo,
    this.githubToken = '',
  });

  /// Controlla la presenza di una nuova versione su GitHub.
  Future<UpdateResult> checkForUpdates(String currentVersion) async {
    try {
      final dio = Dio();
      if (githubToken.isNotEmpty) {
        dio.options.headers['authorization'] = 'token $githubToken';
      }

      final response = await dio.get(
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases',
      );

      if (response.statusCode == 200) {
        final releases = response.data as List<dynamic>;
        if (releases.isNotEmpty) {
          final latestRelease = releases.first;
          final latestVersionTag = latestRelease['tag_name'] ?? '';

          if (_isNewerVersion(latestVersionTag, currentVersion)) {
            return UpdateResult(
              isUpdateAvailable: true,
              latestVersion: latestVersionTag,
              release: latestRelease,
            );
          }
        }
      }
      return UpdateResult(isUpdateAvailable: false);
    } catch (e) {
      print('Errore durante il controllo aggiornamenti: $e');
      rethrow; // Rilancia l'eccezione per essere gestita dall'UI
    }
  }

  /// Scarica e avvia l'installazione dell'aggiornamento.
  Future<void> downloadAndInstallUpdate(
    Map<String, dynamic> release,
    Function(double) onProgress,
  ) async {
    try {
      final assets = release['assets'] as List<dynamic>;
      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => throw Exception('Nessun file APK trovato nella release.'),
      );

      final downloadUrl = apkAsset['browser_download_url'];
      final fileName = apkAsset['name'];

      final dio = Dio();

      Directory downloadDir;
      if (Platform.isAndroid) {
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
            onProgress(received / total);
          }
        },
      );

      _installApk(filePath);
    } catch (e) {
      print('Errore durante il download: $e');
      rethrow;
    }
  }

  /// Avvia l'intent di sistema per installare un APK.
  Future<void> _installApk(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await Process.run('am', [
          'start',
          '-a',
          'android.intent.action.VIEW',
          '-d',
          'file://$filePath',
          '-t',
          'application/vnd.android.package-archive',
        ]);
      } catch (e) {
        print('Installazione fallita: $e');
        rethrow;
      }
    }
  }

  /// Confronta due stringhe di versione per determinare se 'latestVersion' è più recente.
  bool _isNewerVersion(String latestVersion, String currentVersion) {
    print("--- INIZIO DEBUG AGGIORNAMENTO ---");
    print("Ricevuta versione da GitHub: '$latestVersion'");
    print("Ricevuta versione corrente: '$currentVersion'");

    var latest = latestVersion.startsWith('v')
        ? latestVersion.substring(1)
        : latestVersion;
    var current = currentVersion;

    List<String> latestParts = latest.split('+');
    String latestSemver = latestParts[0];
    int latestBuild =
        latestParts.length > 1 ? int.tryParse(latestParts[1]) ?? 0 : 0;

    List<String> currentParts = current.split('+');
    String currentSemver = currentParts[0];
    int currentBuild =
        currentParts.length > 1 ? int.tryParse(currentParts[1]) ?? 0 : 0;

    print(
        "Confronto SemVer: '$latestSemver' (GitHub) vs '$currentSemver' (App)");
    print("Confronto Build: '$latestBuild' (GitHub) vs '$currentBuild' (App)");

    List<int> latestSemverParts =
        latestSemver.split('.').map(int.parse).toList();
    List<int> currentSemverParts =
        currentSemver.split('.').map(int.parse).toList();

    while (latestSemverParts.length < currentSemverParts.length)
      latestSemverParts.add(0);
    while (currentSemverParts.length < latestSemverParts.length)
      currentSemverParts.add(0);

    for (int i = 0; i < latestSemverParts.length; i++) {
      if (latestSemverParts[i] > currentSemverParts[i]) {
        print("RISULTATO: VERO (major/minor/patch è maggiore)");
        print("--- FINE DEBUG ---");
        return true;
      }
      if (latestSemverParts[i] < currentSemverParts[i]) {
        print("RISULTATO: FALSO (major/minor/patch è minore)");
        print("--- FINE DEBUG ---");
        return false;
      }
    }

    bool isNewer = latestBuild > currentBuild;
    print("RISULTATO: $isNewer (basato sul build number)");
    print("--- FINE DEBUG ---");
    return isNewer;
  }
}
