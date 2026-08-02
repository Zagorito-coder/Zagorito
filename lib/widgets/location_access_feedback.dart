import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:spots_app/l10n/app_localizations.dart';

/// Requests foreground location only after an explicit user action.
///
/// The app does not need background location. This helper keeps the permission
/// explanation and the recovery links consistent everywhere location is used.
Future<bool> ensureLocationAccess(BuildContext context) async {
  try {
    return await _ensureLocationAccess(context);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('locationAccess.unavailable'))),
      );
    }
    return false;
  }
}

Future<bool> _ensureLocationAccess(BuildContext context) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (!context.mounted) return false;
    final openSettings = await _showLocationActionDialog(
      context,
      titleKey: 'locationAccess.serviceDisabledTitle',
      messageKey: 'locationAccess.serviceDisabledMessage',
      actionKey: 'locationAccess.openLocationSettings',
    );
    if (openSettings) await Geolocator.openLocationSettings();
    return false;
  }

  var permission = await Geolocator.checkPermission();
  if (_isGranted(permission)) return true;
  if (!context.mounted) return false;

  if (permission == LocationPermission.deniedForever) {
    await _showAppSettingsDialog(context);
    return false;
  }

  final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('locationAccess.title')),
          content: Text(dialogContext.tr('locationAccess.rationale')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('locationAccess.continue')),
            ),
          ],
        ),
      ) ??
      false;
  if (!shouldRequest) return false;

  permission = await Geolocator.requestPermission();
  if (_isGranted(permission)) return true;
  if (!context.mounted) return false;

  if (permission == LocationPermission.deniedForever) {
    await _showAppSettingsDialog(context);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('locationAccess.denied'))),
    );
  }
  return false;
}

bool _isGranted(LocationPermission permission) =>
    permission == LocationPermission.whileInUse ||
    permission == LocationPermission.always;

Future<void> _showAppSettingsDialog(BuildContext context) async {
  if (!context.mounted) return;
  final openSettings = await _showLocationActionDialog(
    context,
    titleKey: 'locationAccess.deniedForeverTitle',
    messageKey: 'locationAccess.deniedForeverMessage',
    actionKey: 'locationAccess.openAppSettings',
  );
  if (openSettings) await Geolocator.openAppSettings();
}

Future<bool> _showLocationActionDialog(
  BuildContext context, {
  required String titleKey,
  required String messageKey,
  required String actionKey,
}) async {
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr(titleKey)),
          content: Text(dialogContext.tr(messageKey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr(actionKey)),
            ),
          ],
        ),
      ) ??
      false;
}
