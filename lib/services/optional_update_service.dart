import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionalUpdateService {
  OptionalUpdateService._();

  static const String enabledKey = 'android_optional_update_enabled';
  static const String latestBuildKey = 'android_latest_build_number';

  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.zagorito.spots_app',
  );

  static Future<bool> isUpdateAvailable() async {
    if (!kReleaseMode ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 6),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults(const <String, Object>{
        enabledKey: false,
        latestBuildKey: 0,
      });

      try {
        await remoteConfig.fetchAndActivate();
      } catch (_) {
        // Continue with the last activated values when the network is unavailable.
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      return shouldOfferUpdate(
        enabled: remoteConfig.getBool(enabledKey),
        currentBuild: currentBuild,
        latestBuild: remoteConfig.getInt(latestBuildKey),
      );
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static bool shouldOfferUpdate({
    required bool enabled,
    required int currentBuild,
    required int latestBuild,
  }) {
    return enabled && currentBuild > 0 && latestBuild > currentBuild;
  }

  static Future<bool> openStoreListing() {
    return launchUrl(_playStoreUri, mode: LaunchMode.externalApplication);
  }
}
