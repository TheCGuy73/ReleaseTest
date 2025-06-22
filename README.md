# Release Test App

Un'applicazione Flutter che dimostra come implementare l'aggiornamento automatico tramite GitHub Releases.

## Funzionalità

- ✅ Visualizzazione della versione corrente dell'app
- ✅ Controllo automatico degli aggiornamenti da GitHub
- ✅ Download e installazione di nuovi APK
- ✅ Interfaccia utente moderna con Material Design 3
- ✅ Barra di progresso per il download
- ✅ Gestione degli errori e stati di caricamento

## Configurazione

### 1. Modifica le variabili GitHub

Nel file `lib/main.dart`, modifica le seguenti variabili con i tuoi dati:

```dart
final String _githubOwner = 'tuo-username';  // Il tuo username GitHub
final String _githubRepo = 'release_test';   // Il nome del tuo repository
final String _githubToken = '';              // Token GitHub (opzionale, per repo privati)
```

### 2. Crea una Release su GitHub

1. Vai nel tuo repository GitHub
2. Clicca su "Releases" nella barra laterale
3. Clicca "Create a new release"
4. Inserisci un tag (es. `v1.0.1`)
5. Aggiungi una descrizione della release
6. **Importante**: Carica il file APK nella sezione "Attachments"
7. Pubblica la release

### 3. Build dell'APK

Per creare un APK da distribuire:

```bash
flutter build apk --release
```

L'APK sarà disponibile in: `build/app/outputs/flutter-apk/app-release.apk`

## Come funziona

1. **Controllo versione**: L'app confronta la versione corrente con l'ultima release su GitHub
2. **Download**: Se è disponibile una versione più recente, l'app scarica l'APK
3. **Installazione**: L'app apre l'installer di Android per installare il nuovo APK

## Permessi richiesti

L'app richiede i seguenti permessi Android:
- `INTERNET`: Per scaricare gli aggiornamenti
- `WRITE_EXTERNAL_STORAGE`: Per salvare l'APK scaricato
- `READ_EXTERNAL_STORAGE`: Per accedere ai file scaricati
- `REQUEST_INSTALL_PACKAGES`: Per installare nuovi APK

## Dipendenze

- `package_info_plus`: Per ottenere la versione dell'app
- `dio`: Per le richieste HTTP e download
- `path_provider`: Per gestire i percorsi dei file
- `permission_handler`: Per gestire i permessi Android

## Note importanti

### Per repository privati
Se il tuo repository è privato, dovrai:
1. Creare un Personal Access Token su GitHub
2. Inserirlo nella variabile `_githubToken`

### Versioning
- Usa il formato semantico per le versioni (es. `1.0.0`, `1.0.1`, `1.1.0`)
- Il tag GitHub deve corrispondere alla versione nel `pubspec.yaml`
- Per le release, usa il prefisso `v` (es. `v1.0.1`)

### Sicurezza
- Verifica sempre l'integrità degli APK scaricati
- Considera l'implementazione di firme digitali per gli APK
- Testa sempre gli aggiornamenti prima della distribuzione

## Troubleshooting

### Errore "APK non trovato nella release"
Assicurati di aver caricato un file `.apk` nella release GitHub.

### Errore "Permessi di storage non concessi"
L'utente deve concedere i permessi di storage quando richiesto dall'app.

### Errore "Errore nell'apertura del file APK"
Su alcuni dispositivi Android, potrebbe essere necessario abilitare l'installazione da fonti sconosciute nelle impostazioni.

## Sviluppo

Per eseguire l'app in modalità sviluppo:

```bash
flutter run
```

Per build di debug:

```bash
flutter build apk --debug
```

## Licenza

Questo progetto è rilasciato sotto licenza MIT.
