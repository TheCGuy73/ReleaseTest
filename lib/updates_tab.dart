import 'package:fluent_ui/fluent_ui.dart';

class UpdatesTab extends StatelessWidget {
  final List<Map<String, dynamic>> releaseHistory;
  final VoidCallback onCheckUpdate;
  final dynamic updateResult;
  final double getTextSize;
  final double getTitleSize;
  final double getButtonTextSize;
  final double getIconSize;
  final EdgeInsets getButtonPadding;

  const UpdatesTab(
      {super.key,
      required this.releaseHistory,
      required this.onCheckUpdate,
      required this.updateResult,
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
            Text('Storico Aggiornamenti',
                style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 12),
            ...releaseHistory.map((rel) => InfoBar(
                  title: Text(rel['tag_name'] ?? '',
                      style: const TextStyle(fontSize: 20)),
                  content: Text(rel['name'] ?? '',
                      style: const TextStyle(fontSize: 20)),
                  severity: InfoBarSeverity.info,
                )),
            const SizedBox(height: 16),
            Button(
                child: const Text('Controlla Aggiornamenti'),
                onPressed: onCheckUpdate),
          ],
        ),
      ),
    );
  }
}
