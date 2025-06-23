import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:android_intent_plus/android_intent.dart';
import 'package:installed_apps/installed_apps.dart';

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
        final intent = AndroidIntent(
          action: 'android.intent.action.SET_ALARM',
          arguments: <String, dynamic>{
            'android.intent.extra.alarm.HOUR': selected.hour,
            'android.intent.extra.alarm.MINUTES': selected.minute,
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
                content:
                    Text('Sveglia impostata per le ${_formatTime(selected)}.'),
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
    }
  }

  String _formatTime(material.TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
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
                                : 'Orario: ${_formatTime(_selectedTime!)}',
                            style: const TextStyle(fontSize: 22)),
                      ],
                    ),
                    onPressed: () => _selectTime(context),
                    style: ButtonStyle(
                        padding: ButtonState.all(widget.getButtonPadding)),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Button(
                        child: Text('Calcola Sonno',
                            style:
                                TextStyle(fontSize: widget.getButtonTextSize)),
                        onPressed:
                            _selectedTime == null ? null : _calculateBedTimes,
                        style: ButtonStyle(
                            padding: ButtonState.all(widget.getButtonPadding)),
                      ),
                      const SizedBox(height: 16),
                      Button(
                        child: Text('Calcola Sveglia',
                            style:
                                TextStyle(fontSize: widget.getButtonTextSize)),
                        onPressed: _selectedTime == null
                            ? null
                            : _calculateWakeUpTimes,
                        style: ButtonStyle(
                            padding: ButtonState.all(widget.getButtonPadding)),
                      ),
                    ],
                  ),
                ],
              ),
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
              Column(
                children: _results
                    .map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: InfoBar(
                            title: Text(_formatTime(t),
                                style: const TextStyle(fontSize: 20)),
                            severity: InfoBarSeverity.info,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
