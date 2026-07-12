import 'package:flutter/material.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/theme.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;

  /// Si true, le retour ramène à l'onglet Home du shell principal.
  /// Utile pour les pages affichées comme onglet (Species, Settings).
  final bool toHome;

  const AppBackButton({super.key, this.onTap, this.color, this.toHome = false});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final iconColor = color ?? tc.textSecondary;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, top: 8, bottom: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap ??
                () {
                  if (toHome) {
                    appShellKey.currentState?.navigateTo(0);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tc.surfaceElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.textPrimary.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: iconColor,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
