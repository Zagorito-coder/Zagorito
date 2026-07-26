import 'package:flutter/material.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/widgets/boosterfish_page.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final palette = BoosterFishPagePalette.of(context);
        final imageAsset =
            'assets/home_cards/community_portrait_${palette.isDark ? 'dark' : 'light'}.webp';
        return BoosterFishPageShell(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                BoosterFishPageHeader(
                  eyebrow: context.tr('home.expeditionTitle'),
                  title: context.tr('community.title'),
                  subtitle: context.tr('home.communitySubtitle'),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: BoosterFishGlassCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            imageAsset,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  palette.navy.withValues(alpha: 0.26),
                                  palette.navy.withValues(alpha: 0.94),
                                ],
                                stops: const [0.35, 0.68, 1],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 18,
                            end: 18,
                            bottom: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: palette.accent,
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.accent
                                            .withValues(alpha: 0.38),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.groups_rounded,
                                    color: Colors.white,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  context.tr('community.title'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  context
                                      .tr('home.communitySubtitle')
                                      .replaceAll('\n', ' '),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.84),
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                BoosterFishGlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: palette.accent,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('community.comingSoon'),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
