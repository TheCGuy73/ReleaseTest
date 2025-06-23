import 'package:fluent_ui/fluent_ui.dart';

class InfoTab extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onShowVersionInfo;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const InfoTab(
      {super.key,
      required this.themeMode,
      required this.onThemeModeChanged,
      required this.onShowVersionInfo,
      required this.getTextSize,
      required this.getTitleSize,
      required this.getButtonTextSize,
      required this.getIconSize,
      required this.getButtonPadding});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 700),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impostazioni',
                style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 16),
            Text('Tema:'),
            const SizedBox(height: 8),
            Row(
              children: [
                RadioButton(
                  checked: themeMode == ThemeMode.system,
                  onChanged: (_) => onThemeModeChanged(ThemeMode.system),
                  content: const Text('Sistema'),
                ),
                RadioButton(
                  checked: themeMode == ThemeMode.light,
                  onChanged: (_) => onThemeModeChanged(ThemeMode.light),
                  content: const Text('Chiaro'),
                ),
                RadioButton(
                  checked: themeMode == ThemeMode.dark,
                  onChanged: (_) => onThemeModeChanged(ThemeMode.dark),
                  content: const Text('Scuro'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Button(
              child: const Text('Info Versione'),
              onPressed: onShowVersionInfo,
            ),
          ],
        ),
      ),
    );
  }
}
