import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/models/offline_map_region.dart';
import 'package:spots_app/services/offline_map_service.dart';
import 'package:spots_app/theme.dart';

Future<void> showOfflineMapManager(
  BuildContext context, {
  ValueChanged<OfflineMapRegion>? onActivated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    elevation: 0,
    builder: (_) => OfflineMapManagerSheet(onActivated: onActivated),
  );
}

class OfflineMapManagerSheet extends StatefulWidget {
  const OfflineMapManagerSheet({
    super.key,
    this.onActivated,
  });

  final ValueChanged<OfflineMapRegion>? onActivated;

  @override
  State<OfflineMapManagerSheet> createState() => _OfflineMapManagerSheetState();
}

class _OfflineMapManagerSheetState extends State<OfflineMapManagerSheet> {
  final _service = OfflineMapService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_service.refreshCatalog());
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height *
        (media.orientation == Orientation.portrait ? 0.84 : 0.94);

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final totalSpots = _service.regions.fold<int>(
          0,
          (total, region) => total + region.spotCount,
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.97),
                border: Border(
                  top: BorderSide(
                    color: tc.oceanLight.withValues(alpha: 0.42),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tc.shadowColor,
                    blurRadius: 32,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tc.oceanDeep,
                          tc.oceanLight,
                          tc.sunset,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tc.textMuted.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 8, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: tc.oceanMedium.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tc.oceanLight.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            Icons.public,
                            color: tc.oceanMedium,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('offlineMaps.title'),
                                style: TextStyle(
                                  color: tc.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_service.regions.isNotEmpty)
                                Text(
                                  '${_service.regions.length}  |  '
                                  '$totalSpots spots',
                                  style: TextStyle(
                                    color: tc.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _headerButton(
                          tc: tc,
                          tooltip: context.tr('offlineMaps.refresh'),
                          icon: Icons.refresh,
                          onPressed: _service.isConfigured
                              ? () => unawaited(_service.refreshCatalog())
                              : null,
                        ),
                        const SizedBox(width: 4),
                        _headerButton(
                          tc: tc,
                          tooltip: context.tr('common.close'),
                          icon: Icons.close,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: tc.surfaceLight.withValues(alpha: 0.58),
                      border: Border.symmetric(
                        horizontal: BorderSide(color: tc.divider),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storage_rounded,
                          color: tc.textMuted,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('offlineMaps.storageUsed'),
                          style: TextStyle(
                            color: tc.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_service.installedRegionIds.length}/'
                          '${_service.regions.length}',
                          style: TextStyle(
                            color: tc.oceanMedium,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatBytes(_service.installedBytes),
                          style: TextStyle(
                            color: tc.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildContent(context, tc)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerButton({
    required ThemeColors tc,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(38),
        minimumSize: const Size.square(38),
        padding: EdgeInsets.zero,
        backgroundColor: tc.surfaceLight.withValues(alpha: 0.72),
        foregroundColor: tc.textSecondary,
        disabledForegroundColor: tc.textMuted.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: tc.glassBorder),
        ),
      ),
      icon: Icon(icon, size: 20),
    );
  }

  Widget _buildContent(BuildContext context, ThemeColors tc) {
    if (!_service.isConfigured) {
      return _message(
        tc,
        Icons.cloud_off,
        context.tr('offlineMaps.notConfigured'),
      );
    }
    if (_service.regions.isEmpty) {
      if (_service.lastFailure != null) {
        return _message(
          tc,
          Icons.sync_problem,
          context.tr(_failureKey(_service.lastFailure!)),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _service.refreshCatalog,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _service.regions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 72,
          color: tc.divider,
        ),
        itemBuilder: (context, index) {
          return _regionTile(context, tc, _service.regions[index]);
        },
      ),
    );
  }

  Widget _regionTile(
    BuildContext context,
    ThemeColors tc,
    OfflineMapRegion region,
  ) {
    final installed = _service.isInstalled(region);
    final active = _service.activeRegionId == region.id;
    final downloading = _service.downloadingRegionId == region.id;
    final locale = Localizations.localeOf(context).languageCode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: active
            ? tc.oceanMedium.withValues(alpha: 0.07)
            : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: active ? tc.oceanLight : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(15, 9, 10, 9),
      child: Row(
        children: [
          Semantics(
            label: region.countryCode,
            image: true,
            child: ExcludeSemantics(
              child: _ReliefCountryFlag(
                countryCode: region.countryCode,
                colors: tc,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.localizedName(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                if (downloading)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _service.downloadProgress,
                            minHeight: 4,
                            backgroundColor:
                                tc.surfaceLight.withValues(alpha: 0.8),
                            color: tc.oceanLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_service.downloadProgress * 100).round()}%',
                        style: TextStyle(
                          color: tc.oceanMedium,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${_formatBytes(region.sizeBytes)}  |  '
                    '${region.spotCount} spots  |  '
                    'Z${region.minZoom}-${region.maxZoom}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tc.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (downloading)
            _actionButton(
              tc: tc,
              tooltip: context.tr('common.cancel'),
              icon: Icons.stop_rounded,
              color: tc.error,
              onPressed: _service.cancelDownload,
            )
          else if (installed) ...[
            _actionButton(
              tc: tc,
              tooltip: active
                  ? context.tr('offlineMaps.active')
                  : context.tr('offlineMaps.activate'),
              icon: active ? Icons.check_rounded : Icons.map_outlined,
              color: active ? tc.success : tc.oceanMedium,
              onPressed: active ? null : () => _activate(region),
              showDisabledColor: active,
            ),
            const SizedBox(width: 6),
            _actionButton(
              tc: tc,
              tooltip: context.tr('common.delete'),
              icon: Icons.delete_outline_rounded,
              color: tc.error,
              onPressed: () => _confirmDelete(context, region),
            ),
          ] else
            _actionButton(
              tc: tc,
              tooltip: context.tr('offlineMaps.download'),
              icon: Icons.download_rounded,
              color: tc.oceanMedium,
              onPressed: _service.downloadingRegionId == null
                  ? () => _download(region)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required ThemeColors tc,
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool showDisabledColor = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        maximumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        backgroundColor: color.withValues(alpha: 0.09),
        foregroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.07),
        disabledForegroundColor: showDisabledColor
            ? color.withValues(alpha: 0.85)
            : tc.textMuted.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
      ),
      icon: Icon(icon, size: 20),
    );
  }

  Future<void> _download(OfflineMapRegion region) async {
    try {
      await _service.download(region);
      if (!mounted || _service.activeRegionId != region.id) return;
      widget.onActivated?.call(region);
    } on OfflineMapException catch (error) {
      if (!mounted) return;
      _showError(context, _failureKey(error.failure));
    }
  }

  Future<void> _activate(OfflineMapRegion region) async {
    try {
      await _service.activate(region);
      if (!mounted) return;
      widget.onActivated?.call(region);
    } on OfflineMapException catch (error) {
      if (!mounted) return;
      _showError(context, _failureKey(error.failure));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfflineMapRegion region,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('offlineMaps.deleteTitle')),
        content: Text(context.tr('offlineMaps.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _service.delete(region);
  }

  void _showError(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(key))),
    );
  }

  Widget _message(ThemeColors tc, IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tc.textMuted, size: 42),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _failureKey(OfflineMapFailure failure) {
    return switch (failure) {
      OfflineMapFailure.notConfigured => 'offlineMaps.notConfigured',
      OfflineMapFailure.catalogUnavailable => 'offlineMaps.catalogUnavailable',
      OfflineMapFailure.invalidCatalog => 'offlineMaps.invalidCatalog',
      OfflineMapFailure.downloadFailed => 'offlineMaps.downloadFailed',
      OfflineMapFailure.checksumMismatch => 'offlineMaps.checksumMismatch',
      OfflineMapFailure.invalidArchive => 'offlineMaps.invalidArchive',
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _ReliefCountryFlag extends StatelessWidget {
  const _ReliefCountryFlag({
    required this.countryCode,
    required this.colors,
  });

  final String countryCode;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final normalizedCode = countryCode.toLowerCase();

    return SizedBox(
      key: ValueKey('offline-flag-$normalizedCode'),
      width: 40,
      height: 30,
      child: Image.asset(
        'assets/flags/$normalizedCode.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Center(
            child: Text(
              countryCode,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
