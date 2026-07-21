import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attribution exigée par les licences des données météo et marines.
///
/// Ce widget ne participe pas aux calculs ni au chargement des prévisions.
class OpenMeteoAttribution extends StatelessWidget {
  const OpenMeteoAttribution({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final EdgeInsetsGeometry padding;

  static final Uri _openMeteoUri = Uri.parse('https://open-meteo.com/');
  static final Uri _dwdUri = Uri.parse('https://www.dwd.de/');

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[Attribution] Impossible d’ouvrir la source: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        );
    final linkStyle = style?.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        label: 'Sources des prévisions météorologiques et marines',
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Données : ', style: style),
            _AttributionLink(
              label: 'Open-Meteo',
              style: linkStyle,
              onTap: () => _open(_openMeteoUri),
            ),
            Text(' · Modèles : ', style: style),
            _AttributionLink(
              label: 'DWD',
              style: linkStyle,
              onTap: () => _open(_dwdUri),
            ),
            Text(' · Prévisions indicatives', style: style),
          ],
        ),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
