import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spots_app/features/community/widgets/community_map_view.dart';
import 'package:spots_app/features/community/widgets/private_catches_view.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final palette = BoosterFishPagePalette.of(context);
        return BoosterFishPageShell(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: BoosterFishPageHeader(
                  eyebrow: context.tr('home.expeditionTitle'),
                  title: context.tr('community.title'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: palette.divider),
                  ),
                  child: Row(
                    children: [
                      _SectionButton(
                        label: context.tr('community.publicFeed'),
                        icon: Icons.public_rounded,
                        selected: _section == 0,
                        palette: palette,
                        onTap: () => setState(() => _section = 0),
                      ),
                      _SectionButton(
                        label: context.tr('community.myCatches'),
                        icon: Icons.photo_library_rounded,
                        selected: _section == 1,
                        palette: palette,
                        onTap: () => setState(() => _section = 1),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Firebase.apps.isEmpty
                      ? _CommunityUnavailableState(palette: palette)
                      : IndexedStack(
                          index: _section,
                          children: const [
                            CommunityMapView(),
                            PrivateCatchesView(),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityUnavailableState extends StatelessWidget {
  const _CommunityUnavailableState({required this.palette});

  final BoosterFishPagePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BoosterFishGlassCard(
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: palette.textMuted),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  context.tr('community.unavailable'),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final BoosterFishPagePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
