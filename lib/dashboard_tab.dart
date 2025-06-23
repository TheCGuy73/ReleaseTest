import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

class DashboardTab extends StatefulWidget {
  final dynamic updateResult;
  final VoidCallback onCheckUpdate;
  final bool isDownloading;
  final double downloadProgress;
  final String updateStatus;
  final VoidCallback onShowVersionInfo;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const DashboardTab({
    super.key,
    required this.updateResult,
    required this.onCheckUpdate,
    required this.isDownloading,
    required this.downloadProgress,
    required this.updateStatus,
    required this.onShowVersionInfo,
    required this.getTextSize,
    required this.getTitleSize,
    required this.getButtonTextSize,
    required this.getIconSize,
    required this.getButtonPadding,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _displayedText = '';
  final String _fullText = 'Benvenuto in SleepTrack!';
  int _charIndex = 0;
  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  void _startTypewriter() async {
    while (_charIndex < _fullText.length) {
      await Future.delayed(const Duration(milliseconds: 45));
      setState(() {
        _displayedText = _fullText.substring(0, _charIndex + 1);
        _charIndex++;
      });
    }
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
              Image.asset('assets/icon/icon.png', width: 96, height: 96),
              const SizedBox(height: 24),
              Text(_displayedText,
                  style: FluentTheme.of(context)
                      .typography
                      .title
                      ?.copyWith(fontSize: widget.getTitleSize)),
              const SizedBox(height: 32),
              InfoBar(
                title: Text(
                  widget.updateResult?.isUpdateAvailable == true
                      ? 'Aggiornamento disponibile!'
                      : 'App aggiornata',
                  style: const TextStyle(fontSize: 22),
                ),
                severity: widget.updateResult?.isUpdateAvailable == true
                    ? InfoBarSeverity.warning
                    : InfoBarSeverity.success,
                action: widget.updateResult?.isUpdateAvailable == true
                    ? Button(
                        child: Text('Aggiorna',
                            style:
                                TextStyle(fontSize: widget.getButtonTextSize)),
                        onPressed: widget.onCheckUpdate,
                        style: ButtonStyle(
                            padding: ButtonState.all(widget.getButtonPadding)),
                      )
                    : null,
              ),
              if (widget.isDownloading) ...[
                const SizedBox(height: 24),
                ProgressBar(
                  value: widget.downloadProgress > 0
                      ? widget.downloadProgress
                      : null,
                ),
                const SizedBox(height: 16),
                Text(widget.updateStatus,
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
              ],
              const SizedBox(height: 32),
              Button(
                child: Text('Controlla Aggiornamenti',
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
                onPressed: widget.onCheckUpdate,
                style: ButtonStyle(
                    padding: ButtonState.all(widget.getButtonPadding)),
              ),
              const SizedBox(height: 16),
              Button(
                child: Text('Info App',
                    style: TextStyle(fontSize: widget.getButtonTextSize)),
                onPressed: widget.onShowVersionInfo,
                style: ButtonStyle(
                    padding: ButtonState.all(widget.getButtonPadding)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
