import 'package:flutter/material.dart';

/// The supplied full logo keeps its transparent background. The compact mark
/// intentionally uses the supplied opaque app artwork.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 170, this.compact = false});
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Health Broget',
    image: true,
    child: SizedBox(
      width: width,
      height: compact ? width : width * 280 / 1200,
      child: Image.asset(
        compact
            ? 'assets/branding/health_broget_app_logo_192.png'
            : 'assets/branding/health_broget_wordmark.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
