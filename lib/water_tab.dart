import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'dart:async';

class WaterTab extends StatefulWidget {
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const WaterTab({
    super.key,
    required this.getTextSize,
    required this.getTitleSize,
    required this.getButtonTextSize,
    required this.getIconSize,
    required this.getButtonPadding,
  });

  @override
  State<WaterTab> createState() => _WaterTabState();
}

class _WaterTabState extends State<WaterTab> {
  int _glassesDrank = 0;
  final int _goal = 8; // 8 bicchieri standard
  Timer? _timer;
  DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _resetAtMidnight();
  }

  void _resetAtMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);
    _timer = Timer(duration, () {
      setState(() {
        _glassesDrank = 0;
        _today = DateTime.now();
      });
      _resetAtMidnight();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _addGlass() {
    setState(() {
      _glassesDrank++;
    });
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
              Icon(FluentIcons.coffee, size: 64),
              const SizedBox(height: 16),
              Text('Gestione Acqua',
                  style: FluentTheme.of(context)
                      .typography
                      .title
                      ?.copyWith(fontSize: widget.getTitleSize)),
              const SizedBox(height: 24),
              InfoBar(
                title: Text(
                  'Hai bevuto $_glassesDrank bicchieri oggi',
                  style: TextStyle(fontSize: widget.getTextSize),
                ),
                content: Text(
                  'Obiettivo: $_goal bicchieri',
                  style: TextStyle(fontSize: widget.getTextSize),
                ),
                severity: _glassesDrank >= _goal
                    ? InfoBarSeverity.success
                    : InfoBarSeverity.info,
              ),
              const SizedBox(height: 24),
              Button(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: widget.getIconSize),
                    const SizedBox(width: 8),
                    Text('Aggiungi bicchiere',
                        style: TextStyle(fontSize: widget.getButtonTextSize)),
                  ],
                ),
                onPressed: _addGlass,
                style: ButtonStyle(
                    padding: ButtonState.all(widget.getButtonPadding)),
              ),
              const SizedBox(height: 32),
              Text(
                _glassesDrank < _goal
                    ? 'Ricordati di bere acqua regolarmente!'
                    : 'Ottimo! Hai raggiunto il tuo obiettivo di oggi.',
                style: TextStyle(fontSize: widget.getTextSize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
